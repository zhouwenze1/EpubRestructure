class ResourceGroup {
  final List<List<dynamic>> textList;
  final List<List<dynamic>> cssList;
  final List<List<dynamic>> imageList;
  final List<List<dynamic>> fontList;
  final List<List<dynamic>> audioList;
  final List<List<dynamic>> videoList;
  final List<List<dynamic>> otherList;

  ResourceGroup({
    required this.textList,
    required this.cssList,
    required this.imageList,
    required this.fontList,
    required this.audioList,
    required this.videoList,
    required this.otherList,
  });

  // 为 textList 添加元素
  void addText(List<dynamic> text) {
    textList.add(text);
  }

  // 为 cssList 添加元素
  void addCss(List<dynamic> css) {
    cssList.add(css);
  }

  // 为 imageList 添加元素
  void addImage(List<dynamic> image) {
    imageList.add(image);
  }

  // 为 fontList 添加元素
  void addFont(List<dynamic> font) {
    fontList.add(font);
  }

  // 为 audioList 添加元素
  void addAudio(List<dynamic> audio) {
    audioList.add(audio);
  }

  // 为 videoList 添加元素
  void addVideo(List<dynamic> video) {
    videoList.add(video);
  }

  // 为 otherList 添加元素
  void addOther(List<dynamic> other) {
    otherList.add(other);
  }
}
