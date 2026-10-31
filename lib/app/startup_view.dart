import 'package:flutter/material.dart';

import 'theme.dart';
import 'stationery_pattern.dart';

/// Branded local-startup state shown only while the on-device workspace opens.
/// It contains no simulated progress and does not hold the user behind a timer.
class WorkspaceLoadingView extends StatelessWidget {
  const WorkspaceLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        const StationeryPattern(),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 76),
                  const SizedBox(height: 20),
                  Text(
                    'DeskSuite',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
