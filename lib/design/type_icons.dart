import 'package:flutter/material.dart';

import '../domain/log_type.dart';

/// The icon shown for each log type's badge throughout the app.
IconData momentIconFor(LogType type) => switch (type) {
  LogType.text => Icons.text_fields_rounded,
  LogType.emoji => Icons.emoji_emotions_outlined,
  LogType.photo => Icons.photo_camera_outlined,
  LogType.video => Icons.videocam_outlined,
  LogType.audio => Icons.mic_none_rounded,
  LogType.location => Icons.location_on_outlined,
};
