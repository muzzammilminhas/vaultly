import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/document.dart';
import '../providers/vault_providers.dart';
import '../widgets/document_tile.dart';
import 'capture_screen.dart';

class HomeVaultScreen extends ConsumerStatefulWidget {
  const HomeVaultScreen({super.key});

  @override
  ConsumerState<HomeVaultScreen> createState() => _HomeVaultScreenState();
}

class _HomeVaultScreenState extends ConsumerState<HomeVaultScreen> {
  bool _saving = false;

  Future<void> _startCapture() async {
    final result = await Navigator.of(context).push<CaptureResult>(
      MaterialPageRoute(builder: (_) => const CaptureScreen(), fullscreenDialog: true),
    );
    if (result == null || !mounted) return;
    await _saveCapture(result);
  }

  Future<void> _saveCapture(CaptureResult result) async {
    setState(() => _saving = true);
    try {
      final encryption = ref.read(encryptionServiceProvider);
      final encryptedBytes = await encryption.encryptBytes(result.imageBytes);

      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, 'documents'));
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      final id = const Uuid().v4();
      final file = File(p.join(docsDir.path, '$id.enc'));
      await file.writeAsBytes(encryptedBytes);

      final now = DateTime.now();
      final document = Document(
        id: id,
        title: _titleFor(result.extractedText, now),
        tags: const [],
        createdAt: now,
        encryptedFilePath: file.path,
      );
      await ref.read(documentsProvider.notifier).add(document, result.extractedText);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleFor(String extractedText, DateTime fallback) {
    final firstLine = extractedText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) {
      return 'Document — ${DateFormat.yMMMd().add_jm().format(fallback)}';
    }
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
  }

  Future<void> _openDocument(Document document) async {
    final encryption = ref.read(encryptionServiceProvider);
    Uint8List bytes;
    try {
      final raw = await File(document.encryptedFilePath).readAsBytes();
      bytes = await encryption.decryptBytes(raw);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open document: $e')),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vaultly')),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your vault: $error'),
          ),
        ),
        data: (documents) {
          if (documents.isEmpty) {
            return _EmptyState(saving: _saving);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return DocumentTile(document: document, onTap: () => _openDocument(document));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _startCapture,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(_saving ? 'Saving…' : 'Scan document'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.saving});

  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              saving ? 'Saving your document…' : 'Your vault is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan or import a document to get started. Everything stays encrypted on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
