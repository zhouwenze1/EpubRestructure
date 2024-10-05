import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_epubtool/utils.dart';
import 'package:path/path.dart' as p;

import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'model/epubMeta.dart';
import 'model/resourceGroup.dart';

class Restructure {
  late String opf;
  late String epubSrc; // 源 EPUB 文件路径
  final Archive sourceEpubArchive; // 源 EPUB 的 Archive 对象
  final EpubMeta epubMeta; // EPUB 元数据
  final Map<String, dynamic> idToHMp; // ID 到 HashMap 的映射
  final ResourceGroup resourceGroup; // 资源组
  final Map<String, List<Map<String, String?>>> errorLinkLog = {};
  Archive targetEpubArchive = Archive(); // 目标 EPUB 的 Archive 对象
  
  // 构造函数
  Restructure({
    required this.epubSrc,
    required this.sourceEpubArchive,
    required this.epubMeta,
    required this.idToHMp,
    required this.resourceGroup,
    required this.opf,
  });

  Map<String, Map<String, String>> rePathMap = {
    "text": {},
    "css": {},
    "image": {},
    "font": {},
    "audio": {},
    "video": {},
    "other": {},
  };

  Map<String, List<String>> basenameLog = {
    "text": [],
    "css": [],
    "image": [],
    "font": [],
    "audio": [],
    "video": [],
    "other": [],
  };

  Map<String, String> lowerPathToOriginPath =
  {};

  Uint8List? readImageFromArchive(String fileName) {
    for (var file in sourceEpubArchive) {
      if (file.isFile && file.name == fileName) {
        // 确保文件是图像格式
        if (file.name.endsWith('.jpg') ||
            file.name.endsWith('.jpeg') || // 支持 JPEG
            file.name.endsWith('.png') ||
            file.name.endsWith('.gif')) {
          // 返回图像的二进制数据
          return file.content as Uint8List; // 假设 file.content 是 Uint8List 类型
        }
      }
    }
    return null; // 如果未找到文件，返回 null
  }

  String? readFileFromArchive(String fileName) {
    for (var file in sourceEpubArchive) {
      if (file.isFile && file.name == fileName) {
        try {
          // 尝试以 UTF-8 解码文件内容
          return utf8.decode(file.content as List<int>);
        } catch (e) {
          // 捕获解码错误并返回 null 或处理方式
          print('Error decoding file $fileName: $e');
          return null; // 或者根据需要返回其他值
        }
      }
    }
    return null; // 如果文件未找到，返回 null
  }


  /// 将文件内容写入目标 Archive 对象
  void writeToArchive(Archive archive, String fileName, String content) {
    // 将文件添加到目标 Archive
    final archiveFile =
    ArchiveFile(fileName, content.length, utf8.encode(content));
    archive.addFile(archiveFile);
  }
  void writeImageToArchive(Archive archive, String fileName, Uint8List imageData) {
    // 创建 ArchiveFile 对象并添加图像数据到目标 Archive
    final archiveFile = ArchiveFile(fileName, imageData.length, imageData);
    archive.addFile(archiveFile);
  }
  String autoRename(String id, String href, String ftype) {
    // 分割文件名和扩展名
    String filename = p.basenameWithoutExtension(href);
    String ext = p.extension(href);
    String filename_ = filename;
    int num = 0;

    // 检查是否已存在该文件名，若存在则递增数字后缀
    while (basenameLog[ftype]?.contains(filename_ + ext) ?? false) {
      num += 1;
      filename_ = '$filename\_$num';
    }

    // 生成最终的文件名
    String basename = filename_ + ext;

    // 将生成的文件名添加到日志中
    basenameLog.putIfAbsent(ftype, () => []).add(basename);

    return basename;
  }

