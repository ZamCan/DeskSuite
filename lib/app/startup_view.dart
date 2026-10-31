import 'package:flutter/material.dart';

import 'brand_launch.dart';
import 'theme.dart';

/// Quiet local-startup state shown only while the workspace is being prepared.
class WorkspaceLoadingView extends StatelessWidget {
  const WorkspaceLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StationeryWallpaper(
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'DeskSuite',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5,
                        ),
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
