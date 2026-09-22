import 'dart:convert';

import 'package:flutter/services.dart';

class LyricsRepository {
  const LyricsRepository();

  Future<List<LyricsDocument>> loadAll() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith('demo/') &&
              path.endsWith('.json') &&
              !path.endsWith('.schema.json'),
        )
        .toList();

    final documents = <LyricsDocument>[];
    for (final path in paths) {
      try {
        final source = await rootBundle.loadString(path);
        final decoded = jsonDecode(source);
        if (decoded is! Map<String, dynamic> || decoded['sentences'] is! List) {
          continue;
        }
        documents.add(LyricsDocument.fromJson(decoded, assetPath: path));
      } on FormatException {
        // 잘못된 JSON 한 개가 다른 정상 문서의 로딩을 막지 않도록 건너뛴다.
      }
    }

    documents.sort((a, b) => b.lines.length.compareTo(a.lines.length));
    return documents;
  }
}

class LyricsDocument {
  const LyricsDocument({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.lines,
  });

  factory LyricsDocument.fromJson(
    Map<String, dynamic> json, {
    required String assetPath,
  }) {
    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final filename = assetPath
        .split('/')
        .last
        .replaceAll(RegExp(r'\.json$'), '')
        .replaceAll('_', ' ');
    final title = _firstNotEmpty([_string(metadata['title']), filename]);
    final description = _string(metadata['description']).isNotEmpty
        ? _string(metadata['description'])
        : '일본어 데모 문장과 한국어 번역';
    final sentenceList = json['sentences'] as List<dynamic>;

    return LyricsDocument(
      title: title,
      description: description,
      assetPath: assetPath,
      sourceLanguage: _string(
        metadata['sourceLanguage'] ?? json['sourceLanguage'] ?? 'ja',
      ),
      targetLanguage: _string(
        metadata['targetLanguage'] ?? json['targetLanguage'] ?? 'ko',
      ),
      lines: sentenceList
          .whereType<Map<String, dynamic>>()
          .map(LyricsLine.fromJson)
          .toList(growable: false),
    );
  }

  final String title;
  final String description;
  final String assetPath;
  final String sourceLanguage;
  final String targetLanguage;
  final List<LyricsLine> lines;

  List<VocabularySummary> get vocabularyIndex => buildVocabularyIndex([this]);
}

class LyricsLine {
  const LyricsLine({
    required this.id,
    required this.original,
    required this.ruby,
    required this.translation,
    required this.vocabulary,
  });

