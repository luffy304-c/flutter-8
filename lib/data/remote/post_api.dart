import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';

part 'post_api.g.dart';

@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String? baseUrl}) = _PostApi;

  /// 1. GET /posts?_page=1&_limit=10
  @GET('/posts')
  Future<List<Post>> getPosts(
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @CancelRequest() CancelToken? cancelToken,
  });

  /// 2. GET /posts/{id}
  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);

  /// 3. GET /posts?userId={id}
  @GET('/posts')
  Future<List<Post>> getPostsByUser(
    @Query('userId') int userId,
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @CancelRequest() CancelToken? cancelToken,
  });

  /// 4. GET /posts/{id}/comments
  @GET('/posts/{id}/comments')
  Future<List<Comment>> getComments(@Path('id') int postId);

  /// 5. POST /posts
  @POST('/posts')
  Future<Post> createPost(@Body() CreatePostRequest body);

  /// Дополнительно: авторы.
  @GET('/users')
  Future<List<User>> getUsers();

  @GET('/users/{id}')
  Future<User> getUser(@Path('id') int id);
}
