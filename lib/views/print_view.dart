import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/estate_print_service.dart';
import '../services/estate_service.dart';

const Color _sage = Color(0xFF5B7C6A);
const Color _ink = Color(0xFF2C2C2E);
const Color _muted = Color(0xFF6B6B70);

/// Explains how printing fits alongside the cloud copy, then offers to print
/// or cancel.
///
/// The one button hands off to the system print preview, where the user can
/// pick a printer or choose the platform's "Save as PDF" option (on iOS, the
/// Share button in the preview, then "Save to Files"). The document is the
/// estate record built by [printEstateData]: every saved text field and step,
/// but never the uploaded documents (wills, certificates, photos or scanned
/// ID).
class PrintView extends ConsumerStatefulWidget {
  const PrintView({super.key});

  @override
  ConsumerState<PrintView> createState() => _PrintViewState();
}

class _PrintViewState extends ConsumerState<PrintView> {
  bool _busy = false;

  Future<String> _estateId() async {
    final id = await ref.read(estateIdProvider.future);
    if (id.isEmpty) {
      throw Exception('No estate found for this account.');
    }
    return id;
  }

  /// Opens the system print preview, which also carries the platform's
  /// "Save as PDF" option.
  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final estateId = await _estateId();
      await printEstateData(estateId: estateId);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not prepare the document. $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F1E8),
              Color(0xFFEDE6D6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WarningCard(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print or Save as PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _sage.withValues(alpha: 0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: _sage, size: 22),
              SizedBox(width: 10),
              Text(
                'Your data stays in the cloud',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'UnderCroft data is stored securely in the cloud, and you can '
            'always access it from the app on any mobile device when you '
            'login. If you need to print out the data, please keep it safe.',
            style: TextStyle(fontSize: 15, height: 1.4, color: _ink),
          ),
          SizedBox(height: 12),
          Text(
            'Printed copies list your saved text and steps only. Uploaded '
            'documents such as wills, certificates and photos are not '
            'included.',
            style: TextStyle(fontSize: 13, height: 1.4, color: _muted),
          ),
        ],
      ),
    );
  }
}
