class TopicModel {
  const TopicModel({
    required this.id,
    required this.name,
    required this.layerId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int layerId;
  final String createdAt;
  final String updatedAt;

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      layerId: (json['layerId'] as num).toInt(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
