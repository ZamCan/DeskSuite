import 'package:flutter/material.dart';

/// Internal section illustrations, including the Photo Studio PS adaptation.
/// None is the selected DS app logo.
abstract final class SectionArt {
  static const scan = 'assets/brand/sections/scan.png';
  static const photo = 'assets/brand/sections/photo.png';
  static const text = 'assets/brand/sections/text.png';
  static const office = 'assets/brand/sections/office.png';
  static const design = 'assets/brand/sections/design.png';
  static const projects = 'assets/brand/sections/projects.png';

  static const all = [scan, photo, text, office, design, projects];
}

/// Decorative section artwork. Adjacent text supplies the accessible name.
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
