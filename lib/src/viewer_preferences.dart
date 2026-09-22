import 'package:shared_preferences/shared_preferences.dart';

/// The demo has a separate Android ID and preference namespace.
class ViewerPreferences {
  static const _prefix = 'public_demo.';

  ViewerPreferences._(this._store);
  final SharedPreferences _store;

  static Future<ViewerPreferences> load() async =>
      ViewerPreferences._(await SharedPreferences.getInstance());

  bool get showRuby => _store.getBool('${_prefix}ruby') ?? true;
  bool get showTranslation => _store.getBool('${_prefix}translation') ?? true;
  Set<String> get bookmarks =>
      (_store.getStringList('${_prefix}bookmarks') ?? []).toSet();

  Future<bool> setRuby(bool value) => _store.setBool('${_prefix}ruby', value);
  Future<bool> setTranslation(bool value) =>
      _store.setBool('${_prefix}translation', value);
  Future<bool> setBookmarks(Set<String> values) =>
      _store.setStringList('${_prefix}bookmarks', values.toList()..sort());
}
