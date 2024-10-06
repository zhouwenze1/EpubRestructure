import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

// 读取文件的实用函数
String? readFileFromArchive(Archive archive, String fileName) {
  for (var file in archive) {
    if (file.isFile && file.name == fileName) {
      try {
        return utf8.decode(file.content);
      } catch (e) {
        print('Error decoding file $fileName: $e');
        return null;
      }
    }
  }
  return null;
}

// 读取二进制文件的实用函数
Uint8List? readBinaryFileFromArchive(Archive archive, String fileName) {
  for (var file in archive) {
    if (file.isFile && file.name == fileName) {
      return file.content as Uint8List;
    }
  }
  return null;
}

// 写入文本文件的实用函数
void writeToArchive(Archive archive, String fileName, String content) {
  final contentBytes = utf8.encode(content);
  final archiveFile = ArchiveFile(fileName, contentBytes.length, contentBytes);
  archive.addFile(archiveFile);
}

// 写入二进制文件的实用函数
void writeBinaryFileToArchive(Archive archive, String fileName, Uint8List binaryData) {
  final archiveFile = ArchiveFile(fileName, binaryData.length, binaryData);
  archive.addFile(archiveFile);
}
