import 'dart:collection';
import 'dart:core';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

class Parser {
  Map<String, Tuple3<String, String, String>> idToHMp =
      {}; // { id : (href, mime, properties) }
  Map<String, String> idToHref = {}; // { id : href.lower }
  Map<String, String> hrefToId = {}; // { href.lower : id }
  List<Tuple3<String, String, String>> spineList =
      []; // [ (sid, linear, properties) ]
  List<Tuple2<String, String>> errorOPFLog = []; // [ (errorType, id) ]
  Map<String, String> metadata = HashMap();
  late XmlDocument etreeOpf;

  Parser(String xmlString) {
    etreeOpf = XmlDocument.parse(xmlString);
  }

  void _parseManifest() {
    bool ifError = false;

    var manifestElements = etreeOpf.findAllElements('manifest');
    for (var item in manifestElements) {
      String? id;
      String? href;

      // 检查opf文件中是否存在错误
      try {
        id = item.getAttribute('id');
        href = Uri.decodeComponent(item.getAttribute('href')!); // 解码href
      } catch (e) {
        String strItem = item
            .toXmlString(pretty: true, indent: "  ")
            .replaceAll(RegExp(r'\n|\r|\t'), ''); // 格式化字符串
        print('item: $strItem error: $e');
        ifError = true;
        continue;
      }

      String? mime = item.getAttribute('media-type');
      String properties = item.getAttribute('properties') ?? "";

      idToHMp[id!] = Tuple3(href!, mime ?? "", properties);
      idToHref[id] = href!.toLowerCase();
      hrefToId[href.toLowerCase()] = id;
    }

    if (ifError) {
      print('opf文件中存在错误，请检查！');
    }
  }

  void _parseSpine() {
    for (var itemRef in etreeOpf.findAllElements('spine')) {
      String? sid = itemRef.getAttribute('idref');
      String linear = itemRef.getAttribute('linear') ?? "";
      String properties = itemRef.getAttribute('properties') ?? "";
      spineList.add(Tuple3(sid!, linear, properties));
    }
  }

  void _checkManifestAndSpine() {
    // 获取spine中的所有idrefs
    List<String> spineIdrefs = spineList.map((x) => x.item1).toList();

    // 检查是否存在无效的idref
    for (var idref in spineIdrefs) {
      if (!idToHMp.containsKey(idref)) {
        errorOPFLog.add(Tuple2('invalid_idref', idref));
      }
    }

    // 检查xhtml文件是否在spine中
    for (var entry in idToHMp.entries) {
      String mid = entry.key;
      String mime = entry.value.item2; // MIME type
      if (mime == "application/xhtml+xml" && !spineIdrefs.contains(mid)) {
        errorOPFLog.add(Tuple2('xhtml_not_in_spine', mid));
      }
    }
  }

  void _clearDuplicateIdHref() {
    // id_used = [ id_in_spine + cover_id ]
    List<String> idUsed = [for (var x in spineList) x.item1];
    if (metadata["cover"] != null) {
      idUsed.add(metadata["cover"]!);
    }

    List<String> delId = [];
    for (var entry in idToHref.entries) {
      String id = entry.key;
      String href = entry.value;
      if (hrefToId[href] != id) {
        // 该href拥有多个id，此id已被覆盖
        if (idUsed.contains(id) && !idUsed.contains(hrefToId[href]!)) {
          if (!delId.contains(hrefToId[href]!)) {
            delId.add(hrefToId[href]!);
          }
          hrefToId[href] = id;
        } else if (idUsed.contains(id) && idUsed.contains(hrefToId[href]!)) {
          continue;
        } else {
          if (!delId.contains(id)) {
            delId.add(id);
          }
        }
      }
    }

    for (var id in delId) {
      errorOPFLog.add(Tuple2('duplicate_id', id));
      idToHref.remove(id);
      idToHMp.remove(id);
    }
  }

  void _parseHrefsNotInEpub(List<String> namelist, String opfPath) {
    List<String> delId = [];
    for (var entry in idToHref.entries) {
      String id = entry.key;
      String href = entry.value;
      String bkpath = getBookPath(href, opfPath);
      if (!namelist
          .map((name) => name.toLowerCase())
          .contains(bkpath.toLowerCase())) {
        delId.add(id);
        hrefToId.remove(href);
      }
    }
    for (var id in delId) {
      idToHref.remove(id);
      idToHMp.remove(id);
    }
  }

