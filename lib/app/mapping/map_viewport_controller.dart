import 'package:flutter/foundation.dart';

import '../../domain/models/tracking_center.dart';
import '../../domain/models/aircraft_route.dart';

class MapViewport {
  const MapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.route,
  });

  factory MapViewport.around(TrackingCenter center) => MapViewport(
        latitude: center.latitude,
        longitude: center.longitude,
        zoom: 9,
      );

  final double latitude;
  final double longitude;
  final double zoom;
  final AircraftRoute? route;
}

class MapViewportController extends ChangeNotifier {
  MapViewportController(MapViewport initialViewport)
      : _viewport = initialViewport;

  MapViewport _viewport;
  MapViewport get viewport => _viewport;

  void update(MapViewport viewport) {
    _viewport = viewport;
    notifyListeners();
  }

  void updateFromMap(MapViewport viewport) {
    _viewport = viewport;
  }
}
