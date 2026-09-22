import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_lyrics/main.dart';
import 'package:tsuki_lyrics/src/lyrics_data.dart';
import 'package:tsuki_lyrics/src/viewer_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test('demo documents have matching ruby and unique IDs', () {
    final ids = <String>{};
    final documents = Directory('demo').listSync().whereType<File>().map((
      file,
    ) {
      return LyricsDocument.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        assetPath: file.path,
      );
    }).toList();
    expect(documents, hasLength(2));
    final ruby = RegExp(r'｜([^《]+)《([^》]+)》');
    for (final document in documents) {
      expect(document.lines, hasLength(3));
      for (final line in document.lines) {
        expect(ids.add(line.id), isTrue);
        expect(
          line.ruby.replaceAllMapped(ruby, (match) => match[1]!),
          line.original,
        );
        expect(line.translation, isNotEmpty);
        expect(line.vocabulary, isNotEmpty);
      }
    }
    final index = buildVocabularyIndex(documents);
    final book = index.singleWhere((entry) => entry.word.lemma == '本');
    expect(book.occurrences, 2);
    expect(book.sourceTitles, containsAll(['아침 준비', '도서관에서']));
    expect(book.matches('ほん'), isTrue);
    expect(book.matches('책'), isTrue);
  });

  test('bookmarks and display settings survive a reload', () async {
    final preferences = await ViewerPreferences.load();
    await preferences.setRuby(false);
    await preferences.setTranslation(false);
    await preferences.setBookmarks({'本|ほん'});
    final reloaded = await ViewerPreferences.load();
    expect(reloaded.showRuby, isFalse);
    expect(reloaded.showTranslation, isFalse);
    expect(reloaded.bookmarks, {'本|ほん'});
  });

  testWidgets('reader searches and hides translations', (tester) async {
    await tester.pumpWidget(const LyricsStudyApp());
    await tester.pumpAndSettle();
    expect(find.text('달빛 가사'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search')), '사전을');
    await tester.pumpAndSettle();
    // Choose the matching document regardless of asset ordering.
    await tester.tap(find.byKey(const Key('document-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도서관에서').last);
    await tester.pumpAndSettle();
    expect(find.text('도서관에서 작은 사전을 빌립니다.'), findsOneWidget);
    expect(find.text('창문 가까이에서 책을 읽습니다.'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, '번역'));
    await tester.pumpAndSettle();
    expect(find.text('도서관에서 작은 사전을 빌립니다.'), findsNothing);
    await tester.enterText(find.byKey(const Key('search')), '일치하지 않는 검색');
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vocabulary bookmarks persist and filter', (tester) async {
    await tester.pumpWidget(const LyricsStudyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('어휘'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('북마크 저장').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '북마크만'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('북마크 해제'), findsOneWidget);
    expect(find.byTooltip('북마크 저장'), findsNothing);
    await tester.tap(find.byTooltip('북마크 해제'));
    await tester.pumpAndSettle();
    expect(find.text('표시할 어휘가 없습니다.'), findsOneWidget);
  });

  testWidgets('quiz locks answers, reports correction and advances', (
    tester,
  ) async {
    await tester.pumpWidget(const LyricsStudyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('document-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아침 준비').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀴즈'));
    await tester.pumpAndSettle();
    expect(find.text('「机」의 뜻은?'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '공책'));
    await tester.pumpAndSettle();
    expect(find.text('정답: 책상'), findsOneWidget);
    final options = tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(options.every((button) => button.onPressed == null), isTrue);
    await tester.ensureVisible(find.text('다음 문제'));
    await tester.tap(find.text('다음 문제'));
    await tester.pumpAndSettle();
    expect(find.text('「本」의 뜻은?'), findsOneWidget);
    expect(find.text('2 / 6 · 정답 0개'), findsOneWidget);
  });
}
