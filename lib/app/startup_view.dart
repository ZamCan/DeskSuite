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
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
}
