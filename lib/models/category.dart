class Category {
  final int? id;
  final String name;
  final int order;

  Category({
    this.id,
    required this.name,
    this.order = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id && other.name == name && other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, name, order);

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int?,
      name: json['name'] as String,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? order,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, order: $order}';
  }
}