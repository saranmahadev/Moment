import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'log_filter.dart';

/// What a type's page shows above its list while a filter is in force:
/// "Showing 3 of 12" and a Clear filter button, and a line when nothing
/// matches. Nothing at all when there is no filter.
List<Widget> filterNotice({
  required LogFilter filter,
  required int total,
  required int shown,
  required MomentTokens tokens,
  VoidCallback? onClear,
}) {
  if (!filter.isActive) return const [];
  return [
    SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $shown of $total',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Clear filter',
            onTap: onClear,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Clear filter',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    if (shown == 0)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Nothing matches this filter.',
          style: TextStyle(fontSize: 15, color: tokens.secondary),
        ),
      ),
  ];
}

/// Today as UTC midnight, the form [LogFilter.apply] wants.
DateTime filterToday(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day);
