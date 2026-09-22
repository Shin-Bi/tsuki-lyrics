import 'package:flutter/material.dart';

import 'aozora_ruby_text.dart';
import 'lyrics_data.dart';
import 'viewer_preferences.dart';

class LyricsViewerPage extends StatefulWidget {
  const LyricsViewerPage({super.key, required this.documents});

  final List<LyricsDocument> documents;

  @override
  State<LyricsViewerPage> createState() => _LyricsViewerPageState();
}

class _LyricsViewerPageState extends State<LyricsViewerPage> {
  ViewerPreferences? _preferences;
  int _documentIndex = 0;
  int _tab = 0;
  String _query = '';
  bool _showRuby = true;
  bool _showTranslation = true;
  bool _bookmarksOnly = false;
  Set<String> _bookmarks = {};

  LyricsDocument get _document => widget.documents[_documentIndex];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await ViewerPreferences.load();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _showRuby = preferences.showRuby;
      _showTranslation = preferences.showTranslation;
      _bookmarks = preferences.bookmarks;
    });
  }

  Future<void> _toggleBookmark(String key) async {
    setState(() {
      if (!_bookmarks.add(key)) _bookmarks.remove(key);
    });
    await _preferences?.setBookmarks(_bookmarks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('달빛 가사'),
            Text('공개 데모 · 직접 작성한 일상 예문', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '오픈소스 라이선스',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: '달빛 가사 · 공개 데모',
              applicationVersion: '1.0.0',
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _preferences == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<int>(
                      key: const Key('document-picker'),
                      initialValue: _documentIndex,
                      decoration: const InputDecoration(labelText: '읽을 문서'),
                      items: [
                        for (
                          var index = 0;
                          index < widget.documents.length;
                          index++
                        )
                          DropdownMenuItem(
                            value: index,
                            child: Text(widget.documents[index].title),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _documentIndex = value);
                      },
                    ),
                  ),
                  if (_tab != 2)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        key: const Key('search'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '일본어 · 읽기 · 한국어 검색',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ),
                  Expanded(
                    child: switch (_tab) {
                      0 => _buildReading(),
                      1 => _buildVocabulary(),
                      _ => _VocabularyQuiz(
                        key: ValueKey(_document.assetPath),
                        words: _document.vocabularyIndex,
                      ),
                    },
                  ),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '읽기'),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            label: '어휘',
          ),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: '퀴즈'),
        ],
      ),
    );
  }

  Widget _buildReading() {
    final lines = _document.lines
        .where((line) => line.matches(_query))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('후리가나'),
              selected: _showRuby,
              onSelected: (value) {
                setState(() => _showRuby = value);
                _preferences?.setRuby(value);
              },
            ),
            FilterChip(
              label: const Text('번역'),
              selected: _showTranslation,
              onSelected: (value) {
                setState(() => _showTranslation = value);
                _preferences?.setTranslation(value);
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_document.description),
        ),
        if (lines.isEmpty) const Text('검색 결과가 없습니다.'),
        for (final line in lines)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AozoraRubyText(
                    line.ruby.isEmpty ? line.original : line.ruby,
                    showRuby: _showRuby,
                  ),
                  if (_showTranslation) ...[
                    const SizedBox(height: 12),
                    Text(line.translation),
                  ],
                  if (line.vocabulary.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('문장 어휘 ${line.vocabulary.length}개'),
                      children: [
                        for (final word in line.vocabulary)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${word.surface} · ${word.reading}'),
                            subtitle: Text(
                              '${word.posLabelKo} · ${word.meaning}',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVocabulary() {
    final words = _document.vocabularyIndex
        .where(
          (word) =>
              word.matches(_query) &&
              (!_bookmarksOnly || _bookmarks.contains(word.bookmarkKey)),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('북마크만'),
            selected: _bookmarksOnly,
            onSelected: (value) => setState(() => _bookmarksOnly = value),
          ),
        ),
        if (words.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('표시할 어휘가 없습니다.'),
          ),
        for (final entry in words)
          Card(
            child: ListTile(
              title: Text('${entry.word.lemma} · ${entry.word.reading}'),
              subtitle: Text(
                '${entry.word.posLabelKo} · ${entry.meaningLabel}\n'
                '문서에 ${entry.occurrences}회 등장',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: _bookmarks.contains(entry.bookmarkKey)
                    ? '북마크 해제'
                    : '북마크 저장',
                onPressed: () => _toggleBookmark(entry.bookmarkKey),
                icon: Icon(
                  _bookmarks.contains(entry.bookmarkKey)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VocabularyQuiz extends StatefulWidget {
  const _VocabularyQuiz({super.key, required this.words});
  final List<VocabularySummary> words;

  @override
  State<_VocabularyQuiz> createState() => _VocabularyQuizState();
}

class _VocabularyQuizState extends State<_VocabularyQuiz> {
  int _index = 0;
  int _score = 0;
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final words = widget.words;
    if (words.isEmpty) return const Center(child: Text('퀴즈에 사용할 어휘가 없습니다.'));
    if (_index == words.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '학습 완료 · $_score / ${words.length}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() {
                _index = 0;
                _score = 0;
                _answer = null;
              }),
              child: const Text('다시 풀기'),
            ),
          ],
        ),
      );
    }
    final question = words[_index].word;
    final alternatives =
        words.map((entry) => entry.word.meaning).toSet().toList()..sort();
    return ListView(
      key: ValueKey(_index),
      padding: const EdgeInsets.all(24),
      children: [
        Text('${_index + 1} / ${words.length} · 정답 $_score개'),
        const SizedBox(height: 24),
        Text(
          '「${question.lemma}」의 뜻은?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(question.reading),
        const SizedBox(height: 20),
        if (_answer != null) ...[
          Text(
            _answer == question.meaning ? '정답입니다!' : '정답: ${question.meaning}',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() {
              _index++;
              _answer = null;
            }),
            child: Text(_index + 1 == words.length ? '결과 보기' : '다음 문제'),
          ),
        ],
        for (final meaning in alternatives)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _answer != null
                  ? null
                  : () => setState(() {
                      _answer = meaning;
                      if (meaning == question.meaning) _score++;
                    }),
              child: Text(meaning),
            ),
          ),
      ],
    );
  }
}
