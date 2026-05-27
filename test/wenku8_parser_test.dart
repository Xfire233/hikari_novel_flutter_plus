import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/service/browser_assisted_fetch_service.dart';

void main() {
  test('Wenku8 recommend parser tolerates unexpected home html', () {
    expect(
      Parser.getRecommend('<html><body>temporary failure</body></html>'),
      isEmpty,
    );
  });

  test('Wenku8 list parser tolerates style whitespace changes', () {
    final list = Parser.parseToList(
      '<html><body><div id="content">'
      '<div style="width: 373px; height: 136px; float: left; margin: 5px 0px 5px 5px;">'
      '<a href="/book/123.htm" title="测试标题"><img src="/images/noimg.jpg"></a>'
      '<div><a href="/book/123.htm">测试标题</a></div>'
      '</div></div></body></html>',
    );

    expect(list, hasLength(1));
    expect(list.single.aid, '123');
    expect(list.single.title, '测试标题');
  });

  test('Wenku8 list parser accepts compact book grid cards', () {
    final list = Parser.parseToList(
      '<html><body><div id="content">'
      '<div style="float: left;text-align:center;width: 95px; height:155px;overflow:hidden;">'
      '<a href="/book/456.htm"><img src="/files/article/image/0/456/456s.jpg"></a>'
      '<a href="/book/456.htm">紧凑列表标题</a>'
      '</div></div></body></html>',
    );

    expect(list, hasLength(1));
    expect(list.single.aid, '456');
    expect(list.single.title, '紧凑列表标题');
  });

  test('Wenku8 list parser accepts tag pages without content wrapper', () {
    final list = Parser.parseToList(
      '<html><head><title>Tags含有 旅行 的轻小说</title></head><body>'
      '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
      '<a href="book/789.htm" title="旅行测试"><img src="/files/article/image/0/789/789s.jpg"></a>'
      '<div><a href="book/789.htm">旅行测试</a></div>'
      '</div></body></html>',
    );

    expect(list, hasLength(1));
    expect(list.single.aid, '789');
    expect(list.single.title, '旅行测试');
  });

  test('Wenku8 detail parser extracts tags from links and labels', () {
    const html =
        '<html><head><title>Detail Title - Wenku8</title></head><body>'
        '<div id="content">'
        '<h1>Detail Title</h1>'
        '<span>\u5c0f\u8bf4\u4f5c\u8005\uFF1AAuthor Name</span>'
        '<span>\u5199\u4f5c\u8fdb\u7a0b\uFF1A\u5df2\u7ecf\u5b8c\u672c</span>'
        '<span>\u6700\u540e\u66f4\u65b0\uFF1A2026-05-26</span>'
        '<span>\u5c0f\u8bf4Tags\uFF1A\u6821\u56ed \u604b\u7231</span>'
        '<a href="/modules/article/tags.php?t=x">\u9b54\u6cd5</a>'
        '<p>\u8fd9\u662f\u4e00\u6bb5\u8db3\u591f\u957f\u7684\u7b80\u4ecb\u5185\u5bb9\uff0c'
        '\u7528\u4e8e\u907f\u514d\u88ab\u8bc6\u522b\u4e3a\u5143\u6570\u636e\u3002</p>'
        '<a href="/modules/article/reviews.php?aid=123">reviews</a>'
        '<a href="/modules/article/addbookcase.php?bid=123">add</a>'
        '<a href="/modules/article/uservote.php?id=123">vote</a>'
        '</div></body></html>';

    final detail = Parser.getNovelDetail(html);

    expect(detail.title, 'Detail Title');
    expect(detail.author, 'Author Name');
    expect(
      detail.tags,
      containsAll(['\u6821\u56ed', '\u604b\u7231', '\u9b54\u6cd5']),
    );
    expect(detail.tags, isNotEmpty);
  });

  test('Wenku8 detail parser preserves native Dio legacy table tags', () {
    const html =
        '<html><body><div id="content">'
        '<table><tr><td><span><b>Legacy Detail</b></span></td></tr>'
        '<tr><td></td></tr>'
        '<tr><td></td>'
        '<td>\u5c0f\u8bf4\u4f5c\u8005\uFF1ALegacy Author</td>'
        '<td>\u5199\u4f5c\u8fdb\u7a0b\uFF1A\u8fde\u8f7d\u4e2d</td>'
        '<td>\u6700\u540e\u66f4\u65b0\uFF1A2026-05-26</td></tr></table>'
        '<table></table>'
        '<table><tr><td></td><td>'
        '<span>\u5c0f\u8bf4Tags\uFF1A\u6821\u56ed \u9752\u6625 \u604b\u7231</span>'
        '<span>\u603b\u70b9\u51fb\uFF1A12 \u6708\u70b9\u51fb\uFF1A3</span>'
        '<span></span><span></span><span></span>'
        '<span>\u8fd9\u662f\u539f\u59cb table/span \u7ed3\u6784\u4e0b\u7684'
        '\u4e00\u6bb5\u8db3\u591f\u957f\u7684\u7b80\u4ecb\u5185\u5bb9\u3002</span>'
        '</td></tr></table>'
        '</div></body></html>';

    final detail = Parser.getNovelDetail(html);

    expect(detail.title, 'Legacy Detail');
    expect(detail.author, 'Legacy Author');
    expect(
      detail.tags,
      containsAll(['\u6821\u56ed', '\u9752\u6625', '\u604b\u7231']),
    );
  });

  test('Wenku8 detail parser keeps flexible label scanning as fallback', () {
    const html =
        '<html><body><main id="content">'
        '<h1>Flexible Detail</h1>'
        '<p>\u5c0f\u8bf4\u4f5c\u8005\uFF1AFlexible Author</p>'
        '<p>\u5199\u4f5c\u8fdb\u7a0b\uFF1A\u8fde\u8f7d\u4e2d</p>'
        '<p>\u5c0f\u8bf4Tags\uFF1A\u5947\u5e7b \u5192\u9669 \u5973\u6027\u89c6\u89d2</p>'
        '<section>\u8fd9\u662f\u901a\u7528 label \u626b\u63cf\u7ed3\u6784\u4e0b'
        '\u7684\u4e00\u6bb5\u8db3\u591f\u957f\u7684\u7b80\u4ecb\u5185\u5bb9\u3002</section>'
        '<a href="/modules/article/reviews.php?aid=124">reviews</a>'
        '<a href="/modules/article/addbookcase.php?bid=124">add</a>'
        '<a href="/modules/article/uservote.php?id=124">vote</a>'
        '</main></body></html>';

    final detail = Parser.getNovelDetail(html);

    expect(detail.title, 'Flexible Detail');
    expect(detail.author, 'Flexible Author');
    expect(
      detail.tags,
      containsAll(['\u5947\u5e7b', '\u5192\u9669', '\u5973\u6027\u89c6\u89d2']),
    );
  });

  test('Wenku8 max page parser uses page query when last marker is absent', () {
    const html =
        '<html><body><div id="content">'
        '<a href="/modules/article/tags.php?t=x&amp;v=0&amp;page=2">2</a>'
        '<a href="/modules/article/tags.php?t=x&amp;v=0&amp;page=18">18</a>'
        '</div></body></html>';

    expect(Parser.getMaxNum(html), 18);
  });
  test(
    'Wenku8 browser assisted cache aliases cover host and home variants',
    () {
      final aliases = BrowserAssistedFetchService.cacheAliasesFor(
        'https://www.wenku8.cc/index.php?&charset=gbk',
      );

      expect(aliases, contains('https://www.wenku8.cc/index.php'));
      expect(aliases, contains('https://www.wenku8.cc/'));
      expect(aliases, contains('https://www.wenku8.net/index.php'));
      expect(aliases, contains('https://www.wenku8.net/'));
    },
  );

  test('Wenku8 assisted validation accepts captured list/detail pages', () {
    const listHtml =
        '<html><body><div id="content">'
        '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
        '<a href="/book/123.htm">book</a></div>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';
    const detailHtml =
        '<html><body><div id="content">'
        '<a href="/modules/article/reviews.php?aid=123">reviews</a>'
        '<a href="/modules/article/addbookcase.php?bid=123">add</a>'
        '<a href="/modules/article/uservote.php?id=123">vote</a>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/tags.php?t=x&v=0&page=1',
        listHtml,
      ),
      isTrue,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/articleinfo.php?id=123',
        detailHtml,
      ),
      isTrue,
    );
  });

  test('Wenku8 assisted validation rejects list html for detail urls', () {
    // Real Wenku8 list pages never contain both addbookcase and uservote
    // forms — those are exclusive to detail pages.  Simulate a list page
    // that still has the list card dimensions but no detail-specific forms.
    const listHtml =
        '<html><body><div id="content">'
        '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
        '<a href="/book/123.htm">book</a>'
        '<a href="/modules/article/articleinfo.php?id=456">other book</a>'
        '</div>'
        '<a href="/modules/article/reviews.php?aid=123">reviews</a>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/articleinfo.php?id=123',
        listHtml,
      ),
      isFalse,
    );
  });

  test('Wenku8 assisted validation accepts compact list pages', () {
    const compactListHtml =
        '<html><body><div id="content">'
        '<div style="float: left;text-align:center;width: 95px; height:155px;overflow:hidden;">'
        '<a href="/book/456.htm"><img src="/files/article/image/0/456/456s.jpg"></a>'
        '<a href="/book/456.htm">book</a></div>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/tags.php?t=x&v=0&page=2',
        compactListHtml,
      ),
      isTrue,
    );
  });

  test('Wenku8 assisted validation accepts tag list page markers', () {
    const tagListHtml =
        '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
        '<meta http-equiv="Content-Type" content="text/html; charset=gbk">'
        '<title>Tags含有 旅行 的轻小说 - 轻小说文库</title></head><body>'
        '<div id="left"><div class="block"><div class="blocktitle">Tags云集</div></div></div>'
        '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
        '<a href="book/123.htm">book one</a></div>'
        '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
        '<a href="/book/456.htm">book two</a></div>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/tags.php?t=x&v=0&page=1',
        tagListHtml,
      ),
      isTrue,
    );
  });

  test('Wenku8 assisted validation separates catalogue and chapter pages', () {
    const catalogueHtml =
        '<html><body><div id="content"><table class="css">'
        '<tr><td class="vcss">volume</td></tr>'
        '<tr><td class="ccss"><a href="/modules/article/reader.php?aid=123&amp;cid=456">chapter</a></td></tr>'
        '</table>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';
    const chapterHtml =
        '<html><body><div id="content">'
        '<ul id="contentdp"></ul>'
        '<p>这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。</p>'
        '<p>这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。</p>'
        '<p>这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。</p>'
        '<p>这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。这是章节正文。</p>'
        '</div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        catalogueHtml,
      ),
      isTrue,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        catalogueHtml.replaceAll(
          'reader.php?aid=123&amp;cid=',
          'reader.php?cid=',
        ),
      ),
      isTrue,
    );
    const looseCatalogueHtml =
        '<html><body>'
        '<a href="/modules/article/reader.php?cid=456">chapter</a>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</body></html>';
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        looseCatalogueHtml,
      ),
      isFalse,
    );
    final looseCatalogue = Parser.getCatalogue(looseCatalogueHtml);
    expect(looseCatalogue, hasLength(1));
    expect(looseCatalogue.single.chapters.single.cid, '456');
    const staticCatalogueHtml =
        '<html><body><div id="content"><table class="css">'
        '<tr><td class="vcss">volume</td></tr>'
        '<tr><td class="ccss"><a href="145082.htm">static chapter</a></td></tr>'
        '<tr><td class="ccss"><a href="/novel/3/123/145083.htm">static chapter 2</a></td></tr>'
        '</table>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        staticCatalogueHtml,
      ),
      isTrue,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/novel/3/123/index.htm',
        staticCatalogueHtml,
      ),
      isTrue,
    );
    final staticCatalogue = Parser.getCatalogue(staticCatalogueHtml);
    expect(staticCatalogue, hasLength(1));
    expect(staticCatalogue.single.chapters.map((chapter) => chapter.cid), [
      '145082',
      '145083',
    ]);
    const readerGatewayHtml =
        '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
        '<meta http-equiv="Content-Type" content="text/html; charset=gbk">'
        '<title>崩坏世界的魔杖匠人小说在线阅读与TXT下载</title>'
        '</head><body>'
        '<a href="/novel/3/123/index.htm">小说在线阅读</a>'
        '<a href="/modules/article/txtarticle.php?id=123">TXT下载</a>'
        '</body></html>';
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        readerGatewayHtml,
      ),
      isFalse,
    );
    expect(
      BrowserAssistedFetchService.wenku8ReaderCatalogueRedirectUrl(
        requestedUrl:
            'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        currentUrl: 'https://www.wenku8.net/modules/article/reader.php?aid=123',
        html: readerGatewayHtml,
      ),
      'https://www.wenku8.net/novel/3/123/index.htm',
    );
    const articleInfoLikeHtml =
        '<html><body><div id="content">'
        '<a href="/book/123.htm">book</a>'
        '<a href="/modules/article/reader.php?aid=123&amp;cid=456">start</a>'
        '<a href="/modules/article/reviews.php?aid=123">reviews</a>'
        '<a href="/modules/article/addbookcase.php?bid=123">add</a>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123',
        articleInfoLikeHtml,
      ),
      isFalse,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/articleinfo.php?id=123',
        articleInfoLikeHtml,
      ),
      isTrue,
    );
    const chapterHtmlWithNav =
        '<html><body>'
        '<a href="/modules/article/addbookcase.php?bid=123&amp;cid=456">bookmark</a>'
        '<a href="/modules/article/uservote.php?id=123">vote</a>'
        '<a href="/modules/article/reviews.php?aid=123">reviews</a>'
        '<div id="content">'
        '<a href="/modules/article/reader.php?aid=123&amp;cid=455">prev</a>'
        '<p>chapter body chapter body chapter body chapter body chapter body chapter body chapter body chapter body chapter body chapter body chapter body chapter body.</p>'
        '<a href="/modules/article/reader.php?aid=123&amp;cid=457">next</a>'
        '</div></body></html>';
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123&cid=456',
        catalogueHtml,
      ),
      isFalse,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123&cid=456',
        chapterHtml,
      ),
      isTrue,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/reader.php?aid=123&cid=456',
        chapterHtmlWithNav,
      ),
      isTrue,
    );
  });

  test('Wenku8 assisted validation rejects challenge and wrong home aliases', () {
    const challengeHtml =
        '<html><body>Just a moment<script>window._cf_chl_opt={}</script></body></html>';
    const listHtml =
        '<html><body><div id="content">'
        '<div style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;">'
        '<a href="/book/123.htm">book</a></div>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/index.php',
        challengeHtml,
      ),
      isFalse,
    );
    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/index.php',
        listHtml,
      ),
      isFalse,
    );
  });

  test('Wenku8 assisted validation rejects home html for list urls', () {
    const homeHtml =
        '<html><body><div id="centers"><div class="block">'
        '<div class="blocktitle">home</div><a href="/book/123.htm">book</a>'
        '<p>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</p>'
        '</div></div></body></html>';

    expect(
      BrowserAssistedFetchService.isUsableHtmlForUrl(
        'https://www.wenku8.cc/modules/article/tags.php?t=x&v=0&page=1',
        homeHtml,
      ),
      isFalse,
    );
  });
}
