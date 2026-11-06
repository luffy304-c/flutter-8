import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/create_post_controller.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen(
      {super.key, required this.authorIds, required this.nameOf});

  final List<int> authorIds;
  final String Function(int) nameOf;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _userId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final c = context.read<CreatePostController>();
    final ok =
        await c.submit(title: _title.text, body: _body.text, userId: _userId!);
    if (!mounted) return;
    if (ok) {
      final p = c.created!;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ответ сервера'),
          content: Text('id: ${p.id}\nuserId: ${p.userId}\n'
              'title: ${p.title}\nbody: ${p.body}\n\n'
              'Пост добавлен в локальный список (создан локально): '
              'сервер не сохраняет POST-изменения.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'))
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(p);
    } else if (c.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(c.error!.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreatePostController>();
    final busy = c.status == SubmitStatus.submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Новый пост')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _title,
            enabled: !busy,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: 'Заголовок (5–100)', border: OutlineInputBorder()),
            validator: CreatePostController.validateTitle,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _body,
            enabled: !busy,
            maxLength: 1000,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Текст (10–1000)', border: OutlineInputBorder()),
            validator: CreatePostController.validateBody,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _userId,
            decoration: const InputDecoration(
                labelText: 'Автор', border: OutlineInputBorder()),
            items: [
              for (final id in widget.authorIds)
                DropdownMenuItem(value: id, child: Text(widget.nameOf(id))),
            ],
            onChanged: busy ? null : (v) => setState(() => _userId = v),
            validator: CreatePostController.validateUser,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Отправить'),
          ),
        ]),
      ),
    );
  }
}