  factory LyricsLine.fromJson(Map<String, dynamic> json) {
    final rawVocabulary = json['vocabulary'];
    return LyricsLine(
      id: _string(json['id']),
      original: _string(json['original']),
      ruby: _string(json['ruby']),
      translation: _string(json['translation']),
      vocabulary: rawVocabulary is List
          ? rawVocabulary
                .whereType<Map<String, dynamic>>()
                .map(VocabularyWord.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String original;
  final String ruby;
  final String translation;
  final List<VocabularyWord> vocabulary;

  bool matches(String query) {
    final needle = query.toLowerCase();
    return original.toLowerCase().contains(needle) ||
        ruby.toLowerCase().contains(needle) ||
        translation.toLowerCase().contains(needle) ||
        vocabulary.any((word) => word.matches(needle));
  }
}

class VocabularyWord {
  const VocabularyWord({
    required this.surface,
    required this.lemma,
    required this.reading,
    required this.pos,
    required this.posLabelKo,
    required this.meaning,
    this.note = '',
    this.tags = const [],
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return VocabularyWord(
      surface: _string(json['surface']),
      lemma: _string(json['lemma']),
      reading: _string(json['reading']),
      pos: _string(json['pos']),
      posLabelKo: _string(json['posLabelKo']),
      meaning: _string(json['meaning']),
      note: _string(json['note']),
      tags: rawTags is List
          ? rawTags.map(_string).where((tag) => tag.isNotEmpty).toList()
          : const [],
    );
  }

  final String surface;
  final String lemma;
  final String reading;
  final String pos;
  final String posLabelKo;
  final String meaning;
  final String note;
  final List<String> tags;

  bool matches(String query) {
    return surface.toLowerCase().contains(query) ||
        lemma.toLowerCase().contains(query) ||
        reading.toLowerCase().contains(query) ||
        meaning.toLowerCase().contains(query) ||
        posLabelKo.toLowerCase().contains(query);
  }
}

class VocabularySummary {
  const VocabularySummary({
    required this.word,
    required this.occurrences,
    required this.firstSeenOrder,
    this.sources = const [],
    this.meanings = const [],
    this.surfaces = const [],
    this.notes = const [],
  });

  final VocabularyWord word;
  final int occurrences;
  final int firstSeenOrder;
  final List<VocabularySource> sources;
  final List<String> meanings;
  final List<String> surfaces;
  final List<String> notes;

  String get meaningLabel =>
      meanings.isEmpty ? word.meaning : meanings.join(' · ');

  String get bookmarkKey => vocabularyBookmarkKey(word);

  List<String> get sourceTitles => sources
      .map((source) => source.documentTitle)
      .toSet()
      .toList(growable: false);

  bool matches(String query) {
    final needle = query.toLowerCase();
    return word.matches(needle) ||
        meanings.any((value) => value.toLowerCase().contains(needle)) ||
        surfaces.any((value) => value.toLowerCase().contains(needle)) ||
        notes.any((value) => value.toLowerCase().contains(needle)) ||
        sources.any((source) => source.matches(needle));
  }
}

class VocabularySource {
  const VocabularySource({
    required this.documentPath,
    required this.documentTitle,
    required this.lineId,
  });

  final String documentPath;
  final String documentTitle;
  final String lineId;

  String get key => '$documentPath|$lineId';

  bool matches(String query) {
    return documentTitle.toLowerCase().contains(query) ||
        lineId.toLowerCase().contains(query);
  }
}

String vocabularyBookmarkKey(VocabularyWord word) {
  final lemma = word.lemma.trim().toLowerCase();
  final surface = word.surface.trim().toLowerCase();
  return '${lemma.isEmpty ? surface : lemma}|${word.reading.trim()}';
}

List<VocabularySummary> buildVocabularyIndex(
  Iterable<LyricsDocument> documents,
) {
  final index = <String, _VocabularyAccumulator>{};
  var order = 0;

  for (final document in documents) {
    for (final line in document.lines) {
      for (final word in line.vocabulary) {
        final key = vocabularyBookmarkKey(word);
        final accumulator = index.putIfAbsent(
          key,
          () => _VocabularyAccumulator(word: word, firstSeenOrder: order++),
        );
        accumulator.add(
          word,
          VocabularySource(
            documentPath: document.assetPath,
            documentTitle: document.title,
            lineId: line.id,
          ),
        );
      }
    }
  }

  return index.values.map((item) => item.toSummary()).toList(growable: false);
}

class _VocabularyAccumulator {
  _VocabularyAccumulator({required this.word, required this.firstSeenOrder});

  final VocabularyWord word;
  final int firstSeenOrder;
  int occurrences = 0;
  final List<VocabularySource> sources = [];
  final Set<String> sourceKeys = {};
  final Set<String> meanings = {};
  final Set<String> surfaces = {};
  final Set<String> notes = {};

  void add(VocabularyWord value, VocabularySource source) {
    occurrences += 1;
    if (sourceKeys.add(source.key)) sources.add(source);
    if (value.meaning.isNotEmpty) meanings.add(value.meaning);
    if (value.surface.isNotEmpty) surfaces.add(value.surface);
    if (value.note.isNotEmpty) notes.add(value.note);
  }

  VocabularySummary toSummary() {
    return VocabularySummary(
      word: word,
      occurrences: occurrences,
      firstSeenOrder: firstSeenOrder,
      sources: List.unmodifiable(sources),
      meanings: meanings.toList(growable: false),
      surfaces: surfaces.toList(growable: false),
      notes: notes.toList(growable: false),
    );
  }
}

String _string(Object? value) => value?.toString() ?? '';

String _firstNotEmpty(Iterable<String> values) =>
    values.firstWhere((value) => value.isNotEmpty, orElse: () => '');