  String? checkLink(String filename, String bkpath, String href,
      [String targetId = ""]) {
    // 如果 href 是空字符串或以特定协议开头，返回 null
    if (href.isEmpty ||
        href.startsWith(RegExp(r'^(http://|https://|res:/|file:/|data:)'))) {
      return null;
    }

    // 检查 lowerPathToOriginPath 是否包含 bkpath 的小写形式
    if (lowerPathToOriginPath.containsKey(bkpath.toLowerCase())) {
      // 如果大小写不一致，进行纠正
      if (bkpath != lowerPathToOriginPath[bkpath.toLowerCase()]) {
        String correctPath = lowerPathToOriginPath[bkpath.toLowerCase()]!;
        errorLinkLog.putIfAbsent(filename, () => []);
        errorLinkLog[filename]?.add({
          'href': href + targetId,
          'correct_path': correctPath,
        });
        bkpath = correctPath;
      }
    } else {
      // 如果链接路径找不到对应文件
      errorLinkLog.putIfAbsent(filename, () => []);
      errorLinkLog[filename]?.add({
        'href': href + targetId,
        'correct_path': null,
      });
      return null;
    }

    return bkpath;
  }

  void handleResources(List<List<dynamic>> resourceList, String fileType) {
    for (var resource in resourceList) {
      var id = resource[0];
      var href = resource[1];
      var bkpath = getBookPath(href, epubMeta.opfPath);
      var basename = autoRename(id, href, fileType);
      rePathMap[fileType]?[bkpath] = basename;
      lowerPathToOriginPath[bkpath.toLowerCase()] = bkpath;
    }
  }

