import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../data/media_store.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../detail/emoji_detail_screen.dart';
import '../detail/text_detail_screen.dart';
import '../emoji/create_emoji_screen.dart';
import '../home/add_sheet.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../lock/app_lock_controller.dart';
import '../photo/create_photo_screen.dart';
import '../photo/photo_detail_screen.dart';
import '../photo/photo_picker.dart';
import '../photo/photo_section_screen.dart';
import '../privacy/privacy_screen.dart';
import '../section/section_screen.dart';
import '../settings/settings_screen.dart';
import '../text/create_text_screen.dart';
import '../trash/trash_screen.dart';

enum _Tab { home, library, calendar, settings }

/// The app's tab shell: Home, Library, Add, Calendar and Settings behind a
/// persistent dock, matching the `<nav>` in every mockup (e.g.
/// design/mockups/Main.dc.html). Add opens a sheet instead of being a tab.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.lockController,
    required this.mediaStore,
    required this.picker,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final AppLockController lockController;
  final MediaStore mediaStore;
  final PhotoPicker picker;
  final DateTime Function() now;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.home;

  Future<void> _openAddSheet() async {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => AddSheet(
        onTypeSelected: (type) {
          Navigator.of(sheetContext).pop();
          _handleTypeSelected(type);
        },
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void _handleTypeSelected(LogType type) {
    switch (type) {
      case LogType.text:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateTextScreen(
              repository: widget.repository,
              onSaved: (_) => Navigator.of(context).pop(),
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        );
      case LogType.emoji:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateEmojiScreen(
              repository: widget.repository,
              onSaved: (_) => Navigator.of(context).pop(),
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        );
      case LogType.photo:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreatePhotoScreen(
              repository: widget.repository,
              mediaStore: widget.mediaStore,
              picker: widget.picker,
              now: widget.now,
              onSaved: (_) => Navigator.of(context).pop(),
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        );
      // Not in builtLogTypes yet, so AddSheet never offers these: nothing
      // to wire up until their own chunks add both the screen and the type.
      case LogType.video:
      case LogType.audio:
      case LogType.location:
        break;
    }
  }

  void _openDetail(Log log) {
    final screen = switch (log) {
      TextLog() => TextDetailScreen(
        log: log,
        repository: widget.repository,
        now: widget.now,
        onBack: () => Navigator.of(context).pop(),
      ),
      EmojiLog() => EmojiDetailScreen(
        log: log,
        repository: widget.repository,
        now: widget.now,
        onBack: () => Navigator.of(context).pop(),
      ),
      PhotoLog() => PhotoDetailScreen(
        log: log,
        repository: widget.repository,
        mediaStore: widget.mediaStore,
        picker: widget.picker,
        now: widget.now,
        onBack: () => Navigator.of(context).pop(),
      ),
      AudioLog() => throw UnimplementedError('Audio detail is not built yet'),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrashScreen(
          repository: widget.repository,
          now: widget.now,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyScreen(
          controller: widget.lockController,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openSection(LogType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => type == LogType.photo
            ? PhotoSectionScreen(
                repository: widget.repository,
                onBack: () => Navigator.of(context).pop(),
                onOpenLog: _openDetail,
              )
            : SectionScreen(
                type: type,
                repository: widget.repository,
                onBack: () => Navigator.of(context).pop(),
                onOpenLog: _openDetail,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<MomentTokens>() ?? MomentTokens.standard;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: OrbField()),
          IndexedStack(
            index: _Tab.values.indexOf(_tab),
            children: [
              HomeScreen(
                repository: widget.repository,
                now: widget.now,
                onOpenLog: _openDetail,
              ),
              LibraryScreen(
                repository: widget.repository,
                now: widget.now,
                onOpenType: _openSection,
                onOpenTrash: _openTrash,
              ),
              const _Placeholder('Calendar'),
              SettingsScreen(
                repository: widget.repository,
                onOpenPrivacy: _openPrivacy,
                onOpenTrash: _openTrash,
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: _Dock(
                tab: _tab,
                tokens: tokens,
                onTabSelected: (tab) => setState(() => _tab = tab),
                onAddTapped: _openAddSheet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}

class _Dock extends StatelessWidget {
  const _Dock({
    required this.tab,
    required this.tokens,
    required this.onTabSelected,
    required this.onAddTapped,
  });

  final _Tab tab;
  final MomentTokens tokens;
  final ValueChanged<_Tab> onTabSelected;
  final VoidCallback onAddTapped;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: GlassSurface(
        variant: GlassVariant.strong,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DockItem(
                key: const ValueKey('dock-tab-Home'),
                label: 'Home',
                icon: Icons.home_outlined,
                isActive: tab == _Tab.home,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.home),
              ),
              _DockItem(
                key: const ValueKey('dock-tab-Library'),
                label: 'Library',
                icon: Icons.grid_view_rounded,
                isActive: tab == _Tab.library,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.library),
              ),
              _AddButton(tokens: tokens, onTap: onAddTapped),
              _DockItem(
                key: const ValueKey('dock-tab-Calendar'),
                label: 'Calendar',
                icon: Icons.calendar_today_outlined,
                isActive: tab == _Tab.calendar,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.calendar),
              ),
              _DockItem(
                key: const ValueKey('dock-tab-Settings'),
                label: 'Settings',
                icon: Icons.tune_rounded,
                isActive: tab == _Tab.settings,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? tokens.ink : tokens.secondary;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          height: 58,
          decoration: BoxDecoration(
            color: isActive ? tokens.ink.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.tokens, required this.onTap});

  final MomentTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a log',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tokens.ink,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tokens.ink.withValues(alpha: 0.3),
                offset: const Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
