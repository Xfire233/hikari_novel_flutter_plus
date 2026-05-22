import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';

void main() {
  testWidgets('renders source mark widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SourceMark(source: NovelSource.yamibo, size: 48)),
        ),
      ),
    );

    expect(find.byType(SourceMark), findsOneWidget);
  });
}
