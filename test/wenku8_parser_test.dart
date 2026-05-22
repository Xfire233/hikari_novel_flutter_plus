import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/network/parser.dart';

void main() {
  test('Wenku8 recommend parser tolerates unexpected home html', () {
    expect(
      Parser.getRecommend('<html><body>temporary failure</body></html>'),
      isEmpty,
    );
  });
}
