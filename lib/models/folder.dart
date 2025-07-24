class Folder {
  int id;
  String name;

  Folder({
    required this.id,
    required this.name,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json["id"],
    name: json["name"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
  };

  // Override toString for better debugging
  @override
  String toString() {
    return 'Folder{id: $id, name: $name}';
  }

  // Override equality operators for better comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Folder &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  // Helper method to create a copy with updated values
  Folder copyWith({
    int? id,
    String? name,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}