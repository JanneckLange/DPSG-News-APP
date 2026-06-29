class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.dv,
  });

  final String id;
  final String title;
  final String description;
  final String startDate;
  final String endDate;
  final String location;
  final String dv;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      location: json['location'] as String,
      dv: json['dv'] as String,
    );
  }
}
