class Category {
  final int? id;
  final String name;
  final int orderIndex;
  int? remoteId; // Changed to int?

  Category({
    this.id,
    required this.name,
    this.orderIndex = 0,
    this.remoteId, // Changed to int?
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.orderIndex == orderIndex &&
        other.remoteId == remoteId; // remoteId check
  }

  @override
  int get hashCode => Object.hash(id, name, orderIndex, remoteId); // Added remoteId to hash

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      remoteId: json['remote_id'] as int?, // Changed to int?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order_index': orderIndex,
      'remote_id': remoteId, // remoteId
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? orderIndex,
    int? remoteId, // Changed to int?
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      remoteId: remoteId ?? this.remoteId, // remoteId
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, orderIndex: $orderIndex, remoteId: $remoteId}'; // Added remoteId
  }
}
