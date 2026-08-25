import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_helper.dart';
import '../models/document.dart';
import '../services/encryption_service.dart';
import '../services/ocr_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) => EncryptionService());

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
