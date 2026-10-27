import 'package:flutter/material.dart';

import 'conversion_catalog.dart';

/// A catalogue of real routes, not a universal file converter. Buttons open the
/// actual studio; unavailable routes have no button.
class ConversionCatalogPage extends StatelessWidget {
  const ConversionCatalogPage({super.key, required this.onOpen});
  final ValueChanged<ConversionTarget> onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Text(
        'Conversion routes',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose a supported route to open its real tool. Outputs are copies: choose a different destination to preserve your source.',
      ),
      const SizedBox(height: 16),
      for (final route in conversionRoutes) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(route.detail),
                const SizedBox(height: 8),
                if (route.target case final target?)
                  OutlinedButton.icon(
                    key: Key('conversion-${target.name}'),
                    onPressed: () => onOpen(target),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open tool'),
                  )
                else
                  Text(
                    'Not available',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}
