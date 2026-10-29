import 'package:flutter/material.dart';

/// Reused section illustrations recovered from the original DeskSuite branch.
/// These are studio artwork, not substitutes for the canonical app logo.
abstract final class SectionArt {
  static const scan = 'assets/brand/sections/scan.png';
  static const photo = 'assets/brand/sections/photo.png';
  static const text = 'assets/brand/sections/text.png';
  static const office = 'assets/brand/sections/office.png';
  static const design = 'assets/brand/sections/design.png';
  static const projects = 'assets/brand/sections/projects.png';
}

class SectionArtwork extends StatelessWidget {
  const SectionArtwork({
    super.key,
    required this.asset,
    this.size = 64,
    this.fallback = Icons.image_outlined,
  });

  final String asset;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .21),
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: 256,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          fallback,
          size: size * .48,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    ),
  );
}