  void restructure() {
    // 在这里添加重构逻辑
    // 例如，读取 sourceEpubArchive 的内容并进行修改
    // for (var file in sourceEpubArchive) {
    //   if (file.isFile) {
    //     // 读取文件内容并进行处理
    //     String content = String.fromCharCodes(file.content as List<int>);
    //     // 对内容进行必要的重构
    //     // String modifiedContent = modifyContent(content);
    //
    //     // 将修改后的内容写入到目标 Archive
    //     // targetEpubArchive.addFile(ArchiveFile(file.name, modifiedContent.length, utf8.encode(modifiedContent)));
    //   }
    String? mimetype = readFileFromArchive("mimetype");
    if (mimetype != null) {
      targetEpubArchive.addFile(
          ArchiveFile("mimetype", mimetype.length, utf8.encode(mimetype)));
    } else {
      print("No mimetype found in source EPUB.");
    }
    String? metainfData = readFileFromArchive("META-INF/container.xml");
    final RegExp regExp = RegExp(
      r'<rootfile[^>]*media-type="application/oebps-[^>]*/>',
      multiLine: true,
      caseSensitive: false,
    );

    if (metainfData != null) {
      String updatedData = metainfData.replaceAll(
        regExp,
        '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>',
      );
      targetEpubArchive.addFile(ArchiveFile("META-INF/container.xml",
          updatedData.length, utf8.encode(updatedData)));
    } else {
      print("No META-INF/container.xml found in source EPUB.");
    }

    handleResources(resourceGroup.textList, 'text');
    handleResources(resourceGroup.cssList, 'css');
    handleResources(resourceGroup.imageList, 'image');
    handleResources(resourceGroup.fontList, 'font');
    handleResources(resourceGroup.audioList, 'audio');
    handleResources(resourceGroup.videoList, 'video');
    handleResources(resourceGroup.otherList, 'other');


    String? tocPath = epubMeta.tocPath;
    if (tocPath.isNotEmpty)
      {
        var toc = readFileFromArchive(epubMeta.tocPath);
        var toc_dir = p.dirname(epubMeta.tocPath);

        RegExp hrefExp = RegExp(r'''src=([\'\"])(.*?)\1''');
        toc?.replaceAllMapped(hrefExp, (match) => reTocHref(match, tocPath));
        writeToArchive(targetEpubArchive, tocPath, toc!);

      }








    rePathMap['text']?.forEach((xhtmlBkpath, newName) {
      String? text = readFileFromArchive(xhtmlBkpath);
      if (text!.isEmpty) {
        print("Processing $xhtmlBkpath failed");
      }
      if (!text.startsWith("<?xml")) {
        text = '<?xml version="1.0" encoding="utf-8"?>\n' + text;
      }
      RegExp doctypeCheck = RegExp(r'[\s\S]*<!DOCTYPE html');
      if (!doctypeCheck.hasMatch(text)) {
        // 定义用于替换的正则表达式
        // 定义正则表达式
        RegExp regex = RegExp(r"(<\?xml.*?>)\n*");

        // 执行替换
        text = text.replaceFirst(
            regex,
            r'''$1
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
          "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
                ''');
      }
      String hrefPattern = r'''(<[^>]*href=([\'"]))(.*?)(\2[^>]*>)''';
      RegExp hrefExp = RegExp(hrefPattern, caseSensitive: false);
      text = text.replaceAllMapped(regExp, (match) => reHref(match, xhtmlBkpath));

      String srcPattern = r'''(<[^>]*src=([\'"]))(.*?)(\2[^>]*>)''';
      RegExp srcExp = RegExp(srcPattern, caseSensitive: false);
      text = text.replaceAllMapped(srcExp, (match) => reSrc(match, xhtmlBkpath));


      String urlPattern = r'''(url\([\'\"]?)(.*?)([\'\"]?\))''';
      RegExp urlExp = RegExp(urlPattern, caseSensitive: false);
      text = text.replaceAllMapped(urlExp, (match) => reUrl(match, xhtmlBkpath));
      writeToArchive(targetEpubArchive,  "OEBPS/Text/$newName", text);

    });



    rePathMap['css']?.forEach((cssBkpath, newName) {
      String css = readFileFromArchive(cssBkpath)!;
      String importPattern = r'''@import ([\'\"])(.*?)\1|@import url\([\'\"]?(.*?)[\'\"]?\)''';
      RegExp importExp = RegExp(importPattern, caseSensitive: false);
      css = css.replaceAllMapped(importExp, (match) => reImport(match));
      String cssUrlPattern = r'''(url\([\'\"]?)(.*?)([\'\"]?\))''';
      RegExp cssUrlExp = RegExp(cssUrlPattern, caseSensitive: false);
      css = css.replaceAllMapped(cssUrlExp, (match) => reCssUrl(match, cssBkpath));

      writeToArchive(targetEpubArchive, "OEBPS/Styles/$newName", css);



    });
    rePathMap['image']?.forEach((imageBkpath, newName) {
      Uint8List? imageData = readBinaryFileFromArchive(imageBkpath);

      writeBinaryFileToArchive(targetEpubArchive, "OEBPS/Images/$newName", imageData!);
    });

    rePathMap['font']?.forEach((fontBkpath, newName) {
      Uint8List? fontData = readBinaryFileFromArchive(fontBkpath);
      writeBinaryFileToArchive(targetEpubArchive, "OEBPS/Fonts/$newName", fontData!);
      // String font = readFileFromArchive(fontBkpath)!;
      // writeToArchive(targetEpubArchive, "OEBPS/Fonts/$newName", font);
    });
    rePathMap['audio']?.forEach((audioBkpath, newName) {
      Uint8List? audioData = readBinaryFileFromArchive(audioBkpath);
      writeBinaryFileToArchive(targetEpubArchive, "OEBPS/Audio/$newName", audioData!);


    });
    rePathMap['video']?.forEach((videoBkpath, newName) {
      Uint8List? videoData = readBinaryFileFromArchive(videoBkpath);
      writeBinaryFileToArchive(targetEpubArchive, "OEBPS/Video/$newName", videoData!);

      // String video = readFileFromArchive(videoBkpath)!;
      // writeToArchive(targetEpubArchive, "OEBPS/Video/$newName", video);
    });
    rePathMap['other']?.forEach((otherBkpath, newName) {
      String other = readFileFromArchive(otherBkpath)!;
      writeToArchive(targetEpubArchive, "OEBPS/Misc/$newName", other);
    });


    List<List<dynamic>> manifestList = [];

    for (var id in idToHMp.keys) {
      var href = idToHMp[id]![0];  // 获取 href
      var mime = idToHMp[id]![1];  // 获取 mime
      var properties = idToHMp[id]![2];  // 获取 properties

      manifestList.add([id, href, mime, properties]);  // 将 (id, href, mime, properties) 添加到 manifestList
    }

    String manifestText = "<manifest>";
    for (var item in manifestList) {
      String id = item[0];
      String href = item[1];
      String mime = item[2];
      String? prop = item[3];


      manifestText = generateManifestText(manifestText, id, href, mime, prop, rePathMap, epubMeta.tocId, epubMeta.opfPath);
    }
    manifestText += "\n  </manifest>";

    RegExp manifestExp = RegExp(r"<manifest.*?>.*?</manifest>", dotAll: true);
    opf = opf.replaceFirst(regExp, manifestText);

    RegExp referExp = RegExp(r'''(<reference[^>]*href=([\'\"]))(.*?)(\2[^>]*/>)''');

    opf = opf.replaceAllMapped(referExp, reRefer);

    writeToArchive(targetEpubArchive, "OEBPS/content.opf", opf);









    saveTargetEpub();

  }


