/// Suggests a name for a place from its coordinates.
///
/// This is the one thing in Moment that can use the internet, and only
/// when "Look up place names" is turned on. With it off the app is handed
/// no lookup at all.
abstract interface class PlaceNameLookup {
  /// A short name for the place, or null when none could be found for any
  /// reason: nothing there, no connection, the service is down.
  Future<String?> nameFor({
    required double latitude,
    required double longitude,
  });
}
