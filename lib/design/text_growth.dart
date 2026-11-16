import 'package:flutter/widgets.dart';

/// How much taller a box that holds text and fixed-size parts (an icon, a
/// row of dots) should be at the system's text size: 1 at the normal size,
/// rising a little over half as fast as the text does, since only part of
/// the box is text. Layouts with a fixed shape use it so nothing is cut
/// off at the largest sizes.
double textGrowth(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return scale <= 1 ? 1 : 1 + (scale - 1) * 0.55;
}

/// The extra height a line of text of [fontSize] needs at the system's
/// text size, over what it needs at the normal size.
double extraTextHeight(BuildContext context, double fontSize) {
  final scaled = MediaQuery.textScalerOf(context).scale(fontSize);
  return scaled <= fontSize ? 0 : (scaled - fontSize) * 1.3;
}
