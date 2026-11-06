import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/core/network/api_interceptor.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/presentation/state/create_post_controller.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock-адаптер Dio: тесты не зависят от интернета.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json200(Object body, {int status = 200}) => ResponseBody.fromString(
    jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

Map<String, dynamic> postJson(int id, {int userId = 1}) =>
    {'userId': userId, 'id': id, 'title': 'title $id', 'body': 'body $id'};

PostRepositoryImpl repoWith(MockAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test'))
    ..httpClientAdapter = adapter
    ..interceptors.addAll([ApiInterceptor(), ErrorInterceptor()]);
  return PostRepositoryImpl(PostApi(dio), PostCache());
}

class FakeRepo implements PostRepository {
  int calls = 0;
  Completer<List<Post>>? gate;
  List<Post> Function(int page, int? userId) pages =
      (page, userId) => List.generate(
          10, (i) => Post(userId: 1, id: (page - 1) * 10 + i + 1, title: 't', body: 'b'));

  @override
  Future<List<Post>> getPosts(
      {required int page,
      required int limit,
      int? userId,
      CancelToken? cancelToken}) async {
    calls++;
    if (gate != null && page > 1) return gate!.future;
    return pages(page, userId);
  }

  @override
  Future<List<Post>> readCachedPosts() async => [];
  @override
  Future<void> cachePosts(List<Post> posts) async {}
  @override
  Future<List<Post>> readLocalPosts() async => [];
  @override
  Future<void> saveLocalPosts(List<Post> posts) async {}
  @override
  Future<List<User>> getUsers() async => [];
  @override
  Future<Post> getPost(int id) => throw UnimplementedError();
  @override
  Future<List<Comment>> getComments(int postId) => throw UnimplementedError();
  @override
  Future<Post> createPost(
          {required String title, required String body, required int userId}) =>
      throw UnimplementedError();
  @override
  Future<User> getUser(int id) => throw UnimplementedError();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1. JSON успешно преобразуется в Post (+ nullable и вложенные модели)', () {
    final post = Post.fromJson(postJson(5, userId: 3));
    expect(post.id, 5);
    expect(post.userId, 3);
    expect(post.createdLocally, false);

    final user = User.fromJson({
      'id': 1,
      'name': 'A',
      'username': 'a',
      'email': 'a@a.com',
      'company': {'name': 'ACME'},
    });
    expect(user.phone, isNull);
    expect(user.company!.name, 'ACME');
    expect(user.address, isNull);
  });

  test('2. Post преобразуется обратно в JSON', () {
    const post = Post(userId: 2, id: 7, title: 'T', body: 'B');
    expect(post.toJson(), {
      'userId': 2,
      'id': 7,
      'title': 'T',
      'body': 'B',
      'createdLocally': false,
    });
  });

  test('3. Репозиторий успешно загружает посты (GET с пагинацией)', () async {
    final adapter = MockAdapter((o) => json200([postJson(1), postJson(2)]));
    final posts = await repoWith(adapter).getPosts(page: 1, limit: 10);
    expect(posts.length, 2);
    final req = adapter.requests.single;
    expect(req.path, '/posts');
    expect(req.queryParameters, {'_page': 1, '_limit': 10});
    expect(req.headers['X-Client'], 'post-explorer');
  });

  test('4. Ошибка сервера 500 превращается в AppException.server', () async {
    final repo = repoWith(MockAdapter((o) => json200({}, status: 500)));
    expect(
      repo.getPosts(page: 1, limit: 10),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.server)
          .having((e) => e.statusCode, 'status', 500)),
    );
  });

  test('4b. Некорректный JSON даёт ошибку парсинга, а не падение', () async {
    final repo = repoWith(MockAdapter((o) => json200([{'id': 1}])));
    expect(
      repo.getPosts(page: 1, limit: 10),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.parse)),
    );
  });

  test('5. Фильтрация по автору и заголовку', () async {
    final repo = FakeRepo()
      ..pages = (page, userId) => [
            const Post(userId: 1, id: 1, title: 'apple pie', body: 'b'),
            const Post(userId: 2, id: 2, title: 'banana', body: 'b'),
            const Post(userId: 2, id: 3, title: 'apple tart', body: 'b'),
          ];
    final c = PostListController(repo);
    await c.refresh();
    expect(c.visiblePosts.length, 3);

    c.setQuery('APPLE');
    expect(c.visiblePosts.map((p) => p.id), [1, 3]);

    c.setSort(SortOrder.idDesc);
    expect(c.visiblePosts.map((p) => p.id), [3, 1]);
    c.dispose();
  });

  test('6. Защита от дублирующейся загрузки страницы', () async {
    final repo = FakeRepo();
    final c = PostListController(repo);
    await c.refresh();
    expect(repo.calls, 1);

    repo.gate = Completer();
    final f1 = c.loadMore();
    final f2 = c.loadMore(); // повторный вызов, пока первый не завершён
    final f3 = c.loadMore();
    expect(repo.calls, 2, reason: 'страница 2 запрошена один раз');

    repo.gate!.complete(repo.pages(2, null));
    await Future.wait([f1, f2, f3]);
    expect(c.visiblePosts.length, 20);
    c.dispose();
  });

  test('7. Смена фильтра сбрасывает старые страницы', () async {
    final repo = FakeRepo()
      ..pages = (page, userId) => [
            Post(userId: userId ?? 1, id: userId == null ? 1 : 100, title: 't', body: 'b'),
          ];
    final c = PostListController(repo);
    await c.refresh();
    await c.setUserFilter(4);
    expect(c.visiblePosts.map((p) => p.id), [100]);
    expect(c.visiblePosts.every((p) => p.userId == 4), true);
    c.dispose();
  });

  test('8. POST /posts через mock-адаптер Dio', () async {
    final adapter = MockAdapter((o) {
      final body = o.data as Map<String, dynamic>;
      return json200({'id': 101, ...body}, status: 201);
    });
    final repo = repoWith(adapter);
    final post = await repo.createPost(title: 'Hello world', body: 'Long body text', userId: 3);
    expect(post.id, 101);
    expect(post.title, 'Hello world');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data,
        {'title': 'Hello world', 'body': 'Long body text', 'userId': 3});
  });

  test('9. Валидация формы и блокировка повторной отправки', () async {
    expect(CreatePostController.validateTitle('abc'), isNotNull);
    expect(CreatePostController.validateTitle('hello'), isNull);
    expect(CreatePostController.validateBody('short'), isNotNull);
    expect(CreatePostController.validateBody('x' * 1001), isNotNull);
    expect(CreatePostController.validateUser(null), isNotNull);

    var calls = 0;
    final repo = repoWith(MockAdapter((o) {
      calls++;
      return json200({'id': 101, 'userId': 1, 'title': 'hello', 'body': 'bodybodybody'});
    }));
    final c = CreatePostController(repo);
    final f1 = c.submit(title: 'hello', body: 'bodybodybody', userId: 1);
    final f2 = c.submit(title: 'hello', body: 'bodybodybody', userId: 1);
    expect(await f2, false);
    expect(await f1, true);
    expect(calls, 1);
  });
}
