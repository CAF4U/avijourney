import 'package:flutter/material.dart';
import '../../domain/models/airport.dart';
import '../../domain/models/aircraft_route.dart';
import '../../domain/models/tracked_aircraft.dart';

/// Map destinations from detail routes; the shell owns tab and camera changes.
class DetailNavigationController extends ChangeNotifier {
  Object? target;
  void airport(Airport value) {
    target = value;
    notifyListeners();
  }

  void route(AircraftRoute value) {
    target = value;
    notifyListeners();
  }

  void aircraft(TrackedAircraft value) {
    target = value;
    notifyListeners();
  }
}

class DetailNavigation extends InheritedWidget {
  const DetailNavigation(
      {required this.controller, required super.child, super.key});
  final DetailNavigationController controller;
  static DetailNavigationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DetailNavigation>()
      ?.controller;
  @override
  bool updateShouldNotify(DetailNavigation oldWidget) =>
      oldWidget.controller != controller;
}
