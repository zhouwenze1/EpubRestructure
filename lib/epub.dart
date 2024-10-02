import 'dart:convert'; // 用于 utf-8 解码
import 'package:archive/archive.dart'; // 用于处理 EPUB 文件
import 'dart:io'; // 用于文件操作
import 'package:path/path.dart' as p;

class Epub {
  late Archive epub;
  late String epubSrc;
  late String epubName;
  late String ebookRoot;
  late List<String> namelist = [];
  late String opf = "";
  late String opfpath = "";

  Epub(this.epubSrc)
      : epubName = p.basename(epubSrc),
        ebookRoot = p.dirname(epubSrc),
        epub = ZipDecoder().decodeBytes(File(epubSrc).readAsBytesSync()) {
    _initNamelist();
    _initOpf();
  }

  // 初始化文件名列表
  void _initNamelist() {
    for (ArchiveFile file in epub) {
      namelist.add(file.name); // 添加每个文件的名字到 namelist
    }
  }

  // 初始化 OPF 文件
  void _initOpf() {
    // 读取 META-INF/container.xml 文件内容
    final containerXmlFile = epub.findFile("META-INF/container.xml");
    if (containerXmlFile == null) {
      throw Exception("无法找到 container.xml 文件");
    }
    String containerXml = utf8.decode(containerXmlFile.content);

    // 使用正则表达式提取 OPF 文件路径

    RegExp regExp =
        RegExp(r'<rootfile[^>]*full-path="(.*?\.opf)"', caseSensitive: false);
    RegExpMatch? rf = regExp.firstMatch(containerXml);
    if (rf != null) {
      // 找到 OPF 文件路径
      opfpath = rf.group(1) ?? "";
      final opfFile = epub.findFile(opfpath);
      if (opfFile != null) {
        opf = utf8.decode(opfFile.content);
        return;
      }
    }

    // 如果正则表达式没有找到 OPF 路径，则在文件列表中搜索 OPF 文件
    for (String bkpath in namelist) {
      if (bkpath.toLowerCase().endsWith(".opf")) {
        opfpath = bkpath;
        final opfFile = epub.findFile(opfpath);
        if (opfFile != null) {
          opf = utf8.decode(opfFile.content);
          return;
        }
      }
    }

    // 如果没有找到 OPF 文件，抛出异常
    throw Exception("无法发现 OPF 文件");
  }

  List<String> getNamelist() {
    return namelist;
  }

  String getOpf() {
    return opf;
  }

  String getOpfpath() {
    return opfpath;
  }
}
