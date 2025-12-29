import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchManager {
  static const String _key = 'recent_searches';
  static const int _maxItems = 10;

  /// Get recent searches
  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// Add a search query
  static Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_key) ?? [];

    // Remove if already exists
    searches.remove(query);

    // Add to beginning
    searches.insert(0, query);

    // Keep only max items
    if (searches.length > _maxItems) {
      searches = searches.sublist(0, _maxItems);
    }

    await prefs.setStringList(_key, searches);
  }

  /// Remove a search query
  static Future<void> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_key) ?? [];
    searches.remove(query);
    await prefs.setStringList(_key, searches);
  }

  /// Clear all searches
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
