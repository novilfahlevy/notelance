class Note {
  final int? id;
  final String title;
  final String? content;
  final int? categoryId;
  final String? createdAt;
  final String? updatedAt;

  Note({
    this.id,
    required this.title,
    this.content,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int?,
      title: json['title'] as String,
      content: json['content'] as String?,
      categoryId: json['category_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Note{id: $id, title: $title, content: $content, categoryId: $categoryId, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}