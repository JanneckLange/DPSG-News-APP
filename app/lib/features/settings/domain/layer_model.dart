class LayerModel {
  const LayerModel({
    required this.id,
    required this.name,
    required this.parentId,
    this.hasAuthors = true,
    this.authorCount,
  });

  final int id;
  final String name;
  final int? parentId;

  /// Ob dem Layer mindestens ein Autor explizit zugeordnet ist (#42).
  /// Faellt auf `true` zurueck, wenn ein aelterer, lokal gecachter
  /// Layer-Baum das Feld noch nicht enthaelt -- so wird ein Layer vor dem
  /// ersten Remote-Refresh nicht faelschlich als autorenlos behandelt.
  final bool hasAuthors;

  /// Anzahl der Autoren (ohne Admins), die diesem Layer direkt zugeordnet
  /// sind. Nur im Admin-Layer-Baum (`/api/admin/layers`) befuellt -- bei der
  /// DV-Auswahl (`/api/layers`) bleibt das Feld `null`.
  final int? authorCount;

  factory LayerModel.fromJson(Map<String, dynamic> json) {
    return LayerModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      parentId: (json['parentId'] as num?)?.toInt(),
      hasAuthors: json['hasAuthors'] as bool? ?? true,
      authorCount: (json['authorCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'hasAuthors': hasAuthors,
      'authorCount': authorCount,
    };
  }
}
