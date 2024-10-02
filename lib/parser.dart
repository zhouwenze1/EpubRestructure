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
  late String opf; // OPF XML string (you may initialize this elsewhere)
  late String epubType; // EPUB type
  late String tocPath; // TOC path
  late String tocId; // TOC ID
  List<Tuple3<String, String, String>> textList = []; // (id, href, properties)
  List<Tuple3<String, String, String>> cssList = []; // (id, href, properties)
  List<Tuple3<String, String, String>> imageList = []; // (id, href, properties)
  List<Tuple3<String, String, String>> fontList = []; // (id, href, properties)
  List<Tuple3<String, String, String>> audioList = []; // (id, href, properties)
  List<Tuple3<String, String, String>> videoList = []; // (id, href, properties)
  List<Tuple4<String, String, String, String>> otherList =
      []; // (id, href, mime, properties)
  Map<String, XmlElement> packageElements = {}; // Map to store child elements
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
      "description",
      "language",
      "identifier",
      "date",
      "modified",
      "publisher",
      "cover"
    ];
    for (var key in keys) {
      var element = etreeOpf.findAllElements(key).first;
      if (element != null) {
        metadata[key] = element.text;
      }
    }
  }

  void _parseOpf(String opf) {
    // Parse the OPF XML string
    etreeOpf = XmlDocument.parse(opf);

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
    _parseHrefsNotInEpub([], ""); // Provide valid parameters
    _addFilesNotInOpf([], ""); // Provide valid parameters

    // Prepare the manifest list
    List<Tuple4<String, String, String, String>> manifestList =
        []; // (id, opfHref, mime, properties)
    for (var id in idToHMp.keys) {
      var (href, mime, properties) = idToHMp[id]!;
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
        textList
            .add(Tuple3(id, href, properties)); // Assuming textList is defined
      } else if (mime == "text/css") {
        cssList
            .add(Tuple3(id, href, properties)); // Assuming cssList is defined
      } else if (mime.startsWith("image/")) {
        imageList
            .add(Tuple3(id, href, properties)); // Assuming imageList is defined
      } else if (mime.startsWith("font/") ||
          href.toLowerCase().endsWith(".ttf") ||
          href.toLowerCase().endsWith(".otf") ||
          href.toLowerCase().endsWith(".woff")) {
        fontList
            .add(Tuple3(id, href, properties)); // Assuming fontList is defined
      } else if (mime.startsWith("audio/")) {
        audioList
            .add(Tuple3(id, href, properties)); // Assuming audioList is defined
      } else if (mime.startsWith("video/")) {
        videoList
            .add(Tuple3(id, href, properties)); // Assuming videoList is defined
      } else if (tocId.isNotEmpty && id == tocId) {
        tocPath = bkPath; // Set TOC path
      } else {
        otherList.add(Tuple4(
            id, href, mime, properties)); // Assuming otherList is defined
      }
    }

    _checkManifestAndSpine();
  }

  String getBookPath(String href, String opfPath) {
    return ""; // Implement this method based on your requirements
  }

  String getRelPath(String opfPath, String archivePath) {
    return ""; // Implement this method based on your requirements
  }
  // Other methods...
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