  void _addFilesNotInOpf(List<String> namelist, String opfPath) {
    List<String> hrefsNotInOpf = [];
    List<String> validExtensions = [
      '.html',
      '.xhtml',
      '.css',
      '.jpg',
      '.jpeg',
      '.bmp',
      '.gif',
      '.png',
      '.webp',
      '.svg',
      '.ttf',
      '.otf',
      '.js',
      '.mp3',
      '.mp4',
      '.smil'
    ];

    for (var archivePath in namelist) {
      // 检查文件扩展名
      if (validExtensions
          .any((ext) => archivePath.toLowerCase().endsWith(ext))) {
        String opfHref = getRelPath(opfPath, archivePath);
        if (!hrefToId.containsKey(opfHref.toLowerCase())) {
          hrefsNotInOpf.add(opfHref);
        }
      }
    }

    for (var href in hrefsNotInOpf) {
      String newId = _allocateId(href);
      idToHref[newId] = href.toLowerCase();
      hrefToId[href.toLowerCase()] = newId;
      String ext = path.extension(href).toLowerCase();
      String mime = mimeMap[ext] ?? "text/plain"; // 使用默认的MIME类型
      idToHMp[newId] = Tuple3(href, mime, "");
    }
  }

  Map<String, String> mimeMap = {
    '.html': 'text/html',
    '.xhtml': 'application/xhtml+xml',
    '.css': 'text/css',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.bmp': 'image/bmp',
    '.gif': 'image/gif',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.js': 'application/javascript',
    '.mp3': 'audio/mpeg',
    '.mp4': 'video/mp4',
    '.smil': 'application/smil+xml',
  };

  String _allocateId(String href) {
    String basename = path.basename(href);
    String newId;

    if (RegExp(r'^[A-Za-z]').hasMatch(basename)) {
      newId = basename;
    } else {
      newId = "x$basename";
    }

    String pre = path.basenameWithoutExtension(newId);
    String suf = path.extension(newId);
    String pre_ = pre;
    int i = 0;
    while (idToHref.containsKey('$pre_$i$suf')) {
      i++;
      pre_ = '$pre_$i';
    }
    return '$pre_$i$suf';
  }

  void _parseMetadata() {
    List<String> keys = [
      "title",
      "creator",
      "language",
      "subject",
      "source",
      "identifier",
      "cover"
    ];

    // 预设所有键值为 ""
    for (var key in keys) {
      metadata[key] = "";
    }

    // 解析 metadata
    var metadataElements = etreeOpf.findAllElements('metadata');
    for (var meta in metadataElements) {
      String tag = meta.name.local; // 去掉命名空间

      if (['title', 'creator', 'language', 'subject', 'source', 'identifier']
          .contains(tag)) {
        metadata[tag] = meta.text ?? ""; // 处理可能为null的情况
      } else if (tag == 'meta') {
        var name = meta.getAttribute('name');
        var content = meta.getAttribute('content');
        if (name != null && content != null) {
          metadata['cover'] = content; // 更新封面
        }
      }
    }
  }

  // 计算相对路径
  String getRelPath(String fromPath, String toPath) {
    List<String> fromParts = fromPath.split(RegExp(r"[\\/]+"));
    List<String> toParts = toPath.split(RegExp(r"[\\/]+"));

    while (fromParts.isNotEmpty &&
        toParts.isNotEmpty &&
        fromParts[0] == toParts[0]) {
      fromParts.removeAt(0);
      toParts.removeAt(0);
    }

    String relativePath = "../" * (fromParts.length - 1) + toParts.join('/');
    return relativePath;
  }

  // 计算书本路径
  String getBookPath(String relativePath, String referBkPath) {
    List<String> relativeParts = relativePath.split(RegExp(r"[\\/]+"));
    List<String> referParts = referBkPath.split(RegExp(r"[\\/]+"));

    int backStep = 0;
    while (relativeParts.isNotEmpty && relativeParts[0] == "..") {
      backStep++;
      relativeParts.removeAt(0);
    }

    if (referParts.length <= 1) {
      return relativeParts.join('/');
    } else {
      referParts.removeLast(); // 去掉最后一个部分
    }

    if (backStep < 1) {
      return (referParts + relativeParts).join('/');
    } else if (backStep >= referParts.length) {
      return relativeParts.join('/');
    }

    // len(referParts) > 1 and backStep <= len(referParts)
    for (int i = 0; i < backStep && referParts.isNotEmpty; i++) {
      referParts.removeLast();
    }

    return (referParts + relativeParts).join('/');
  }
}

// Tuple classes for storing multiple values
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}

class Tuple3<T1, T2, T3> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  Tuple3(this.item1, this.item2, this.item3);
}
