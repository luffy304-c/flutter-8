import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';

/// Простой локальный кэш на SharedPreferences.
class PostCache {
  static const _postsKey = 'cache_posts_v1';
  static const _localKey = 'local_posts_v1';

  Future<List<Post>> readPosts() => _read(_postsKey);
  Future<void> writePosts(List<Post> posts) => _write(_postsKey, posts);

  Future<List<Post>> readLocalPosts() => _read(_localKey);
  Future<void> writeLocalPosts(List<Post> posts) => _write(_localKey, posts);

  Future<List<Post>> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Повреждённый кэш не должен ронять приложение.
      return [];
    }
  }

  Future<void> _write(String key, List<Post> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }
}
