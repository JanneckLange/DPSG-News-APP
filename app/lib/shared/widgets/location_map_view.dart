import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Zeigt einen Event-Ort als OpenStreetMap-Karte mit Marker.
///
/// [interactive] steuert, ob Pan/Zoom-Gesten aktiv sind: false in der
/// Vorschau (vermeidet Gesten-Konflikte mit der umgebenden scrollbaren
/// Liste), true auf der Event-Detailseite.
class LocationMapView extends StatelessWidget {
  const LocationMapView({
    required this.lat,
    required this.lng,
    this.address,
    this.height = 160,
    this.interactive = true,
    super.key,
  });

  final double lat;
  final double lng;
  final String? address;
  final double height;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final point = LatLng(lat, lng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                minZoom: 5,
                maxZoom: 18,
                interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dpsg_news_app',
                  tileProvider: NetworkTileProvider(
                    cachingProvider: const DisabledMapCachingProvider(),
                  ),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin,
                          color: scheme.error, size: 40),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(address!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
