import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/dio_client.dart';
import 'data/local/post_cache.dart';
import 'data/remote/post_api.dart';
import 'data/repositories/post_repository.dart';
import 'presentation/screens/post_list_screen.dart';
import 'presentation/state/post_list_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final client = DioClient(); // единый Dio
  final repo = PostRepositoryImpl(PostApi(client.dio), PostCache());
  runApp(PostExplorerApp(repository: repo));
}

class PostExplorerApp extends StatelessWidget {
  const PostExplorerApp({super.key, required this.repository});

  final PostRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: repository),
        ChangeNotifierProvider(
            create: (_) => PostListController(repository)..init()),
      ],
      child: MaterialApp(
        title: 'Post Explorer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const PostListScreen(),
      ),
    );
  }
}
