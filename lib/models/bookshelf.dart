import 'package:get/get.dart';

class Bookshelf {
  final List<BookshelfNovelInfo> list;
  final String classId;

  Bookshelf({required this.list, required this.classId});
}

class BookshelfNovelInfo {
  final String bid;
  final String aid;
  final String url;
  final String title;
  final String img;
  final String updateKey;
  final DateTime? updateTime;
  final bool hasUpdate;
  final bool isReadComplete;
  final String author;
  final String sourceLabel;
  final double rating;

  final RxBool isSelected;

  BookshelfNovelInfo({
    required this.bid,
    required this.aid,
    required this.url,
    required this.title,
    required this.img,
    this.updateKey = '',
    this.updateTime,
    this.hasUpdate = false,
    this.isReadComplete = false,
    this.author = '',
    this.sourceLabel = '',
    this.rating = 0,
    bool initSelected = false,
  }) : isSelected = initSelected.obs;
}

enum BookshelfSortType { update, title, added, recentRead }
