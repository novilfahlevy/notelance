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
  final String id;
  final String? remoteId;

  const RemoteCategoryIdIsNotFoundResponse({
    this.state = 'CATEGORY_ID_IS_NOT_PROVIDED',
    this.message,
    required this.id,
    this.remoteId,
  });

  factory RemoteCategoryIdIsNotFoundResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIdIsNotFoundResponse(
      state: json['state'] ?? 'CATEGORY_ID_IS_NOT_PROVIDED',
      message: json['message'],
      id: json['id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'message': message,
      'id': id,
      'remote_id': remoteId,
    };
  }
}

class RemoteCategoryIdIsNotValidResponse {
  final String state;
  final String id;
  final String remoteId;

  const RemoteCategoryIdIsNotValidResponse({
    this.state = 'CATEGORY_ID_IS_NOT_VALID',
    required this.id,
    required this.remoteId,
  });

  factory RemoteCategoryIdIsNotValidResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIdIsNotValidResponse(
      state: json['state'] ?? 'CATEGORY_ID_IS_NOT_VALID',
      id: json['id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'id': id,
      'remote_id': remoteId,
    };
  }
}

class ErrorIsOccuredResponse {
  final String state;
  final String errorMessage;
  final String id;
  final String remoteId;

  const ErrorIsOccuredResponse({
    this.state = 'AN_ERROR_OCCURED_IN_THIS_CATEGORY',
    required this.errorMessage,
    required this.id,
    required this.remoteId,
  });

  factory ErrorIsOccuredResponse.fromJson(Map<String, dynamic> json) {
    return ErrorIsOccuredResponse(
      state: json['state'] ?? 'AN_ERROR_OCCURED_IN_THIS_CATEGORY',
      errorMessage: json['errorMessage'],
      id: json['id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'errorMessage': errorMessage,
      'id': id,
      'remote_id': remoteId,
    };
  }
}

class CategoryIsNotFoundInRemote {
  final String state;
  final String id;
  final String remoteId;
  final String name;
  final int orderIndex;

  const CategoryIsNotFoundInRemote({
    this.state = 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE',
    required this.id,
    required this.remoteId,
    required this.name,
    required this.orderIndex,
  });

  factory CategoryIsNotFoundInRemote.fromJson(Map<String, dynamic> json) {
    return CategoryIsNotFoundInRemote(
      state: json['state'] ?? 'CATEGORY_IS_NOT_FOUND_IN_THE_REMOTE',
      id: json['id'],
      remoteId: json['remote_id'],
      name: json['name'],
      orderIndex: json['order_index'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'id': id,
      'remote_id': remoteId,
      'name': name,
      'order_index': orderIndex,
    };
  }
}

class CategoriesHaveSameTimesResponse {
  final String state;
  final String id;
  final String remoteId;

  const CategoriesHaveSameTimesResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME',
    required this.id,
    required this.remoteId,
  });

  factory CategoriesHaveSameTimesResponse.fromJson(Map<String, dynamic> json) {
    return CategoriesHaveSameTimesResponse(
      state: json['state'] ?? 'CATEGORY_IN_THE_REMOTE_IS_THE_SAME',
      id: json['id'],
      remoteId: json['remote_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'id': id,
      'remote_id': remoteId,
    };
  }
}

class RemoteCategoryIsNewerResponse {
  final String state;
  final String? message;
  final int id;
  final int? remoteId;
  final String name;
  final int orderIndex;
  final int isDeleted;
  final String updatedAt;
  final String createdAt;

  const RemoteCategoryIsNewerResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_NEWER',
    this.message,
    required this.id,
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
      id: json['id'],
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
      'id': id,
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
  final String id;
  final String remoteId;
  final String? message;

  const RemoteCategoryIsDeprecatedResponse({
    this.state = 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED',
    required this.id,
    required this.remoteId,
    this.message,
  });

  factory RemoteCategoryIsDeprecatedResponse.fromJson(Map<String, dynamic> json) {
    return RemoteCategoryIsDeprecatedResponse(
      state: json['state'] ?? 'CATEGORY_IN_THE_REMOTE_IS_DEPRECATED',
      id: json['id'],
      remoteId: json['remote_id'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'id': id,
      'remote_id': remoteId,
      'message': message,
    };
  }
}