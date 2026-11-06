import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../core/error/app_exception.dart';
import '../local/post_cache.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../remote/post_api.dart';

abstract class PostRepository {
  Future<List<Post>> getPosts({
    required int page,
    required int limit,
    int? userId,
    CancelToken? cancelToken,
  });
  Future<Post> getPost(int id);
  Future<List<Comment>> getComments(int postId);
  Future<Post> createPost(
      {required String title, required String body, required int userId});
  Future<List<User>> getUsers();
  Future<User> getUser(int id);

  Future<List<Post>> readCachedPosts();
  Future<void> cachePosts(List<Post> posts);
  Future<List<Post>> readLocalPosts();
  Future<void> saveLocalPosts(List<Post> posts);
}

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl(this._api, this._cache);

  final PostApi _api;
  final PostCache _cache;

  @override
  Future<List<Post>> getPosts({
    required int page,
    required int limit,
    int? userId,
    CancelToken? cancelToken,
  }) =>
      _guard(() => userId == null
          ? _api.getPosts(page, limit, cancelToken: cancelToken)
          : _api.getPostsByUser(userId, page, limit,
              cancelToken: cancelToken));

  @override
  Future<Post> getPost(int id) => _guard(() => _api.getPost(id));

  @override
  Future<List<Comment>> getComments(int postId) =>
      _guard(() => _api.getComments(postId));

  @override
  Future<Post> createPost(
          {required String title, required String body, required int userId}) =>
      _guard(() => _api.createPost(
          CreatePostRequest(title: title, body: body, userId: userId)));

  @override
  Future<List<User>> getUsers() => _guard(_api.getUsers);

  @override
  Future<User> getUser(int id) => _guard(() => _api.getUser(id));

  @override
  Future<List<Post>> readCachedPosts() => _cache.readPosts();
  @override
  Future<void> cachePosts(List<Post> posts) => _cache.writePosts(posts);
  @override
  Future<List<Post>> readLocalPosts() => _cache.readLocalPosts();
  @override
  Future<void> saveLocalPosts(List<Post> posts) =>
      _cache.writeLocalPosts(posts);

  /// Приводит любые ошибки к [AppException].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      final error = e.error;
      if (error is AppException) throw error;
      if (e.type == DioExceptionType.cancel) rethrow;
      throw AppException.fromDio(e);
    } on CheckedFromJsonException catch (e) {
      debugPrint('JSON error: $e');
      throw AppException(AppErrorType.parse, technical: e.toString());
    } on TypeError catch (e) {
      debugPrint('JSON error: $e');
      throw AppException(AppErrorType.parse, technical: e.toString());
    } on FormatException catch (e) {
      debugPrint('JSON error: $e');
      throw AppException(AppErrorType.parse, technical: e.toString());
    } catch (e) {
      debugPrint('Unknown error: $e');
      throw AppException(AppErrorType.unknown, technical: e.toString());
    }
  }
}
