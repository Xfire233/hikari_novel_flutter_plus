class SourceId {
  static const wenku8 = 'wenku8';
  static const yamibo = 'yamibo';
  static const esj = 'esj';
  static const yamiboPrefix = '$yamibo:';
  static const esjPrefix = '$esj:';

  static bool isYamibo(String aid) => aid.startsWith(yamiboPrefix);

  static bool isEsj(String aid) => aid.startsWith(esjPrefix);

  static String yamiboAid(String tid) => '$yamiboPrefix$tid';

  static String esjAid(String bookId) => '$esjPrefix$bookId';

  static String yamiboTid(String aid) =>
      isYamibo(aid) ? aid.substring(yamiboPrefix.length) : aid;

  static String esjBookId(String aid) =>
      isEsj(aid) ? aid.substring(esjPrefix.length) : aid;

  static String yamiboCid(String tid, int page) => '$yamiboPrefix$tid:$page';

  static String esjCid(String chapterId) => '$esjPrefix$chapterId';

  static bool isYamiboCid(String cid) => cid.startsWith(yamiboPrefix);

  static bool isEsjCid(String cid) => cid.startsWith(esjPrefix);

  static String esjChapterId(String cid) =>
      isEsjCid(cid) ? cid.substring(esjPrefix.length) : cid;

  static int yamiboPage(String cid) {
    final parts = cid.split(':');
    if (parts.length < 3) return 1;
    return int.tryParse(parts.last) ?? 1;
  }

  static String safeFilePart(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
