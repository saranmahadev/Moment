import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../settings/app_settings.dart';

/// The app's `MaterialApp`, themed from [settings]: light, dark or the
/// system's choice, with or without glass. A change to either setting
/// rebuilds it at once. Until the settings have loaded ([settings] is
/// null) it follows the system.
class ThemedApp extends StatelessWidget {
  const ThemedApp({super.key, required this.settings, required this.home});

  final AppSettings? settings;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final settings = this.settings;
    if (settings == null) return _app(ThemeMode.system, false);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) =>
          _app(settings.themeMode, settings.reduceTransparency),
    );
  }

  Widget _app(ThemeMode mode, bool reduceTransparency) {
    return MaterialApp(
      title: 'Moment',
      debugShowCheckedModeBanner: false,
      theme: momentTheme(reduceTransparency: reduceTransparency),
      darkTheme: momentTheme(
        brightness: Brightness.dark,
        reduceTransparency: reduceTransparency,
      ),
      themeMode: mode,
      home: home,
    );
  }
}
