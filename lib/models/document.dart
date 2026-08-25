class Document {
  const Document({
    required this.id,
    required this.title,
    required this.tags,
    required this.createdAt,
    required this.encryptedFilePath,
  });

  final String id;
  final String title;
  final List<String> tags;
  final DateTime createdAt;
  final String encryptedFilePath;

  factory Document.fromRow(Map<String, Object?> row) => Document(
        id: row['id'] as String,
        title: row['title'] as String,
        tags: (row['tags'] as String).split(',').where((t) => t.isNotEmpty).toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        encryptedFilePath: row['encrypted_file_path'] as String,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'tags': tags.join(','),
        'created_at': createdAt.millisecondsSinceEpoch,
        'encrypted_file_path': encryptedFilePath,
      };

  Document copyWith({String? title, List<String>? tags}) => Document(
        id: id,
        title: title ?? this.title,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        encryptedFilePath: encryptedFilePath,
      );
}
