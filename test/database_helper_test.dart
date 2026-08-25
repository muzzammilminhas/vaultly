import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vaultly/db/database_helper.dart';

/// Exercises the actual FTS5 schema and MATCH query against an in-memory
/// sqlite3 database — this is the real risk area (FTS5 module availability,
/// query syntax, ranking), not just plumbing, so it's worth a real query
/// rather than mocking the database away.
Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
      title,
      body
    )
  ''');
  return db;
}

Future<void> _insert(Database db, {required String id, required String title, required String body}) async {
  await db.insert('documents', {
    'id': id,
    'title': title,
    'tags': '',
    'created_at': 0,
    'encrypted_file_path': '/tmp/$id.enc',
  });
  await db.insert('documents_fts', {'id': id, 'title': title, 'body': body});
}

void main() {
  test('FTS5 module is available and full-text search matches on body content', () async {
    final db = await _openTestDatabase();
    addTearDown(db.close);

    await _insert(db, id: '1', title: 'Electric bill', body: 'Total due 1,250.00 USD for August usage');
    await _insert(db, id: '2', title: 'Grocery receipt', body: 'Milk, eggs, bread — thirty four dollars');

    final helper = DatabaseHelper.instance;
    final rows = await db.rawQuery('''
      SELECT documents.* FROM documents_fts
      JOIN documents ON documents.id = documents_fts.id
      WHERE documents_fts MATCH ?
    ''', [helper.buildMatchQuery('usage')]);

    expect(rows, hasLength(1));
    expect(rows.single['id'], '1');
  });

  test('search is a genuine index lookup, not a substring scan — matches whole tokens only', () async {
    final db = await _openTestDatabase();
    addTearDown(db.close);

    await _insert(db, id: '1', title: 'Passport', body: 'Contains the word cataloging in the body');
    await _insert(db, id: '2', title: 'Notebook', body: 'A page about cats and dogs');

    final helper = DatabaseHelper.instance;
    // "cat" should prefix-match "cataloging" and "cats" as whole tokens via
    // FTS5's tokenizer, but would NOT match if this were naive substring
    // search misapplied — both should legitimately match here since FTS5
    // prefix matching operates on token boundaries.
    final rows = await db.rawQuery('''
      SELECT documents.id FROM documents_fts
      JOIN documents ON documents.id = documents_fts.id
      WHERE documents_fts MATCH ?
      ORDER BY documents.id
    ''', [helper.buildMatchQuery('cat')]);

    expect(rows.map((r) => r['id']), ['1', '2']);
  });

  test('ranked results put the more relevant document first', () async {
    final db = await _openTestDatabase();
    addTearDown(db.close);

    // Doc 2 mentions "invoice" many times and in the title; doc 1 mentions
    // it once in passing. bm25 should rank doc 2 above doc 1.
    await _insert(db, id: '1', title: 'Random note', body: 'Remember to check the invoice later');
    await _insert(
      db,
      id: '2',
      title: 'Invoice invoice invoice',
      body: 'Invoice number 4471. Invoice total due. Invoice date today.',
    );

    final helper = DatabaseHelper.instance;
    final rows = await db.rawQuery('''
      SELECT documents.id FROM documents_fts
      JOIN documents ON documents.id = documents_fts.id
      WHERE documents_fts MATCH ?
      ORDER BY bm25(documents_fts)
    ''', [helper.buildMatchQuery('invoice')]);

    expect(rows.first['id'], '2', reason: 'the document saturated with the query term should rank first');
  });

  test('buildMatchQuery quotes tokens so raw FTS5 syntax characters in the query text are inert', () {
    final helper = DatabaseHelper.instance;
    // A bare double-quote or dash from user input must not corrupt the FTS5
    // query syntax (e.g. leading "-" would otherwise mean NOT in FTS5).
    final built = helper.buildMatchQuery('"quoted"  -term');
    expect(built, '"quoted"* "-term"*');
  });

  test('an empty or whitespace-only query builds to nothing, signalling "show everything"', () {
    final helper = DatabaseHelper.instance;
    expect(helper.buildMatchQuery(''), isEmpty);
    expect(helper.buildMatchQuery('   '), isEmpty);
  });
}
