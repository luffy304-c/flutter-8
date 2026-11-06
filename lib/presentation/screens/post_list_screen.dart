import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/post_repository.dart';
import '../state/create_post_controller.dart';
import '../state/post_list_controller.dart';
import '../widgets/post_tile.dart';
import '../widgets/state_views.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) {
      context.read<PostListController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final list = context.read<PostListController>();
    final repo = context.read<PostRepository>();
    final post = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => CreatePostController(repo),
        child: CreatePostScreen(authorIds: list.authorIds, nameOf: list.authorName),
      ),
    ));
    if (post != null) await list.addLocalPost(post);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostListController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Post Explorer')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Новый пост'),
      ),
      body: Column(children: [
        _Filters(controller: c, search: _search),
        if (c.status == ListStatus.cached)
          InfoBanner(
            icon: Icons.cloud_off,
            text: c.isRefreshing
                ? 'Показаны сохранённые данные, обновляем…'
                : 'Показаны кэшированные данные'
                    '${c.error != null ? ': ${c.error!.message}' : ''}',
          ),
        if (c.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body(c)),
      ]),
    );
  }

  Widget _body(PostListController c) {
    switch (c.status) {
      case ListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ListStatus.error:
        return ErrorView(message: c.error!.message, onRetry: c.refresh);
      case ListStatus.empty:
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 300,
                child: EmptyView(
                    message: c.query.isNotEmpty
                        ? 'Ничего не найдено среди загруженных постов (${c.loadedCount}).'
                        : 'Постов пока нет.'),
              ),
            ],
          ),
        );
      case ListStatus.success:
      case ListStatus.cached:
        final posts = c.visiblePosts;
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 88, top: 4),
            itemCount: posts.length + 1,
            itemBuilder: (context, i) {
              if (i == posts.length) return _footer(c);
              final post = posts[i];
              return PostTile(
                post: post,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostDetailScreen(post: post),
                )),
              );
            },
          ),
        );
    }
  }

  Widget _footer(PostListController c) {
    switch (c.loadMoreStatus) {
      case LoadMoreStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      case LoadMoreStatus.error:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(c.loadMoreError?.message ?? 'Ошибка загрузки',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: c.retryLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ]),
        );
      case LoadMoreStatus.idle:
        if (!c.hasMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Это все посты')),
          );
        }
        return const SizedBox(height: 48);
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.search});

  final PostListController controller;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(children: [
        TextField(
          controller: search,
          onChanged: c.setQuery,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Поиск по заголовку',
            helperText: 'Только среди загруженных постов: ${c.loadedCount}',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: c.userFilter,
              key: ValueKey(c.userFilter),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Автор',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Все посты')),
                for (final id in c.authorIds)
                  DropdownMenuItem<int?>(
                      value: id,
                      child: Text(c.authorName(id),
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: c.setUserFilter,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Сортировка по ID',
            onPressed: () => c.setSort(c.sort == SortOrder.idAsc
                ? SortOrder.idDesc
                : SortOrder.idAsc),
            icon: Icon(c.sort == SortOrder.idAsc
                ? Icons.arrow_upward
                : Icons.arrow_downward),
          ),
          IconButton(
            tooltip: 'Сбросить фильтры',
            onPressed: c.hasActiveFilters
                ? () {
                    search.clear();
                    c.resetFilters();
                  }
                : null,
            icon: const Icon(Icons.filter_alt_off),
          ),
        ]),
      ]),
    );
  }
}
