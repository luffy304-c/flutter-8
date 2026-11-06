import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable()
class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
    this.createdLocally = false,
  });

  final int userId;
  final int id;
  final String title;
  final String body;

  /// Серверный JSONPlaceholder не сохраняет посты, поэтому созданный пост
  /// помечается как локальный.
  @JsonKey(defaultValue: false)
  final bool createdLocally;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({int? id, bool? createdLocally}) => Post(
        userId: userId,
        id: id ?? this.id,
        title: title,
        body: body,
        createdLocally: createdLocally ?? this.createdLocally,
      );
}

/// Тело POST /posts.
@JsonSerializable()
class CreatePostRequest {
  const CreatePostRequest(
      {required this.title, required this.body, required this.userId});

  final String title;
  final String body;
  final int userId;

  factory CreatePostRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePostRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePostRequestToJson(this);
}
