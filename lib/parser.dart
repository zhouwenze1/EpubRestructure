import 'dart:collection';
import 'dart:core';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'model/resourceGroup.dart';
import 'utils.dart';

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
  late String opf; // OPF XML string (you may initialize this elsewhere)
  late String epubType; // EPUB type
  late String tocPath; // TOC path
  late String tocId; // TOC ID
  ResourceGroup resourceGroup = ResourceGroup(
    textList: [],
    cssList: [],
    imageList: [],
    fontList: [],
    audioList: [],
    videoList: [],
    otherList: [],
  );

  Map<String, XmlElement> packageElements = {}; // Map to store child elements
  Parser(String xmlString, this.opfPath, this.namelist) {
    etreeOpf = XmlDocument.parse(xmlString);
    _parseOpf();
  }
  late String opfPath;
  late List<String> namelist = [];

  void _parseManifest() {
    bool ifError = false;
    var manifestElements = packageElements['manifest'];
    if (manifestElements == null) {
      print("No metadata found in package elements.");
      return;
    }
    // var manifestElements = etreeOpf.findAllElements('manifest');
    for (var item in manifestElements.children) {
      if (item is! XmlElement) {
        continue;
      }
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
    var spinedataElement = packageElements['spine'];
    if (spinedataElement == null) {
      print("No metadata found in package elements.");
      return;
    }

    for (var itemRef in spinedataElement.children) {
      if (itemRef is! XmlElement) {
        continue;
      }
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

  void _parseHrefsNotInEpub() {
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

  void _addFilesNotInOpf() {
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
    var metadataElement = packageElements['metadata'];
    if (metadataElement == null) {
      print("No metadata found in package elements.");
      return;
    }

    // 正则表达式去除命名空间前缀
    RegExp tagRegExp = RegExp(r'\{.*?\}');

    // 遍历 metadata 子元素
    for (var meta in metadataElement.children) {
      if (meta is XmlElement) {
        // 去除 namespace 并获取标签名称
        String tag = meta.name.toString().replaceAll(tagRegExp, '');
        String tagWithoutNamespace = tag.replaceAll(RegExp(r'.*:'), '');

        // 处理 title、creator、language、subject、source、identifier
        if (["title", "creator", "language", "subject", "source", "identifier"]
            .contains(tagWithoutNamespace)) {
          metadata[tagWithoutNamespace] = meta.text;
        }
        // 处理 meta 标签中的封面信息
        else if (tag == "meta") {
          var nameAttr = meta.getAttribute('name');
          var contentAttr = meta.getAttribute('content');
          if (nameAttr == 'cover' && contentAttr != null) {
            metadata['cover'] = contentAttr;
          }
        }
      }
    }
  }

  void _parseOpf() {
    // Parse the OPF XML string

    // Get the package element
    var packageElement = etreeOpf.findElements('package').first;

    // Store child elements in the map
    for (var child in packageElement.children) {
      if (child is XmlElement) {
        // Ensure child is an XmlElement
        String tag = child.name.local; // Get tag without namespace
        packageElements[tag] = child; // Store the child element in the map
      }
    }

    _parseMetadata();
    _parseManifest();
    _parseSpine();
    _clearDuplicateIdHref();
    _parseHrefsNotInEpub(); // Provide valid parameters
    _addFilesNotInOpf(); // Provide valid parameters

    // Prepare the manifest list
    List<Tuple4<String, String, String, String>> manifestList =
        []; // (id, opfHref, mime, properties)
    for (var id in idToHMp.keys) {
      var tuple = idToHMp[id]!;
      var href = tuple.item1; // Accessing the first item of the tuple
      var mime = tuple.item2; // Accessing the second item of the tuple
      var properties = tuple.item3; // Accessing the third item of the tuple
      manifestList.add(Tuple4(id, href, mime, properties));
    }

    // Determine EPUB type
    String? epubType = packageElement.getAttribute('version');
    if (epubType != null && (epubType == "2.0" || epubType == "3.0")) {
      this.epubType = epubType; // Assuming epubType is a class-level variable
    } else {
      throw Exception("此脚本不支持该EPUB类型");
    }

    // Find EPUB2 TOC file ID; EPUB3 nav file is processed as XHTML
    tocPath = ""; // Assuming tocPath is a class-level variable
    tocId = ""; // Assuming tocId is a class-level variable
    String? tocIdValue = packageElement.getAttribute('toc');
    tocId = tocIdValue ?? "";

    // Classify OPF items
    String opfDir = path.dirname(""); // Assuming you have a valid opfPath
    for (var item in manifestList) {
      String id = item.item1;
      String href = item.item2;
      String mime = item.item3;
      String properties = item.item4;

      String bkPath = path.join(opfDir, href); // Full path
      if (mime == "application/xhtml+xml") {
        // 添加到 textList
        resourceGroup.addText([id, href, properties]);
      } else if (mime == "text/css") {
        // 添加到 cssList
        resourceGroup.addCss([id, href, properties]);
      } else if (mime.startsWith("image/")) {
        // 添加到 imageList
        resourceGroup.addImage([id, href, properties]);
      } else if (mime.startsWith("font/") ||
          href.toLowerCase().endsWith(".ttf") ||
          href.toLowerCase().endsWith(".otf") ||
          href.toLowerCase().endsWith(".woff")) {
        // 添加到 fontList
        resourceGroup.addFont([id, href, properties]);
      } else if (mime.startsWith("audio/")) {
        // 添加到 audioList
        resourceGroup.addAudio([id, href, properties]);
      } else if (mime.startsWith("video/")) {
        // 添加到 videoList
        resourceGroup.addVideo([id, href, properties]);
      } else if (tocId.isNotEmpty && id == tocId) {
        // 设置 TOC 路径
        tocPath = bkPath;
      } else {
        // 添加到 otherList
        resourceGroup.addOther([id, href, mime, properties]);
      }
    }

    _checkManifestAndSpine();
  }

  String getOpf() {
    return opf;
  }
  ResourceGroup getResourceGroup() {
    return resourceGroup;
  }
}

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

class Tuple4<T1, T2, T3, T4> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  final T4 item4;

  Tuple4(this.item1, this.item2, this.item3, this.item4);
}
