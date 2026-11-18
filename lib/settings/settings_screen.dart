import 'package:flutter/material.dart';

import '../app/app_info.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../streaks/streak_settings_screen.dart';
import '../widgets/widget_bridge.dart';
import '../widgets/widget_settings_screen.dart';
import 'about_screen.dart';
import 'app_settings.dart';
import 'media_quality.dart';
import 'quick_emoji_screen.dart';
import 'reminder_scheduler.dart';

/// Picks a time of day; [showTimePicker] in the app, a canned answer in
/// tests.
typedef TimePicker =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> _showTimePicker(BuildContext context, TimeOfDay initial) =>
    showTimePicker(context: context, initialTime: initial);

String _clock(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

const _themeChoices = [
  (ThemeMode.system, 'System', 'Follow the system'),
  (ThemeMode.light, 'Light', 'Always light'),
  (ThemeMode.dark, 'Dark', 'Always dark'),
];

/// Settings hub matching design/mockups/png/25-Settings.png: your data,
/// logging (quick emoji row, the daily reminder, photo quality),
/// appearance (theme, Reduce Transparency) and about. Every option is
/// kept in [AppSettings] and takes effect at once.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.reminders,
    required this.onOpenPrivacy,
    required this.onOpenTrash,
    this.pickTime = _showTimePicker,
    this.widgetBridge = const DeviceWidgetBridge(),
  });

  final LogRepository repository;
  final AppSettings settings;
  final ReminderScheduler reminders;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTrash;
  final TimePicker pickTime;
  final WidgetBridge widgetBridge;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Shown under the reminder row when notifications were refused.
  bool _notificationsRefused = false;

  LogRepository get repository => widget.repository;
  AppSettings get settings => widget.settings;
  VoidCallback get onOpenPrivacy => widget.onOpenPrivacy;
  VoidCallback get onOpenTrash => widget.onOpenTrash;

  Future<void> _setReminder(bool on) async {
    if (!on) {
      await widget.reminders.disable();
      await settings.setReminderOn(false);
      if (mounted) setState(() => _notificationsRefused = false);
      return;
    }
    final allowed = await widget.reminders.enable(settings.reminderTime);
    if (allowed) await settings.setReminderOn(true);
    if (mounted) setState(() => _notificationsRefused = !allowed);
  }

  Future<void> _changeReminderTime() async {
    final picked = await widget.pickTime(context, settings.reminderTime);
    if (picked == null) return;
    await settings.setReminderTime(picked);
    if (settings.reminderOn) await widget.reminders.enable(picked);
  }

  void _push(Widget Function(VoidCallback back) screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => screen(() => Navigator.of(context).pop()),
      ),
    );
  }

  /// A sheet of mutually exclusive choices; the current one is ticked.
  Future<void> _choose<T>({
    required String title,
    required List<(T, String, String)> choices,
    required T current,
    required ValueChanged<T> onChosen,
    String? footnote,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tokens =
            Theme.of(sheetContext).extension<MomentTokens>() ??
            MomentTokens.standard;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GlassSurface(
              variant: GlassVariant.strong,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontWeight: FontWeight.w500,
                          fontSize: 24,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final (value, label, description) in choices)
                      Semantics(
                        button: true,
                        selected: value == current,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            onChosen(value);
                            Navigator.of(sheetContext).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.ink,
                                        ),
                                      ),
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: tokens.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (value == current)
                                  Icon(
                                    Icons.check,
                                    size: 20,
                                    color: tokens.ink,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (footnote != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          footnote,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: tokens.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      // Transparent: this screen is always a tab inside AppShell, which
      // already paints tokens.ground and the shared OrbField behind it.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => _list(tokens),
        ),
      ),
    );
  }

  Widget _list(MomentTokens tokens) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontWeight: FontWeight.w500,
            fontSize: 38,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: 14),
        _SectionLabel('YOUR DATA', tokens: tokens),
        const SizedBox(height: 8),
        GlassSurface(
          variant: GlassVariant.card,
          child: Column(
            children: [
              _Row(
                tokens: tokens,
                title: 'Privacy and backup',
                subtitle: 'App lock, encrypted backup, export',
                onTap: onOpenPrivacy,
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: tokens.secondary,
                ),
              ),
              _divider(tokens),
              StreamBuilder<List<Log>>(
                stream: repository.watchTrash(),
                builder: (context, snapshot) {
                  final count = (snapshot.data ?? const []).length;
                  return _Row(
                    tokens: tokens,
                    title: 'Trash',
                    subtitle: 'Deleted logs stay for 30 days',
                    onTap: onOpenTrash,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count ${count == 1 ? 'log' : 'logs'}',
                          style: TextStyle(
                            fontSize: 15,
                            color: tokens.secondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: tokens.secondary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('LOGGING', tokens: tokens),
        const SizedBox(height: 8),
        GlassSurface(
          variant: GlassVariant.card,
          child: Column(
            children: [
              _Row(
                tokens: tokens,
                title: 'Quick emoji row',
                subtitle: 'Five emoji on Home',
                onTap: () => _push(
                  (back) => QuickEmojiScreen(settings: settings, onBack: back),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit',
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ],
                ),
              ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Evening reminder',
                subtitle:
                    'Local notification at ${_clock(settings.reminderTime)}',
                onTap: _changeReminderTime,
                trailing: Semantics(
                  label: 'Evening reminder',
                  child: Switch(
                    key: const ValueKey('reminder-switch'),
                    value: settings.reminderOn,
                    onChanged: _setReminder,
                    activeThumbColor: tokens.onInk,
                    activeTrackColor: tokens.ink,
                    inactiveTrackColor: tokens.switchOff,
                  ),
                ),
              ),
              if (_notificationsRefused)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Notifications are off for Moment. Allow them in the '
                    'system settings, then turn the reminder on again.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: tokens.danger,
                    ),
                  ),
                ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Video and photo quality',
                onTap: () => _choose<MediaQuality>(
                  title: 'Video and photo quality',
                  choices: [
                    for (final quality in MediaQuality.values)
                      (quality, quality.label, quality.description),
                  ],
                  current: settings.mediaQuality,
                  onChosen: settings.setMediaQuality,
                  footnote:
                      'Applies to photos added from now on. Videos are '
                      'always kept as recorded.',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.mediaQuality.label,
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ],
                ),
              ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Streaks',
                subtitle: settings.showStreaks
                    ? graceLabel(settings.graceDays)
                    : 'Hidden',
                onTap: () => _push(
                  (back) =>
                      StreakSettingsScreen(settings: settings, onBack: back),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.showStreaks ? 'On' : 'Off',
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ],
                ),
              ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Widgets',
                subtitle: widgetShowsLabel(settings),
                onTap: () => _push(
                  (back) => WidgetSettingsScreen(
                    settings: settings,
                    bridge: widget.widgetBridge,
                    onBack: back,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: tokens.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('APPEARANCE', tokens: tokens),
        const SizedBox(height: 8),
        GlassSurface(
          variant: GlassVariant.card,
          child: Column(
            children: [
              _Row(
                tokens: tokens,
                title: 'Theme',
                onTap: () => _choose<ThemeMode>(
                  title: 'Theme',
                  choices: _themeChoices,
                  current: settings.themeMode,
                  onChosen: settings.setThemeMode,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _themeChoices
                          .firstWhere((c) => c.$1 == settings.themeMode)
                          .$2,
                      style: TextStyle(fontSize: 15, color: tokens.secondary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.secondary,
                    ),
                  ],
                ),
              ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Reduce transparency',
                subtitle: 'Swaps glass for solid surfaces',
                trailing: Semantics(
                  label: 'Reduce transparency',
                  child: Switch(
                    key: const ValueKey('reduce-transparency-switch'),
                    value: settings.reduceTransparency,
                    onChanged: settings.setReduceTransparency,
                    activeThumbColor: tokens.onInk,
                    activeTrackColor: tokens.ink,
                    inactiveTrackColor: tokens.switchOff,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('ABOUT', tokens: tokens),
        const SizedBox(height: 8),
        GlassSurface(
          variant: GlassVariant.card,
          child: Column(
            children: [
              _Row(
                tokens: tokens,
                title: 'How Moment stays local',
                onTap: () => _push((back) => AboutScreen(onBack: back)),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: tokens.secondary,
                ),
              ),
              _divider(tokens),
              _Row(
                tokens: tokens,
                title: 'Version',
                trailing: Text(
                  appVersion,
                  style: TextStyle(fontSize: 15, color: tokens.secondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(MomentTokens tokens) =>
      Divider(height: 1, color: tokens.secondary.withValues(alpha: 0.15));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.tokens});

  final String text;
  final MomentTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: tokens.secondary,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.tokens,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final MomentTokens tokens;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13.5, color: tokens.secondary),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
