import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/document.dart';

/// sqflite setup for the vault: a `documents` table for metadata plus an
/// FTS5 virtual table indexing each document's extracted text, kept in sync
/// on every insert/delete so full-text search always reflects current state.
///
/// Uses sqflite_common_ffi (backed by the bundled `sqlite3` package) rather
/// than the native sqflite plugin, because Android's own system SQLite build
/// doesn't reliably ship with the FTS5 module — the OS-provided library
/// varies by device/OEM and can't be counted on for a feature this central.
class DatabaseHelper {
  DatabaseHelper._() {
    sqfliteFfiInit();
  }
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await _open();
    _db = db;
    return db;
  }

  Future<Database> _open() async {
    final appDir = await getApplicationDocumentsDirectory();
    final path = p.join(appDir.path, 'vaultly.db');
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        encrypted_file_path TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE VIRTUAL TABLE documents_fts USING fts5(
        id UNINDEXED,
        body
      )
    ''');
  }

  Future<void> insertDocument(Document document, String extractedText) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('documents', document.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('documents_fts', where: 'id = ?', whereArgs: [document.id]);
      await txn.insert('documents_fts', {'id': document.id, 'body': extractedText});
    });
  }

  Future<void> updateDocumentMeta(Document document) async {
    final db = await database;
    await db.update('documents', document.toRow(), where: 'id = ?', whereArgs: [document.id]);
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'created_at DESC');
    return rows.map(Document.fromRow).toList();
  }

  Future<String> getExtractedText(String id) async {
    final db = await database;
    final rows = await db.query('documents_fts', columns: ['body'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return '';
    return rows.first['body'] as String? ?? '';
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
      await txn.delete('documents_fts', where: 'id = ?', whereArgs: [id]);
    });
  }
}