  Uint8List? readBinaryFileFromArchive(String fileName) {
    for (var file in sourceEpubArchive) {
      if (file.isFile && file.name == fileName) {
        // 返回二进制数据
        return file.content as Uint8List; // 假设 file.content 是 Uint8List 类型
      }
    }
    return null; // 如果未找到文件，返回 null
  }
  void writeBinaryFileToArchive(Archive archive, String fileName, Uint8List binaryData) {
    // 创建 ArchiveFile 对象并添加二进制数据到目标 Archive
    final archiveFile = ArchiveFile(fileName, binaryData.length, binaryData);
    archive.addFile(archiveFile);
  }

  String reRefer(Match match) {
    // 获取 href 并进行 URL 解码和去除多余的空格
    String href = Uri.decodeComponent(match.group(3)!);
    href = href.trim();

    // 获取 basename（最后的文件名）
    String baseName = p.basename(href);

    // 进一步解码文件名
    String filename = Uri.decodeComponent(baseName);

    // 判断文件是否以 ".ncx" 结尾
    if (!baseName.endsWith(".ncx")) {
      // 返回替换后的文本
      return "${match.group(1)}../Text/$filename${match.group(4)}";
    } else {
      // 返回原始的匹配内容，并确保非空
      return match.group(0) ?? '';
    }
  }


