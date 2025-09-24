class SaveNoteSuccessResponse {
  final String message = "NOTE_IS_SUCCESSFULLY_SYNCED";
  final int remoteId;
  final String title;
  final String content;
  final int categoryId;
  final String createdAt;
  final String updatedAt;

  SaveNoteSuccessResponse({
    required this.remoteId,
    required this.title,
    required this.content,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SaveNoteSuccessResponse.fromJson(Map<String, dynamic> json) {
    return SaveNoteSuccessResponse(
      remoteId: json['remote_id'],
      title: json['title'],
      content: json['content'],
      categoryId: json['category_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'remote_id': remoteId,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SaveNoteFailedResponse {
  final String message = "NOTE_CREATION_IS_FAILED";
  final dynamic error;

  SaveNoteFailedResponse({
    required this.error,
  });

  factory SaveNoteFailedResponse.fromJson(Map<String, dynamic> json) {
    return SaveNoteFailedResponse(
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'error': error,
    };
  }
}