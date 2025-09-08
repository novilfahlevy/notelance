class Note {
  int? id;
  final String title;
  final String? content;
  final int? categoryId;
  String? createdAt;
  String? updatedAt;
  int? remoteId; // Changed to int?

  Note({
    this.id,
    required this.title,
    this.content,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.remoteId, // Changed to int?
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int?,
      title: json['title'] as String,
      content: json['content'] as String?,
      categoryId: json['category_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      remoteId: json['remote_id'] as int?, // Changed to int?
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
      'remote_id': remoteId, // remoteId
    };
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? categoryId,
    String? createdAt,
    String? updatedAt,
    int? remoteId, // Changed to int?
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId ?? this.remoteId, // remoteId
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, title: $title, content: $content, categoryId: $categoryId, createdAt: $createdAt, updatedAt: $updatedAt, remoteId: $remoteId}'; // Added remoteId
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.categoryId == categoryId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.remoteId == remoteId; // remoteId check
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    categoryId,
    createdAt,
    updatedAt,
    remoteId, // Added remoteId to hash
  );
}
