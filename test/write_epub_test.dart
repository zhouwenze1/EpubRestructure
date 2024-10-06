// import 'dart:io';
// import 'package:epubx/epubx.dart';
//
// void main() async {
//   // 创建一个EpubBook对象
//   var epub = EpubBook();
//
//   // 设置书籍的元数据
//   epub.Title = "Dart Programming with EpubX";
//   epub.Author = "Your Name";
//   epub.Schema = EpubSchema();
//   epub.Schema!.Package = EpubPackage();
//   epub.Schema!.Package!.Metadata = EpubMetadata();
//   // epub.Schema = EpubSchema()
//   //   ..ContentDirectoryPath = ''
//   //   ..Package = EpubPackage()
//   //   ..Package.Metadata = EpubMetadata()
//
//   // 添加章节
//   var chapter1 = EpubTextContentFile()
//     ..FileName = 'chapter1.xhtml'
//     ..ContentMimeType = 'application/xhtml+xml'
//     ..Content = '''
//       <html xmlns="http://www.w3.org/1999/xhtml">
//         <head><title>Chapter 1</title></head>
//         <body><h1>Chapter 1</h1><p>This is the first chapter.</p></body>
//       </html>
//     ''';
//   epub.Chapters!.add(EpubChapter());
//
//
//   // 创建输出文件
//   var outputFile = File('book.epub');
//
//   // 写入到文件
//   await outputFile.writeAsBytes(await EpubWriter.writeBook(epub));
//
//   print("EPUB 文件已保存");
// }
