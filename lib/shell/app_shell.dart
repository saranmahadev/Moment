import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/tokens.dart';
import '../domain/log.dart';
import '../domain/log_type.dart';
import '../home/add_sheet.dart';
import '../home/home_screen.dart';

enum _Tab { home, library, calendar, settings }

/// The app's tab shell: Home, Library, Add, Calendar and Settings behind a
/// persistent dock, matching the `<nav>` in every mockup (e.g.
/// design/mockups/Main.dc.html). Add opens a sheet instead of being a tab.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.onOpenLog,
    this.onAddType,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final ValueChanged<Log>? onOpenLog;
  final ValueChanged<LogType>? onAddType;

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
      backgroundColor: tokens.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => AddSheet(
        onTypeSelected: (type) {
          Navigator.of(sheetContext).pop();
          widget.onAddType?.call(type);
        },
        onClose: () => Navigator.of(sheetContext).pop(),
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
          IndexedStack(
            index: _Tab.values.indexOf(_tab),
            children: [
              HomeScreen(
                repository: widget.repository,
                now: widget.now,
                onOpenLog: widget.onOpenLog,
              ),
              const _Placeholder('Library'),
              const _Placeholder('Calendar'),
              const _Placeholder('Settings'),
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
                label: 'Home',
                icon: Icons.home_outlined,
                isActive: tab == _Tab.home,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.home),
              ),
              _DockItem(
                label: 'Library',
                icon: Icons.grid_view_rounded,
                isActive: tab == _Tab.library,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.library),
              ),
              _AddButton(tokens: tokens, onTap: onAddTapped),
              _DockItem(
                label: 'Calendar',
                icon: Icons.calendar_today_outlined,
                isActive: tab == _Tab.calendar,
                tokens: tokens,
                onTap: () => onTabSelected(_Tab.calendar),
              ),
              _DockItem(
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
