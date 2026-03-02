import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postOwnerId;
  final String postId;
  final ScrollController? scrollController;

  const CommentsSheet({
    super.key,
    required this.postOwnerId,
    required this.postId,
    this.scrollController,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctrl = TextEditingController();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _replyTo; // {text, fio}

  CollectionReference get _commentsRef => FirebaseFirestore.instance
      .collection('posts')
      .doc(widget.postOwnerId)
      .collection('post')
      .doc(widget.postId)
      .collection('comments');

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final uid = _currentUid;
    if (text.isEmpty || uid == null) return;
    _ctrl.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    final authService = Provider.of<AuthService>(context, listen: false);
    final fio = await authService.getUserField(uid, 'fio') ?? '';
    final photo = await authService.getUserField(uid, 'photourl') ?? '';
    final data = {
      'userId': uid,
      'fio': fio,
      'photourl': photo,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (reply != null) {
      data['replyToText'] = reply['text'] as String;
      data['replyToFio'] = reply['fio'] as String;
    }
    await _commentsRef.add(data);
  }

  void _showCommentOptions(QueryDocumentSnapshot doc, String text) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _editComment(doc, text);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _commentsRef.doc(doc.id).delete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editComment(QueryDocumentSnapshot doc, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Редактировать комментарий'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0071BC)),
            onPressed: () async {
              Navigator.pop(context);
              final newText = ctrl.text.trim();
              if (newText.isEmpty) return;
              await _commentsRef.doc(doc.id).update({'text': newText, 'edited': true});
            },
            child: const Text('Сохранить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outline.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Комментарии',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _commentsRef.orderBy('timestamp').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Нет комментариев',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final photo = d['photourl'] as String? ?? '';
                  final fio = d['fio'] as String? ?? '';
                  final text = d['text'] as String? ?? '';
                  final commentEdited = d['edited'] as bool? ?? false;
                  final replyToText = d['replyToText'] as String?;
                  final replyToFio = d['replyToFio'] as String?;
                  DateTime? time;
                  if (d['timestamp'] != null) {
                    time = (d['timestamp'] as Timestamp).toDate();
                  }
                  final isOwner = d['userId'] == _currentUid;
                  return GestureDetector(
                    onLongPress: isOwner
                        ? () => _showCommentOptions(docs[i], text)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage:
                                photo.isNotEmpty ? NetworkImage(photo) : null,
                            backgroundColor: Colors.lightBlue.shade100,
                            child: photo.isEmpty
                                ? const Icon(Icons.person,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      fio,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    if (time != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '${time.day}.${time.month.toString().padLeft(2, '0')} '
                                        '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                            color: cs.onSurface.withValues(alpha: 0.5),
                                            fontSize: 11),
                                      ),
                                    ],
                                    if (commentEdited) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        'изм.',
                                        style: TextStyle(
                                            color: cs.onSurface.withValues(alpha: 0.4),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                                if (replyToText != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                      border: const Border(
                                        left: BorderSide(
                                          color: Color(0xFF0071BC),
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (replyToFio != null)
                                          Text(
                                            replyToFio,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0071BC),
                                            ),
                                          ),
                                        Text(
                                          replyToText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(text, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.reply_outlined,
                                size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _replyTo = {'text': text, 'fio': fio}),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_replyTo != null)
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Container(width: 3, height: 32, color: const Color(0xFF0071BC)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _replyTo!['fio'] as String,
                        style: const TextStyle(
                          color: Color(0xFF0071BC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _replyTo!['text'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                  onPressed: () => setState(() => _replyTo = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: _replyTo != null
                        ? 'Ответить ${_replyTo!['fio']}...'
                        : 'Напишите комментарий...',
                    hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0071BC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
