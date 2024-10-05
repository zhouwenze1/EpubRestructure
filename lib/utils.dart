






String getRelPath(String fromPath, String toPath) {
  // fromPath 和 toPath 都需要是绝对路径
  List<String> fromPathParts = fromPath.split(RegExp(r'[\\/]+'));
  List<String> toPathParts = toPath.split(RegExp(r'[\\/]+'));

  // 找到共同的前缀并移除
  while (fromPathParts.isNotEmpty &&
      toPathParts.isNotEmpty &&
      fromPathParts[0] == toPathParts[0]) {
    fromPathParts.removeAt(0);
    toPathParts.removeAt(0);
  }

  // 计算相对路径
  String relativePath =
      '../' * (fromPathParts.length - 1) + toPathParts.join('/');
  return relativePath;
}

// 计算 bookpath
String getBookPath(String relativePath, String referBkPath) {
  // relativePath 相对路径，一般是 href
  // referBkPath 参考的绝对路径
  List<String> relativeParts = relativePath.split(RegExp(r'[\\/]+'));
  List<String> referParts = referBkPath.split(RegExp(r'[\\/]+'));

  int backStep = 0;

  // 计算需要回退的步骤
  while (relativeParts.isNotEmpty && relativeParts[0] == '..') {
    backStep++;
    relativeParts.removeAt(0);
  }

  if (referParts.length <= 1) {
    return relativeParts.join('/');
  } else {
    referParts.removeLast();
  }

  if (backStep < 1) {
    return [...referParts, ...relativeParts].join('/');
  } else if (backStep > referParts.length) {
    return relativeParts.join('/');
  }

  // len(referParts) > 1 and backStep <= len(referParts):
  while (backStep > 0 && referParts.isNotEmpty) {
    referParts.removeLast();
    backStep--;
  }

  return [...referParts, ...relativeParts].join('/');
}
