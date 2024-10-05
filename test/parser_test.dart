import 'package:dart_epubtool/epub.dart';
import 'package:dart_epubtool/model/resourceGroup.dart';
import 'package:dart_epubtool/parser.dart';

void main() {
  // 替换为你本地的 EPUB 文件路径
  String epubFilePath = './data/01.epub';
  late ResourceGroup resourceGroup;

  try {
    // 创建 Epub 实例
    Epub epub = Epub(epubFilePath);

    // // 打印文件名列表
    // print("EPUB 文件名列表:");
    // // for (String name in epub.getNamelist()) {
    // //   print(name);
    // // }
    // print(epub.getOpf());
    String opf = epub.getOpf();
    String opfPath = epub.getOpfpath();
    List<String> namelist = epub.getNamelist();

    Parser parser = Parser(opf,opfPath,namelist);
    resourceGroup = parser.getResourceGroup();
    print(resourceGroup.textList);
    print(resourceGroup.cssList);
    print(resourceGroup.imageList);
    print(resourceGroup.audioList);
    print(resourceGroup.videoList);
    print(resourceGroup.otherList);


    // print(parser.metadata);
    // print(parser.packageElements);
    // print(parser.idToHMp);
    // print(parser.idToHref);
    // print(parser.hrefToId);
  } catch (e) {
    print("错误: $e");
  }
}