  String generateManifestText(String manifestText,
      String id, String href, String mime, String? prop, Map<String, Map<String, String>> rePathMap, String tocId, String opfpath) {

    // 调用 getBookpath 函数获取书路径 (需要你实现)
    var bkpath = getBookPath(href, opfpath);

    // 设置属性字符串
    String prop_ = prop != null && prop.isNotEmpty ? ' properties="$prop"' : "";

    // 初始化 manifest_text


    // 根据不同的 MIME 类型生成不同的 item 标签
    if (mime == "application/xhtml+xml") {
      String filename = rePathMap["text"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Text/$filename" media-type="$mime"$prop_/>';

    } else if (mime == "text/css") {
      String filename = rePathMap["css"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Styles/$filename" media-type="$mime"$prop_/>';

    } else if (mime.contains("image/")) {
      String filename = rePathMap["image"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Images/$filename" media-type="$mime"$prop_/>';

    } else if (mime.contains("font/") || href.toLowerCase().endsWith(".ttf") || href.toLowerCase().endsWith(".otf") || href.toLowerCase().endsWith(".woff")) {
      String filename = rePathMap["font"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Fonts/$filename" media-type="$mime"$prop_/>';

    } else if (mime.contains("audio/")) {
      String filename = rePathMap["audio"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Audio/$filename" media-type="$mime"$prop_/>';

    } else if (mime.contains("video/")) {
      String filename = rePathMap["video"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Video/$filename" media-type="$mime"$prop_/>';

    } else if (id == tocId) {
      manifestText += '\n    <item id="$id" href="toc.ncx" media-type="application/x-dtbncx+xml"/>';

    } else {
      String filename = rePathMap["other"]![bkpath]!;
      manifestText += '\n    <item id="$id" href="Misc/$filename" media-type="$mime"$prop_/>';

    }

    return manifestText;
  }

  void saveTargetEpub() {
    var epubName = p.basename(epubSrc);
    var ebookRoot = p.dirname(epubSrc);

    // 目标文件路径
    String targetFilePath =
    path.join(ebookRoot, epubName.replaceAll(".epub", "_reformat.epub"));

    // 创建 ZIP 文件
    var zipData = ZipEncoder().encode(targetEpubArchive);

    // 将压缩数据写入文件
    File(targetFilePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(zipData!); // 压缩数据写入目标文件

    // 将 archive 压缩成 zip 并写入文件

    print("ZIP 文件已创建：$targetFilePath");
  }


  String reImport(Match match) {
    // 获取 href 值，判断 group(2) 和 group(3)
    String href = match.group(2) ?? match.group(3)!;

    // 解码并去除空格
    href = Uri.decodeComponent(href).trim();

    // 检查是否为 .css 文件，不是则返回原始匹配
    if (!href.toLowerCase().endsWith('.css')) {
      return match.group(0)!; // 返回原始匹配
    }

    // 获取文件名
    String filename = path.basename(href);

    // 返回 @import 字符串
    return '@import "$filename"';
  }
  String reCssUrl(Match match, String cssBkpath) {
    // 获取 URL 并解码
    String url = match.group(2)!;
    url = Uri.decodeComponent(url).trim();

    // 获取书路径
    String? bkpath = getBookPath(url, cssBkpath);
    bkpath = checkLink(cssBkpath, bkpath, url);

    if (bkpath == null || bkpath.isEmpty) {
      return match.group(0)!; // 返回原始匹配
    }

    // 检查字体文件
    if (url.toLowerCase().endsWith('.ttf') || url.toLowerCase().endsWith('.otf')) {
      String filename = rePathMap["font"]![bkpath]!;
      return '${match.group(1)}../Fonts/$filename${match.group(3)}';
    }
    // 检查图片文件
    else if (url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.bmp') ||
        url.toLowerCase().endsWith('.gif') ||
        url.toLowerCase().endsWith('.webp') ||
        url.toLowerCase().endsWith('.svg')) {
      String filename = rePathMap["image"]![bkpath]!;
      return '${match.group(1)}../Images/$filename${match.group(3)}';
    } else {
      return match.group(0)!; // 返回原始匹配
    }
  }
  String reHref(Match match, String xhtmlBkpath) {
    String href = match.group(3)!; // 获取 href 值
    href = Uri.decodeComponent(href).trim(); // 解码并去除空格
    String targetId = "";

    // 检查是否包含 #
    if (href.contains("#")) {
      List<String> parts = href.split("#");
      href = parts[0]; // 更新 href
      targetId = "#" + parts[1]; // 更新 target_id
    }

    String? bkpath = getBookPath(href, xhtmlBkpath); // 获取书路径
    bkpath = checkLink(xhtmlBkpath, bkpath, href, targetId); // 检查链接

    if (bkpath!.isEmpty) {
      return match.group(0)!; // 返回原始匹配
    }

    // 检查 href 后缀并构建新的路径
    if (href
        .toLowerCase()
        .endsWith('.(jpg|jpeg|png|bmp|gif|webp)')) {
      String filename = rePathMap["image"]![bkpath]!;
      return '${match.group(1)}../Images/$filename${match.group(4)}'; // 图片路径
    } else if (href.toLowerCase().endsWith('.css')) {
      String filename = rePathMap["css"]![bkpath]!;
      return '<link href="../Styles/$filename" type="text/css" rel="stylesheet"/>'; // CSS 路径
    } else if (href.toLowerCase().endsWith('.xhtml') ||
        href.toLowerCase().endsWith('.html')) {
      String filename = rePathMap["text"]![bkpath]!;
      return '${match.group(1)}$filename$targetId${match.group(
          4)}'; // HTML 或 XHTML 路径
    } else {
      return match.group(0)!; // 返回原始匹配
    }
  }

  String reSrc(Match match, String xhtmlBkpath) {
    String href = Uri.decodeComponent(match.group(3)!);
    href = href.trim();
    String? bkpath = getBookPath(href, xhtmlBkpath);
    bkpath = checkLink(xhtmlBkpath, bkpath, href);

    if (bkpath!.isEmpty) {
      return match.group(0)!;
    }

    if (href
        .toLowerCase()
        .endsWith('.(jpg|jpeg|png|bmp|gif|webp|svg)')) {

      String filename = rePathMap["image"]![bkpath]!;
      return '${match.group(1)}../Images/$filename${match.group(4)}';
    } else if (href.toLowerCase().endsWith('.mp3')) {
      String filename = rePathMap["audio"]![bkpath]!;
      return '${match.group(1)}../Audio/$filename${match.group(4)}';
    } else if (href.toLowerCase().endsWith('.mp4')) {
      String filename = rePathMap["video"]![bkpath]!;
      return '${match.group(1)}../Video/$filename${match.group(4)}';
    } else if (href.toLowerCase().endsWith('.js')) {
      String filename = rePathMap["other"]![bkpath]!;
      return '${match.group(1)}../Misc/$filename${match.group(4)}';
    } else {
      return match.group(0)!;
    }
  }

  String reUrl(Match match, String xhtmlBkpath ){
    String url = match.group(2)!; // 获取匹配的 URL 部分
    url = Uri.decodeComponent(url).trim(); // 解码并去除空格
    String? bkpath = getBookPath(url, xhtmlBkpath); // 获取书路径
    bkpath = checkLink(xhtmlBkpath, bkpath, url); // 检查链接

    if (bkpath!.isEmpty) {
      return match.group(0)!; // 返回原始匹配
    }


    // 检查 URL 后缀并构建新的路径
    if (url.toLowerCase().endsWith('.ttf') || url.toLowerCase().endsWith('.otf')) {
      String filename = rePathMap["font"]![bkpath]!;
      return '${match.group(1)}../Fonts/$filename${match.group(3)}'; // 字体路径
    } else if (url
        .toLowerCase()
        .endsWith('.(jpg|jpeg|png|bmp|gif|webp|svg)')) {

      String filename = rePathMap["image"]![bkpath]!;
      return '${match.group(1)}../Images/$filename${match.group(3)}'; // 图片路径
    } else {
      return match.group(0)!; // 返回原始匹配
    }
  }
  String reTocHref(Match match, String tocpath) {
    String href = match.group(2)!; // 获取 href 值
    href = Uri.decodeComponent(href).trim(); // 解码并去除空格

    String targetId = "";

    // 检查是否包含 #
    if (href.contains("#")) {
      List<String> parts = href.split("#");
      href = parts[0]; // 更新 href
      targetId = "#" + parts[1]; // 更新 targetId
    }

    String? bkpath = getBookPath(href, tocpath); // 获取书路径
    bkpath = checkLink(tocpath, bkpath!, href); // 检查链接

    if (bkpath == null || bkpath.isEmpty) {
      return match.group(0)!; // 返回原始匹配
    }

    // 获取文件名
    String filename = path.basename(bkpath);
    return 'src="Text/$filename"$targetId'; // 返回构造的 src
  }


}
// Placeholder for the Tuple3 and Tuple4 classes
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
