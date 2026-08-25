import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/document.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import '../services/ocr_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) => EncryptionService());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Reference count of "a system UI the app itself opened — camera
/// permission dialog, photo picker, share sheet — is temporarily covering
/// the app" is active. While > 0, the app lock must not re-trigger from the
/// pause/resume lifecycle events that dialog causes, or every capture or
/// share would force the user to re-enter their PIN mid-flow.
final lockSuppressionProvider = StateProvider<int>((ref) => 0);

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

final documentsProvider = AsyncNotifierProvider<DocumentsNotifier, List<Document>>(
  DocumentsNotifier.new,
);

class DocumentsNotifier extends AsyncNotifier<List<Document>> {
  @override
  Future<List<Document>> build() => DatabaseHelper.instance.getAllDocuments();

  Future<void> add(Document document, String extractedText) async {
    await DatabaseHelper.instance.insertDocument(document, extractedText);
    state = AsyncData(await DatabaseHelper.instance.getAllDocuments());
  }

  Future<void> remove(Document document) async {
    await DatabaseHelper.instance.deleteDocument(document.id);
    final file = File(document.encryptedFilePath);
    if (await file.exists()) await file.delete();
    state = AsyncData(await DatabaseHelper.instance.getAllDocuments());
  }
}

/// The raw (undebounced) search box text. The search bar widget debounces
/// keystrokes before writing here, so every write is a query worth running.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Null means "no active search — show the full vault"; an empty list means
/// "searched, found nothing".
final searchResultsProvider = FutureProvider.autoDispose<List<Document>?>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return null;
  return DatabaseHelper.instance.searchDocuments(query);
});

/// The tag currently filtering the vault grid, or null for no filter.
final selectedTagProvider = StateProvider<String?>((ref) => null);

/// Every distinct tag across the vault, sorted, for the filter chip row.
final allTagsProvider = Provider<List<String>>((ref) {
  final documents = ref.watch(documentsProvider).value ?? const <Document>[];
  final tags = <String>{};
  for (final document in documents) {
    tags.addAll(document.tags);
  }
  final sorted = tags.toList()..sort();
  return sorted;
});
