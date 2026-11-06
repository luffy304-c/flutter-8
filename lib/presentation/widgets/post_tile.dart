import 'package:flutter/material.dart';

import '../../data/models/post.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            child: Text(post.createdLocally ? '★' : '${post.id}')),
        title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              Chip(
                label: Text('userId: ${post.userId}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              if (post.createdLocally)
                const Chip(
                  label: Text('создан локально'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
