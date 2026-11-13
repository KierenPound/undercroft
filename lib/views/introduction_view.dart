import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/glossary.dart';
import '../services/introduction_service.dart';

/// The introduction and the glossary of terms.
///
/// Reached two ways: as a one-off gate the first time someone signs in, where
/// [isFirstRun] adds a Continue button because there is nothing behind the
/// screen to go back to; and on demand from Settings, where the app bar's own
/// back button serves instead.
class IntroductionView extends StatefulWidget {
  const IntroductionView({super.key, this.isFirstRun = false});

  final bool isFirstRun;

  @override
  State<IntroductionView> createState() => _IntroductionViewState();
}

class _IntroductionViewState extends State<IntroductionView> {
  bool _finishing = false;

  /// Records the introduction as read before leaving, so the router's gate
  /// does not send the reader straight back here.
  Future<void> _finish() async {
    setState(() => _finishing = true);
    await IntroductionService.markSeen();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Introduction & glossary'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            introductionTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final paragraph in introductionParagraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                paragraph,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          if (widget.isFirstRun) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _finishing ? null : _finish,
                child: const Text('Continue'),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Glossary of terms',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terms carrying a region apply there only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final section in glossary) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 10),
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final entry in section.entries) _GlossaryTile(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _GlossaryTile extends StatelessWidget {
  const _GlossaryTile({required this.entry});

  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A Wrap rather than a Row: "Confirmation Inventory (Form C1)" plus its
    // region tag is wider than a narrow phone, and long terms must wrap
    // instead of overflowing.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                entry.term,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.jurisdiction != null)
                _JurisdictionTag(label: entry.jurisdiction!),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.definition,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Marks a term as belonging to one legal system.
class _JurisdictionTag extends StatelessWidget {
  const _JurisdictionTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
