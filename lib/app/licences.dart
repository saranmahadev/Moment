import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what Moment bundles from others, beyond its Dart packages (which
/// Flutter lists itself), to the licence page in About.
void registerAppLicences() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter', 'Newsreader'], ofl);
    yield const LicenseEntryWithLineBreaks(
      ['Natural Earth'],
      'Map data from Natural Earth (naturalearthdata.com), 1:10m cultural '
      'and physical vectors. Natural Earth is in the public domain; no '
      'permission is needed to use it. Moment builds its offline map '
      'tiles from it with tool/build_map_data.py.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OpenStreetMap'],
      'Place names, when "Look up place names" is turned on, come from '
      'Nominatim and OpenStreetMap. © OpenStreetMap contributors. The '
      'data is available under the Open Database License (ODbL), '
      'openstreetmap.org/copyright.',
    );
  });
}
