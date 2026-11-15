import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Whether Moment may read the device's position right now.
enum LocationAccess {
  granted,

  /// Not allowed yet, or refused once: asking again can still succeed.
  denied,

  /// Refused for good, or allowed earlier and since revoked in Settings:
  /// only the system's settings can change it.
  deniedForever,

  /// Location is switched off for the whole device.
  serviceOff,
}

/// One reading of where the device is.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

/// Reads the device's position. Wraps `geolocator` so tests can supply a
/// fake. It deliberately has no way to turn coordinates into a place
/// name: that needs the internet, and lives apart in `PlaceNameLookup`,
/// which the app only reaches when the owner has turned it on.
abstract interface class LocationProvider {
  /// The current access, without prompting.
  Future<LocationAccess> checkAccess();

  /// Asks the system for access if it can still be asked.
  Future<LocationAccess> requestAccess();

  Future<LocationFix> currentFix();

  /// Opens the system's settings for this app.
  Future<void> openSettings();
}

class DeviceLocationProvider implements LocationProvider {
  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };

  @override
  Future<LocationAccess> checkAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<LocationFix> currentFix() async {
    const timeLimit = Duration(seconds: 30);
    final position = await Geolocator.getCurrentPosition(
      locationSettings: Platform.isAndroid
          // The platform's own location manager, not Google Play services.
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: timeLimit,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeLimit,
            ),
    );
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
