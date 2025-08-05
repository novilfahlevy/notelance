class Category {
  final int id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true; // Same instance
    return other is Category && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name}';
  }
}