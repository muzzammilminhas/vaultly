import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/document.dart';
import '../providers/vault_providers.dart';
import '../widgets/document_tile.dart';
import '../widgets/search_bar.dart';
import '../widgets/tag_chip.dart';
import 'capture_screen.dart';
import 'document_detail_screen.dart';

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

  void _openDocument(Document document) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentDetailScreen(document: document)),
    );
  }

  List<Document> _applyTagFilter(List<Document> documents, String? tag) {
    if (tag == null) return documents;
    return documents.where((d) => d.tags.contains(tag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);
    final query = ref.watch(searchQueryProvider).trim();
    final selectedTag = ref.watch(selectedTagProvider);
    final allTags = ref.watch(allTagsProvider);

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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: VaultSearchBar(
                  onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
                ),
              ),
              if (allTags.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    itemCount: allTags.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = allTags[index];
                      return TagChip(
                        label: tag,
                        selected: selectedTag == tag,
                        onTap: () => ref.read(selectedTagProvider.notifier).state =
                            selectedTag == tag ? null : tag,
                      );
                    },
                  ),
                ),
              Expanded(
                child: query.isEmpty
                    ? _DocumentGrid(
                        documents: _applyTagFilter(documents, selectedTag),
                        onTap: _openDocument,
                        emptyMessage: 'No documents tagged "$selectedTag"',
                      )
                    : Consumer(
                        builder: (context, ref, _) {
                          final searchAsync = ref.watch(searchResultsProvider);
                          return searchAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(child: Text('Search failed: $error')),
                            data: (results) {
                              final matches = _applyTagFilter(results ?? const <Document>[], selectedTag);
                              if (matches.isEmpty) {
                                return Center(child: Text('No documents match "$query"'));
                              }
                              return _DocumentGrid(
                                documents: matches,
                                onTap: _openDocument,
                                emptyMessage: 'No documents match "$query"',
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
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

class _DocumentGrid extends StatelessWidget {
  const _DocumentGrid({required this.documents, required this.onTap, this.emptyMessage});

  final List<Document> documents;
  final ValueChanged<Document> onTap;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Center(child: Text(emptyMessage ?? 'No documents'));
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
        return DocumentTile(document: document, onTap: () => onTap(document));
      },
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
