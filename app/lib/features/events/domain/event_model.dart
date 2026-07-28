class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    required this.layerId,
  });

  final String id;
  final String title;
  final String description;
  final String startDate;
  final String endDate;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final int layerId;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      locationAddress: json['locationAddress'] as String?,
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      layerId: (json['layerId'] as num).toInt(),
    );
  }
}
