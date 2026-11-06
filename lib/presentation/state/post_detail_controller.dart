import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';

enum DetailStatus { loading, success, error }

class PostDetailController extends ChangeNotifier {
  PostDetailController(this._repo, this.initial);

  final PostRepository _repo;
  final Post initial;

  DetailStatus status = DetailStatus.loading;
  Post? post;
  User? author;
  List<Comment> comments = const [];
  AppException? error;

  bool get isLocal => initial.createdLocally || initial.id < 0;

  Future<void> load() async {
    status = DetailStatus.loading;
    error = null;
    notifyListeners();
    try {
      if (isLocal) {
        post = initial;
        author = await _safeUser(initial.userId);
        comments = const [];
      } else {
        final results = await Future.wait([
          _repo.getPost(initial.id),
          _repo.getComments(initial.id),
          _safeUser(initial.userId),
        ]);
        post = results[0] as Post;
        comments = results[1] as List<Comment>;
        author = results[2] as User?;
      }
      status = DetailStatus.success;
    } on AppException catch (e) {
      error = e;
      status = DetailStatus.error;
    }
    notifyListeners();
  }

  // Автор — вспомогательная информация, её отсутствие не ломает экран.
  Future<User?> _safeUser(int id) async {
    try {
      return await _repo.getUser(id);
    } catch (_) {
      return null;
    }
  }
}
