class Category {
  final int? id;
  final String name;
  final int order;
  int? remoteId; // Changed to int?

  Category({
    this.id,
    required this.name,
    this.order = 0,
    this.remoteId, // Changed to int?
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.order == order &&
        other.remoteId == remoteId; // remoteId check
  }

  @override
  int get hashCode => Object.hash(id, name, order, remoteId); // Added remoteId to hash

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      order: json['order'] as int? ?? 0,
      remoteId: json['remote_id'] as int?, // Changed to int?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'remote_id': remoteId, // remoteId
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? order,
    int? remoteId, // Changed to int?
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      remoteId: remoteId ?? this.remoteId, // remoteId
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, order: $order, remoteId: $remoteId}'; // Added remoteId
  }
}
