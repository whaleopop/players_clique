import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/music_service.dart';
import '../../services/ynison_service.dart';

class ArtistPage extends StatefulWidget {
  final String uid;
  const ArtistPage({super.key, required this.uid});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  bool get _isOwn => FirebaseAuth.instance.currentUser?.uid == widget.uid;
  bool _uploading = false;

  late final Stream<DocumentSnapshot> _artistStream = FirebaseFirestore.instance
      .collection('artists').doc(widget.uid).snapshots();
  late final Stream<QuerySnapshot> _tracksStream = FirebaseFirestore.instance
      .collection('artists').doc(widget.uid).collection('tracks')
      .orderBy('timestamp', descending: true).snapshots();

  Future<void> _editProfile(Map<String, dynamic> current) async {
    final nameCtrl = TextEditingController(text: current['name'] as String? ?? '');
    final bioCtrl = TextEditingController(text: current['bio'] as String? ?? '');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Профиль артиста'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Сценическое имя',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'О себе',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('artists').doc(widget.uid).set({
                'name': nameCtrl.text.trim(),
                'bio': bioCtrl.text.trim(),
                'uid': widget.uid,
              }, SetOptions(merge: true));
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadTrack() async {
    PlatformFile? file;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      file = result.files.first;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось открыть файл: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('artist_tracks/${widget.uid}/${ts}_${file.name}');
      final task = (!kIsWeb && file.path != null)
          ? ref.putFile(File(file.path!))
          : ref.putData(file.bytes!);
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      await FirebaseFirestore.instance
          .collection('artists').doc(widget.uid).collection('tracks')
          .add({'title': title, 'audioUrl': url, 'timestamp': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек загружен')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteTrack(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance
        .collection('artists').doc(widget.uid).collection('tracks')
        .doc(doc.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль артиста'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          if (_isOwn)
            StreamBuilder<DocumentSnapshot>(
              stream: _artistStream,
              builder: (context, snap) {
                final d = snap.data?.data() as Map<String, dynamic>? ?? {};
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editProfile(d),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Шапка артиста ────────────────────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: _artistStream,
            builder: (context, snap) {
              final d = snap.data?.data() as Map<String, dynamic>? ?? {};
              final name = d['name'] as String? ?? 'Артист';
              final bio = d['bio'] as String? ?? '';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFB39DDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: Icon(Icons.mic_rounded, color: Colors.white, size: 30)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, size: 11, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text('Артист', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(bio, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    ],
                  ],
                ),
              );
            },
          ),
          // ── Заголовок треков ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.library_music_rounded, size: 16, color: Color(0xFF6C63FF)),
                const SizedBox(width: 6),
                const Text('Треки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (_isOwn)
                  _uploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)))
                      : GestureDetector(
                          onTap: _uploadTrack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 14, color: Color(0xFF6C63FF)),
                                SizedBox(width: 4),
                                Text('Добавить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
                              ],
                            ),
                          ),
                        ),
              ],
            ),
          ),
          // ── Список треков ─────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tracksStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text('Нет треков', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final title = d['title'] as String? ?? 'Трек';
                    final audioUrl = d['audioUrl'] as String? ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Color(0xFF6C63FF), size: 22),
                      ),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      onTap: audioUrl.isNotEmpty
                          ? () {
                              final music = context.read<MusicService>();
                              music.setCurrentTrack(
                                TrackInfo(id: docs[i].id, title: title, artist: 'Артист'),
                                isPlaying: true,
                              );
                              // Play via audioplayers would require MusicService to own the player.
                              // For now, just update the now-playing state.
                            }
                          : null,
                      trailing: _isOwn
                          ? IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                              onPressed: () => _deleteTrack(docs[i]),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
