import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/document.dart';
import '../providers/vault_providers.dart';
import '../widgets/tag_chip.dart';

/// Full-size view of a document: decrypted only into memory, with tag
/// editing, an explicit one-time export/share action, and delete.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.document});

  final Document document;

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  late Document _document;
  Uint8List? _decryptedBytes;
  String? _error;
  String _extractedText = '';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _load();
  }

  Future<void> _load() async {
    try {
      final encryption = ref.read(encryptionServiceProvider);
      final raw = await File(_document.encryptedFilePath).readAsBytes();
      final bytes = await encryption.decryptBytes(raw);
      final text = await DatabaseHelper.instance.getExtractedText(_document.id);
      if (!mounted) return;
      setState(() {
        _decryptedBytes = bytes;
        _extractedText = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not decrypt this document: $e');
    }
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (tag == null || tag.isEmpty || _document.tags.contains(tag)) return;
    await _persistTags(_document.copyWith(tags: [..._document.tags, tag]));
  }

  Future<void> _removeTag(String tag) async {
    await _persistTags(_document.copyWith(tags: _document.tags.where((t) => t != tag).toList()));
  }

  Future<void> _persistTags(Document updated) async {
    setState(() => _document = updated);
    await DatabaseHelper.instance.updateDocumentMeta(updated);
    ref.invalidate(documentsProvider);
  }

  /// Writes the decrypted image to a temp file only for the duration of the
  /// OS share sheet, then deletes it — an explicit, one-time export, not a
  /// decrypted copy left sitting on disk.
  Future<void> _share() async {
    final bytes = _decryptedBytes;
    if (bytes == null || _sharing) return;
    setState(() => _sharing = true);
    // The OS share sheet pauses/resumes the app; that isn't the user
    // backgrounding it, so suppress the lock screen for it.
    ref.read(lockSuppressionProvider.notifier).state++;
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = _document.title.replaceAll(RegExp(r'[^\w\- ]+'), '_');
      tempFile = File(p.join(tempDir.path, '$safeName.jpg'));
      await tempFile.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(tempFile.path)], text: _document.title));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      ref.read(lockSuppressionProvider.notifier).state--;
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This permanently deletes the encrypted file. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(documentsProvider.notifier).remove(_document);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Export / share a decrypted copy',
            onPressed: _decryptedBytes == null ? null : _share,
          ),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)),
            )
          : _decryptedBytes == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: Image.memory(_decryptedBytes!, width: double.infinity),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      DateFormat.yMMMMd().add_jm().format(_document.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in _document.tags) TagChip(label: tag, onDeleted: () => _removeTag(tag)),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Add tag'),
                          onPressed: _addTag,
                        ),
                      ],
                    ),
                    if (_extractedText.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Extracted text', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(_extractedText, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
    );
  }
}
