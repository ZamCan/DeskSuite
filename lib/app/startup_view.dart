import 'package:flutter/material.dart';

import 'theme.dart';

/// Branded local-startup state shown while the on-device workspace opens.
///
/// It uses the same native mark and palette as the sidebar and launcher. It
/// does not add a fixed splash delay: the app proceeds as soon as storage is
/// ready, including on slower phones.
class WorkspaceLoadingView extends StatelessWidget {
  const WorkspaceLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 76),
                const SizedBox(height: 22),
                Text(
                  'DeskSuite',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Documents, photos and print',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 144,
                  child: LinearProgressIndicator(
                    key: Key('workspace-startup-progress'),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Preparing your local workspace…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
