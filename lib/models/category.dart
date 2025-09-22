class Category {
  final int? id;
  final String name;
  final int orderIndex;
  int? remoteId; // Changed to int?
  final int isDeleted;
  final String? createdAt;
  final String? updatedAt;

  Category({
    this.id,
    required this.name,
    this.orderIndex = 0,
    this.remoteId,
    this.isDeleted = 0, // Default to 0 (false)
    this.createdAt,
    this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.orderIndex == orderIndex &&
        other.remoteId == remoteId &&
        other.isDeleted == isDeleted &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, name, orderIndex, remoteId, isDeleted, createdAt, updatedAt);

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      remoteId: json['remote_id'] as int?,
      isDeleted: json['is_deleted'] as int? ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order_index': orderIndex,
      'remote_id': remoteId,
      'is_deleted': isDeleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? orderIndex,
    int? remoteId,
    int? isDeleted,
    String? createdAt,
    String? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      remoteId: remoteId ?? this.remoteId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, orderIndex: $orderIndex, remoteId: $remoteId, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
