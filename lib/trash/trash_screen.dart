import 'package:flutter/material.dart';

import '../data/log_repository.dart';
import '../design/glass_surface.dart';
import '../design/orb_field.dart';
import '../design/tokens.dart';
import '../design/type_icons.dart';
import '../domain/log.dart';

String _previewFor(Log log) => switch (log) {
  TextLog() => log.body,
  EmojiLog() => log.label ?? log.emoji,
};

String _deletedLabelFor(Log log, DateTime now) {
  final days = now.difference(log.deletedAt!).inDays;
  if (days <= 0) return 'Deleted today';
  if (days == 1) return 'Deleted 1 day ago';
  return 'Deleted $days days ago';
}

/// Trash: soft-deleted logs, restorable for 30 days. Matches
/// design/mockups/png/27-Trash.png.
class TrashScreen extends StatelessWidget {
  const TrashScreen({
    super.key,
    required this.repository,
    DateTime Function()? now,
    this.onBack,
  }) : now = now ?? DateTime.now;

  final LogRepository repository;
  final DateTime Function() now;
  final VoidCallback? onBack;

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'Logs in Trash will be removed for good, along with their files. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await repository.emptyTrash();
    }
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
          SafeArea(
            child: StreamBuilder<List<Log>>(
              stream: repository.watchTrash(),
              builder: (context, snapshot) {
                final logs = snapshot.data ?? const [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: onBack,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: GlassSurface(
                            variant: GlassVariant.card,
                            borderRadius: 22,
                            child: Icon(Icons.chevron_left, color: tokens.ink),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Trash',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontWeight: FontWeight.w500,
                        fontSize: 38,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassSurface(
                      variant: GlassVariant.card,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: tokens.ink,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Deleted logs stay here for 30 days, then are '
                                'removed for good along with their files.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final log in logs)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _TrashRow(
                          log: log,
                          tokens: tokens,
                          deletedLabel: _deletedLabelFor(log, now()),
                          onRestore: () => repository.restore(log.id),
                        ),
                      ),
                    if (logs.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => _confirmEmptyTrash(context),
                          child: SizedBox(
                            height: 44,
                            child: GlassSurface(
                              variant: GlassVariant.card,
                              borderRadius: 22,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: tokens.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Empty Trash',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.log,
    required this.tokens,
    required this.deletedLabel,
    required this.onRestore,
  });

  final Log log;
  final MomentTokens tokens;
  final String deletedLabel;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final color = tokens.colorFor(log.type);
    return GlassSurface(
      variant: GlassVariant.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.tintFor(log.type),
                shape: BoxShape.circle,
              ),
              child: Icon(momentIconFor(log.type), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    momentLabelFor(log.type),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    _previewFor(log),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: tokens.ink),
                  ),
                  Text(
                    deletedLabel,
                    style: TextStyle(fontSize: 12.5, color: tokens.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRestore,
              child: SizedBox(
                height: 40,
                child: GlassSurface(
                  variant: GlassVariant.card,
                  borderRadius: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restore, size: 16, color: tokens.ink),
                        const SizedBox(width: 6),
                        Text(
                          'Restore',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
