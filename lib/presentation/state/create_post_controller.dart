import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';

enum SubmitStatus { idle, submitting, success, error }

class CreatePostController extends ChangeNotifier {
  CreatePostController(this._repo);

  final PostRepository _repo;

  SubmitStatus status = SubmitStatus.idle;
  AppException? error;
  Post? created;

  static String? validateTitle(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Введите заголовок';
    if (t.length < 5) return 'Минимум 5 символов';
    if (t.length > 100) return 'Максимум 100 символов';
    return null;
  }

  static String? validateBody(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Введите текст поста';
    if (t.length < 10) return 'Минимум 10 символов';
    if (t.length > 1000) return 'Максимум 1000 символов';
    return null;
  }

  static String? validateUser(int? v) => v == null ? 'Выберите автора' : null;

  /// Возвращает true при успехе. Повторные нажатия во время запроса игнорируются.
  Future<bool> submit(
      {required String title, required String body, required int userId}) async {
    if (status == SubmitStatus.submitting) return false;
    status = SubmitStatus.submitting;
    error = null;
    notifyListeners();
    try {
      created = await _repo.createPost(
          title: title.trim(), body: body.trim(), userId: userId);
      status = SubmitStatus.success;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      error = e;
      status = SubmitStatus.error;
      notifyListeners();
      return false;
    }
  }
}
