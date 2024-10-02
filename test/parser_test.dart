import 'package:dart_epubtool/epub.dart';
import 'package:dart_epubtool/parser.dart';

void main() {
  // 替换为你本地的 EPUB 文件路径
  String epubFilePath = './data/01.epub';

  try {
    // 创建 Epub 实例
    Epub epub = Epub(epubFilePath);

    // // 打印文件名列表
    // print("EPUB 文件名列表:");
    // // for (String name in epub.getNamelist()) {
    // //   print(name);
    // // }
    // print(epub.getOpf());
    Epub parser = Parser()
  } catch (e) {
    print("错误: $e");
  }
}
