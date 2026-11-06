import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';

enum ListStatus { loading, success, error, cached, empty }

enum LoadMoreStatus { idle, loading, error }

enum SortOrder { idAsc, idDesc }

class PostListController extends ChangeNotifier {
  PostListController(this._repo);

  static const pageSize = 10;

  final PostRepository _repo;

  List<Post> _server = [];
  List<Post> _local = [];
  List<User> _users = [];

  int _page = 0;
  bool _hasMore = true;
  final Set<int> _requestedPages = {};

  int? _userFilter;
  String _query = '';
  SortOrder _sort = SortOrder.idAsc;

  bool _loadingFirst = false;
  bool _fromCache = false;
  AppException? _error;
  LoadMoreStatus _loadMore = LoadMoreStatus.idle;
  AppException? _loadMoreError;

  CancelToken? _cancelToken;
  int _generation = 0;
  bool _disposed = false;

  // ---------- getters ----------
  int? get userFilter => _userFilter;
  String get query => _query;
  SortOrder get sort => _sort;
  bool get hasMore => _hasMore;
  bool get fromCache => _fromCache;
  bool get isRefreshing => _loadingFirst && _server.isNotEmpty;
  LoadMoreStatus get loadMoreStatus => _loadMore;
  AppException? get error => _error;
  AppException? get loadMoreError => _loadMoreError;
  int get loadedCount => _server.length + _filteredLocal.length;
  bool get hasActiveFilters =>
      _userFilter != null || _query.isNotEmpty || _sort != SortOrder.idAsc;

  /// Список авторов; если /users недоступен — запасной список 1..10.
  List<User> get users => _users;
  List<int> get authorIds => _users.isNotEmpty
      ? _users.map((u) => u.id).toList()
      : List.generate(10, (i) => i + 1);
  String authorName(int id) {
    for (final u in _users) {
      if (u.id == id) return u.name;
    }
    return 'Автор $id';
  }

  Iterable<Post> get _filteredLocal =>
      _local.where((p) => _userFilter == null || p.userId == _userFilter);

  List<Post> get visiblePosts {
    final q = _query.trim().toLowerCase();
    bool match(Post p) => q.isEmpty || p.title.toLowerCase().contains(q);
    final server = _server
        .where((p) => _userFilter == null || p.userId == _userFilter)
        .where(match)
        .toList()
      ..sort((a, b) =>
          _sort == SortOrder.idAsc ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
    return [..._filteredLocal.where(match), ...server];
  }

  ListStatus get status {
    final empty = _server.isEmpty && _local.isEmpty;
    if (_loadingFirst && empty) return ListStatus.loading;
    if (_error != null && empty) return ListStatus.error;
    if (visiblePosts.isEmpty) {
      return _loadingFirst ? ListStatus.loading : ListStatus.empty;
    }
    return _fromCache ? ListStatus.cached : ListStatus.success;
  }

  // ---------- commands ----------
  Future<void> init() async {
    _local = await _repo.readLocalPosts();
    _server = await _repo.readCachedPosts();
    _fromCache = _server.isNotEmpty;
    _notify();
    _loadUsers();
    await refresh();
  }

  Future<void> _loadUsers() async {
    try {
      _users = await _repo.getUsers();
      _notify();
    } catch (_) {
      // Запасной список авторов используется автоматически.
    }
  }

  /// Первая страница заново (pull-to-refresh, повтор, смена фильтра).
  Future<void> refresh() async {
    _cancelToken?.cancel('refresh');
    final token = _cancelToken = CancelToken();
    final gen = ++_generation;

    _loadingFirst = true;
    _error = null;
    _loadMore = LoadMoreStatus.idle;
    _loadMoreError = null;
    _requestedPages
      ..clear()
      ..add(1);
    _notify();

    try {
      final posts = await _repo.getPosts(
          page: 1, limit: pageSize, userId: _userFilter, cancelToken: token);
      if (gen != _generation) return; // устаревший ответ
      _server = posts;
      _page = 1;
      _hasMore = posts.length >= pageSize;
      _fromCache = false;
      _loadingFirst = false;
      _notify();
      if (_userFilter == null) await _repo.cachePosts(_server);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _onFirstPageError(gen, AppException.fromDio(e));
    } on AppException catch (e) {
      _onFirstPageError(gen, e);
    }
  }

  Future<void> _onFirstPageError(int gen, AppException e) async {
    if (gen != _generation) return;
    debugPrint('First page error: $e');
    _error = e;
    _loadingFirst = false;
    _requestedPages.clear();
    if (_userFilter != null) {
      // Нет сети при активном фильтре: фильтруем кэш локально.
      final cached = await _repo.readCachedPosts();
      if (gen != _generation) return;
      _server = cached.where((p) => p.userId == _userFilter).toList();
    }
    _fromCache = _server.isNotEmpty;
    _hasMore = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (_loadingFirst || !_hasMore || _loadMore == LoadMoreStatus.loading) {
      return;
    }
    if (_error != null && _loadMore != LoadMoreStatus.error) return;
    final next = _page + 1;
    // Защита от повторной загрузки одной и той же страницы.
    if (_requestedPages.contains(next)) return;
    _requestedPages.add(next);

    final gen = _generation;
    final token = _cancelToken;
    _loadMore = LoadMoreStatus.loading;
    _loadMoreError = null;
    _notify();

    try {
      final posts = await _repo.getPosts(
          page: next, limit: pageSize, userId: _userFilter, cancelToken: token);
      if (gen != _generation) return;
      final ids = _server.map((p) => p.id).toSet();
      _server = [..._server, ...posts.where((p) => !ids.contains(p.id))];
      _page = next;
      _hasMore = posts.length >= pageSize;
      _loadMore = LoadMoreStatus.idle;
      _notify();
      if (_userFilter == null) await _repo.cachePosts(_server);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _onLoadMoreError(gen, next, AppException.fromDio(e));
    } on AppException catch (e) {
      _onLoadMoreError(gen, next, e);
    }
  }

  void _onLoadMoreError(int gen, int page, AppException e) {
    if (gen != _generation) return;
    debugPrint('Load more error: $e');
    _requestedPages.remove(page);
    _loadMore = LoadMoreStatus.error;
    _loadMoreError = e;
    _notify();
  }

  Future<void> retryLoadMore() => loadMore();

  /// Смена фильтра: старые страницы сбрасываются и не смешиваются с новыми.
  Future<void> setUserFilter(int? userId) async {
    if (userId == _userFilter) return;
    _userFilter = userId;
    _server = [];
    _page = 0;
    _hasMore = true;
    _fromCache = false;
    await refresh();
  }

  void setQuery(String value) {
    _query = value;
    _notify();
  }

  void setSort(SortOrder order) {
    _sort = order;
    _notify();
  }

  Future<void> resetFilters() async {
    _query = '';
    _sort = SortOrder.idAsc;
    if (_userFilter != null) {
      await setUserFilter(null);
    } else {
      _notify();
    }
  }

  /// Добавляет пост, созданный через POST, в локальный список.
  Future<void> addLocalPost(Post serverPost) async {
    final minId = _local.fold<int>(0, (m, p) => p.id < m ? p.id : m);
    final post = serverPost.copyWith(id: minId - 1, createdLocally: true);
    _local = [post, ..._local];
    _notify();
    await _repo.saveLocalPosts(_local);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel('dispose');
    super.dispose();
  }
}
