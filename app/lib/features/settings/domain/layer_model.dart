class LayerModel {
  const LayerModel({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
  });

  final int id;
  final String name;
  final String type;
  final int? parentId;

  factory LayerModel.fromJson(Map<String, dynamic> json) {
    return LayerModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      parentId: (json['parentId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'parentId': parentId,
    };
  }
}
