class CategoriesSyncResponse {
  final String state;
  final List<dynamic> categories;
  final String? errorMessage;

  CategoriesSyncResponse({
    required this.state,
    required this.categories,
    this.errorMessage
  });

  factory CategoriesSyncResponse.fromJson(Map<String, dynamic> json) {
    return CategoriesSyncResponse(
      state: json['state'] as String,
      categories: json['categories'] as List<dynamic>,
      errorMessage: json['errorMessage'] as String?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'categories': categories,
      'errorMessage': errorMessage
    };
  }
}

class RemoteCategoryIdIsNotFoundResponse {
  final String state;
  final String? message;
  final int clientId;
  final int? remoteId;

  const RemoteCategoryIdIsNotFoundResponse({
    this.state = 'CATEGORY_ID_IS_NOT_PROVIDED',
    this.message,
    required this.clientId,
    this.remoteId,
  });

  factory RemoteCategoryIdIsNotFoundResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIdIsNotFoundResponse(
      state: json['state'] ?? 'CATEGORY_ID_IS_NOT_PROVIDED',
      message: json['message'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class RemoteCategoryIdIsNotValidResponse {
  final String state;
  final int clientId;
  final int remoteId;

  const RemoteCategoryIdIsNotValidResponse({
    this.state = 'CATEGORY_ID_IS_NOT_VALID',
    required this.clientId,
    required this.remoteId,
  });

  factory RemoteCategoryIdIsNotValidResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIdIsNotValidResponse(
      state: json['state'] ?? 'CATEGORY_ID_IS_NOT_VALID',
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class ErrorIsOccurredCategoryResponse {
  final String state;
  final String errorMessage;
  final int clientId;
  final int remoteId;

  const ErrorIsOccurredCategoryResponse({
    this.state = 'AN_ERROR_OCCURED_IN_THIS_CATEGORY',
    required this.errorMessage,
    required this.clientId,
    required this.remoteId,
  });

  factory ErrorIsOccurredCategoryResponse.fromJson(Map<String, dynamic> json) {
    return ErrorIsOccurredCategoryResponse(
      state: json['state'] ?? 'AN_ERROR_OCCURRED_IN_THIS_CATEGORY',
      errorMessage: json['errorMessage'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'errorMessage': errorMessage,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class CategoryIsNotFoundInRemote {
  final String state;
  final int clientId;
  final int remoteId;
  final String name;
  final int orderIndex;

  const CategoryIsNotFoundInRemote({
    this.state = 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE',
    required this.clientId,
    required this.remoteId,
    required this.name,
    required this.orderIndex,
  });

  factory CategoryIsNotFoundInRemote.fromJson(Map<String, dynamic> json) {
    return CategoryIsNotFoundInRemote(
      state: json['state'] ?? 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE',
      clientId: json['client_id'],
      remoteId: json['remote_id'],
      name: json['name'],
      orderIndex: json['order_index'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
      'name': name,
      'order_index': orderIndex,
    };
  }
}

class CategoriesHaveSameTimesResponse {
  final String state;
  final int clientId;
  final int remoteId;

  const CategoriesHaveSameTimesResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME',
    required this.clientId,
    required this.remoteId,
  });

  factory CategoriesHaveSameTimesResponse.fromJson(Map<String, dynamic> json) {
    return CategoriesHaveSameTimesResponse(
      state: json['state'] ?? 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME',
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class RemoteCategoryIsNewerResponse {
  final String state;
  final String? message;
  final int clientId;
  final int? remoteId;
  final String name;
  final int orderIndex;
  final int isDeleted;
  final String updatedAt;
  final String createdAt;

  const RemoteCategoryIsNewerResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_NEWER',
    this.message,
    required this.clientId,
    this.remoteId,
    required this.name,
    required this.orderIndex,
    required this.isDeleted,
    required this.updatedAt,
    required this.createdAt,
  });

  factory RemoteCategoryIsNewerResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIsNewerResponse(
      state: json['state'] ?? 'CATEGORY_IN_THE_REMOTE_IS_NEWER',
      message: json['message'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
      name: json['name'],
      orderIndex: json['order_index'],
      isDeleted: json['is_deleted'],
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'client_id': clientId,
      'remote_id': remoteId,
      'name': name,
      'order_index': orderIndex,
      'is_deleted': isDeleted,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }
}

class RemoteCategoryIsDeprecatedResponse {
  final String state;
  final int clientId;
  final int remoteId;
  final String? message;

  const RemoteCategoryIsDeprecatedResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED',
    required this.clientId,
    required this.remoteId,
    this.message,
  });

  factory RemoteCategoryIsDeprecatedResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIsDeprecatedResponse(
      state: json['state'] ?? 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED',
      clientId: json['client_id'],
      remoteId: json['remote_id'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
      'message': message,
    };
  }
}

class CategoriesResponseSucceed {
  final String state = "CATEGORIES_HAVE_SYNCED";
  final List<dynamic> categories;

  CategoriesResponseSucceed({
    required this.categories,
  });

  factory CategoriesResponseSucceed.fromJson(Map<String, dynamic> json) {
    return CategoriesResponseSucceed(categories: (json['categories'] as List));
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }
}

class CategoriesResponseFailed {
  final String state = "CATEGORIES_SYNC_IS_FAILED";
  final String errorMessage;

  CategoriesResponseFailed({
    required this.errorMessage,
  });

  factory CategoriesResponseFailed.fromJson(Map<String, dynamic> json) {
    return CategoriesResponseFailed(
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'errorMessage': errorMessage,
    };
  }
}

class RemoteNoteIdIsNotProvidedResponse {
  final String state = "NOTE_ID_IS_NOT_PROVIDED";
  final String? message;
  final int clientId;
  final int? remoteId;

  RemoteNoteIdIsNotProvidedResponse({
    this.message,
    required this.clientId,
    this.remoteId,
  });

  factory RemoteNoteIdIsNotProvidedResponse.fromJson(Map<String, dynamic> json) {
    return RemoteNoteIdIsNotProvidedResponse(
      message: json['message'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class RemoteNoteIdIsNotValidResponse {
  final String state = "NOTE_ID_IS_NOT_VALID";
  final int clientId;
  final int remoteId;

  RemoteNoteIdIsNotValidResponse({
    required this.clientId,
    required this.remoteId,
  });

  factory RemoteNoteIdIsNotValidResponse.fromJson(Map<String, dynamic> json) {
    return RemoteNoteIdIsNotValidResponse(
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class ErrorIsOccurredNoteResponse {
  final String state = "AN_ERROR_OCCURRED_IN_THIS_NOTE";
  final String errorMessage;
  final int clientId;
  final int remoteId;

  ErrorIsOccurredNoteResponse({
    required this.errorMessage,
    required this.clientId,
    required this.remoteId,
  });

  factory ErrorIsOccurredNoteResponse.fromJson(Map<String, dynamic> json) {
    return ErrorIsOccurredNoteResponse(
      errorMessage: json['errorMessage'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'errorMessage': errorMessage,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class NoteIsNotFoundInRemoteResponse {
  final String state = "NOTE_IS_NOT_FOUND_IN_THE_REMOTE";
  final int clientId;
  final int remoteId;
  final String title;

  NoteIsNotFoundInRemoteResponse({
    required this.clientId,
    required this.remoteId,
    required this.title,
  });

  factory NoteIsNotFoundInRemoteResponse.fromJson(Map<String, dynamic> json) {
    return NoteIsNotFoundInRemoteResponse(
      clientId: json['client_id'],
      remoteId: json['remote_id'],
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
      'title': title,
    };
  }
}

class NotesHaveSameTimesResponse {
  final String state = "NOTE_IN_THE_REMOTE_IS_THE_SAME";
  final int clientId;
  final int remoteId;

  NotesHaveSameTimesResponse({
    required this.clientId,
    required this.remoteId,
  });

  factory NotesHaveSameTimesResponse.fromJson(Map<String, dynamic> json) {
    return NotesHaveSameTimesResponse(
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class RemoteNoteIsNewerResponse {
  final String state = "NOTE_IN_THE_REMOTE_IS_NEWER";
  final String? message;
  final int clientId;
  final int remoteId;
  final String title;
  final String content;
  final int? categoryId;
  final int isDeleted;
  final String updatedAt;
  final String createdAt;

  RemoteNoteIsNewerResponse({
    this.message,
    required this.clientId,
    required this.remoteId,
    required this.title,
    required this.content,
    this.categoryId,
    required this.isDeleted,
    required this.updatedAt,
    required this.createdAt,
  });

  factory RemoteNoteIsNewerResponse.fromJson(Map<String, dynamic> json) {
    return RemoteNoteIsNewerResponse(
      message: json['message'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
      title: json['title'],
      content: json['content'],
      categoryId: json['category_id'],
      isDeleted: json['is_deleted'],
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'client_id': clientId,
      'remote_id': remoteId,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'is_deleted': isDeleted,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }
}

class RemoteNoteIsDeprecatedResponse {
  final String state = "NOTE_IN_THE_REMOTE_IS_DEPRECATED";
  final String? message;
  final int clientId;
  final int remoteId;

  RemoteNoteIsDeprecatedResponse({
    this.message,
    required this.clientId,
    required this.remoteId,
  });

  factory RemoteNoteIsDeprecatedResponse.fromJson(Map<String, dynamic> json) {
    return RemoteNoteIsDeprecatedResponse(
      message: json['message'],
      clientId: json['client_id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'client_id': clientId,
      'remote_id': remoteId,
    };
  }
}

class NotesResponseSucceed {
  final String state = "NOTES_HAVE_SYNCED";
  final List<dynamic> notes;

  NotesResponseSucceed({
    required this.notes,
  });

  factory NotesResponseSucceed.fromJson(Map<String, dynamic> json) {
    return NotesResponseSucceed(notes: (json['notes'] as List));
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }
}

class NotesResponseFailed {
  final String state = "NOTES_SYNC_IS_FAILED";
  final String errorMessage;

  NotesResponseFailed({
    required this.errorMessage,
  });

  factory NotesResponseFailed.fromJson(Map<String, dynamic> json) {
    return NotesResponseFailed(
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'errorMessage': errorMessage,
    };
  }
}

class FetchNoteResponse {
  final int remoteId;
  final String title;
  final String content;
  final int isDeleted;
  final String createdAt;
  final String updatedAt;
  final int? remoteCategoryId;
  final String? remoteCategoryName;
  final int? remoteCategoryOrderIndex;

  FetchNoteResponse({
    required this.remoteId,
    required this.title,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.remoteCategoryId,
    this.remoteCategoryName,
    this.remoteCategoryOrderIndex,
  });

  factory FetchNoteResponse.fromJson(Map<String, dynamic> json) {
    return FetchNoteResponse(
      remoteId: json['remote_id'],
      title: json['title'],
      content: json['content'],
      isDeleted: json['is_deleted'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      remoteCategoryId: json['remote_category_id'],
      remoteCategoryName: json['remote_category_name'],
      remoteCategoryOrderIndex: json['remote_category_order_index'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remote_id': remoteId,
      'title': title,
      'content': content,
      'is_deleted': isDeleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'remote_category_id': remoteCategoryId,
      'remote_category_name': remoteCategoryName,
      'remote_category_order_index': remoteCategoryOrderIndex,
    };
  }
}