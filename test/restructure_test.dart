import 'package:dart_epubtool/epub.dart';
import 'package:dart_epubtool/model/epubMeta.dart';
import 'package:dart_epubtool/model/resourceGroup.dart';
import 'package:dart_epubtool/parser.dart';
import 'package:dart_epubtool/restructure.dart';



void main() {
  // 替换为你本地的 EPUB 文件路径
  String epubFilePath = './data/01.epub';

  try {
    // 创建 Epub 实例
    Epub epub = Epub(epubFilePath);


    String opf = epub.getOpf();
    String opfPath = epub.getOpfpath();
    List<String> namelist = epub.getNamelist();
    Parser parser = Parser(opf,opfPath,namelist);
    EpubMeta epubMeta = EpubMeta(opfPath: epub.opfpath, tocPath: parser.tocPath , tocId: parser.tocId);

    ResourceGroup resourceGroup = parser.getResourceGroup();


    Restructure restructure = Restructure(epubSrc: epubFilePath,epubMeta:
    epubMeta, resourceGroup: resourceGroup,sourceEpubArchive: epub.epub,idToHMp: parser.idToHMp,opf:opf);
    restructure.restructure();
    // print(restructure.rePathMap);

  } catch (e) {
     print("错误: $e");
  }
}
