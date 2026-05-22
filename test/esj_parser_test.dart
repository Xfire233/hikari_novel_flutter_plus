import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';

void main() {
  test('extracts ESJ account name without EXP text', () {
    const html = '''
      <nav class="navbar">
        <a class="dropdown-toggle" href="/my/view">
          TestUser
          <span>3104 EXP</span>
        </a>
      </nav>
    ''';

    expect(EsjParser.accountName(html), 'TestUser');
  });

  test('extracts ESJ account name when EXP is attached to adjacent text', () {
    const html = '''
      <nav class="navbar">
        <a class="dropdown-toggle" href="/my/view">
          TestUser 3104 EXP會員中心
        </a>
      </nav>
    ''';

    expect(EsjParser.accountName(html), 'TestUser 會員中心');
  });

  test('keeps trailing digits that are part of ESJ account name', () {
    const html = '''
      <nav class="navbar">
        <a class="dropdown-toggle" href="/my/view">
          X_fire233
          <span>3104 EXP</span>
        </a>
      </nav>
    ''';

    expect(EsjParser.accountName(html), 'X_fire233');
  });

  test('does not merge ESJ nested EXP span into account name', () {
    const html = '''
      <nav class="navbar">
        <a class="dropdown-toggle" href="/my/view">X_fire233<span>3104 EXP</span></a>
      </nav>
    ''';

    expect(EsjParser.accountName(html), 'X_fire233');
  });

  test('keeps trailing nickname digits when EXP score is glued to them', () {
    const html = '''
      <nav class="navbar">
        <a class="dropdown-toggle" href="/my/view">X_fire2333104 EXP</a>
      </nav>
    ''';

    expect(EsjParser.accountName(html), 'X_fire233');
  });
}
