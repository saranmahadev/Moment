import 'package:moment/location/location_provider.dart';

/// A scripted [LocationProvider]: the access the device would report, the
/// access a request would end with, and the fix it would return.
class FakeLocationProvider implements LocationProvider {
  FakeLocationProvider({
    this.access = LocationAccess.granted,
    LocationAccess? afterRequest,
    this.fix = const LocationFix(
      latitude: 12.971598765432101,
      longitude: 77.59456234567891,
      accuracyMeters: 12,
    ),
  }) : afterRequest = afterRequest ?? access;

  LocationAccess access;
  LocationAccess afterRequest;
  LocationFix fix;

  int requests = 0;
  int fixes = 0;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> checkAccess() async => access;

  @override
  Future<LocationAccess> requestAccess() async {
    requests++;
    return access = afterRequest;
  }

  @override
  Future<LocationFix> currentFix() async {
    fixes++;
    if (access != LocationAccess.granted) {
      throw StateError('no location access');
    }
    return fix;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
