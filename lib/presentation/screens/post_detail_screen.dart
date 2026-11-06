import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../state/post_detail_controller.dart';
import '../widgets/state_views.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          PostDetailController(context.read<PostRepository>(), post)..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostDetailController>();
    return Scaffold(
      appBar: AppBar(title: Text('Пост ${c.isLocal ? '(локальный)' : '#${c.initial.id}'}')),
      body: switch (c.status) {
        DetailStatus.loading => const Center(child: CircularProgressIndicator()),
        DetailStatus.error =>
          ErrorView(message: c.error!.message, onRetry: c.load),
        DetailStatus.success => _content(context, c),
      },
    );
  }

  Widget _content(BuildContext context, PostDetailController c) {
    final post = c.post!;
    final text = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (c.isLocal)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: InfoBanner(
              icon: Icons.info,
              text: 'Создан локально: сервер не хранит POST-изменения.'),
        ),
      Text(post.title, style: text.headlineSmall),
      const SizedBox(height: 8),
      Text(post.body),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(c.author?.name ?? 'Автор ${post.userId}'),
          subtitle: c.author == null
              ? null
              : Text([
                  c.author!.email,
                  if (c.author!.company != null) c.author!.company!.name,
                  if (c.author!.address?.city != null) c.author!.address!.city!,
                ].join('\n')),
          isThreeLine: c.author != null,
        ),
      ),
      const SizedBox(height: 16),
      Text('Комментарии (${c.comments.length})', style: text.titleMedium),
      const SizedBox(height: 8),
      if (c.comments.isEmpty)
        const Text('Комментариев нет.')
      else
        for (final cm in c.comments)
          Card(
            child: ListTile(
              title: Text(cm.name),
              subtitle: Text('${cm.email}\n${cm.body}'),
              isThreeLine: true,
            ),
          ),
    ]);
  }
}
