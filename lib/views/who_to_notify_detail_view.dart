import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/notify_account_details.dart';
import '../models/who_to_notify.dart';
import '../repositories/who_to_notify_repository.dart';
import '../services/estate_service.dart';
import 'who_to_notify_list_view.dart';

final accountDetailsProvider = FutureProvider.autoDispose
    .family<List<NotifyAccountDetails>, String>((ref, whoToNotifyId) async {
  final repo = ref.watch(whoToNotifyRepositoryProvider);
  return repo.fetchAccountDetails(whoToNotifyId);
});

final whoToNotifyEntryProvider = FutureProvider.autoDispose
    .family<WhoToNotify, String>((ref, whoToNotifyId) async {
  final repo = ref.watch(whoToNotifyRepositoryProvider);
  return repo.fetchById(whoToNotifyId);
});

class WhoToNotifyDetailView extends ConsumerStatefulWidget {
  final String whoToNotifyId;

  const WhoToNotifyDetailView({super.key, required this.whoToNotifyId});

  @override
  ConsumerState<WhoToNotifyDetailView> createState() =>
      _WhoToNotifyDetailViewState();
}

class _WhoToNotifyDetailViewState extends ConsumerState<WhoToNotifyDetailView> {
  static const Color _tint = Color(0xFF3A8D5A);

  late TextEditingController _companyNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _weblinkController;
  late TextEditingController _notesController;

  /// Tracks which entry the controllers are currently primed with, so the
  /// fields load their saved values once and are never overwritten while the
  /// user is typing.
  String? _syncedEntryId;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _weblinkController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNumberController.dispose();
    _weblinkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncControllers(WhoToNotify entry) {
    if (_companyNameController.text != entry.companyName) {
      _companyNameController.text = entry.companyName;
    }
    if (_contactNumberController.text != (entry.contactNumber ?? '')) {
      _contactNumberController.text = entry.contactNumber ?? '';
    }
    if (_weblinkController.text != (entry.weblink ?? '')) {
      _weblinkController.text = entry.weblink ?? '';
    }
    if (_notesController.text != (entry.supplementaryNotes ?? '')) {
      _notesController.text = entry.supplementaryNotes ?? '';
    }
  }

  Future<void> _saveEntry(WhoToNotify entry) async {
    final updated = entry.copyWith(
      companyName: _companyNameController.text.trim(),
      contactNumber: _contactNumberController.text.trim().isEmpty
          ? null
          : _contactNumberController.text.trim(),
      weblink: _weblinkController.text.trim().isEmpty
          ? null
          : _weblinkController.text.trim(),
      supplementaryNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    final repo = ref.read(whoToNotifyRepositoryProvider);
    await repo.update(updated);
    ref.invalidate(whoToNotifyEntryProvider(widget.whoToNotifyId));
    ref.invalidate(whoToNotifyListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved.')),
    );
  }

  Future<void> _confirmDeleteEntry(WhoToNotify entry) async {
    final label = entry.companyName.trim().isEmpty
        ? 'this organisation'
        : '"${entry.companyName.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete organisation?'),
        content: Text('This will permanently delete $label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final repo = ref.read(whoToNotifyRepositoryProvider);
    await repo.delete(widget.whoToNotifyId);
    ref.invalidate(whoToNotifyListProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntry =
        ref.watch(whoToNotifyEntryProvider(widget.whoToNotifyId));
    final asyncDetails =
        ref.watch(accountDetailsProvider(widget.whoToNotifyId));
    final isOwner = ref.watch(isOwnerProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: asyncEntry.maybeWhen(
          data: (entry) => Text(entry.companyName),
          orElse: () => const Text('Organisation'),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F1E8), Color(0xFFEDE6D6)],
          ),
        ),
        child: asyncEntry.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Organisation not found.',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          data: (entry) {
            if (isOwner && _syncedEntryId != entry.whoToNotifyId) {
              _syncControllers(entry);
              _syncedEntryId = entry.whoToNotifyId;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(entry, isOwner),
                const SizedBox(height: 20),
                _buildAccountDetailsSection(asyncDetails, isOwner),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(WhoToNotify entry, bool isOwner) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entry.icon, color: _tint, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isOwner
                      ? TextField(
                          controller: _companyNameController,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        )
                      : Text(
                          entry.companyName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildContactRow(
              icon: Icons.phone,
              hint: 'Contact number',
              value: entry.contactNumber,
              controller: _contactNumberController,
              tint: Colors.green,
              keyboardType: TextInputType.phone,
              actionIcon: Icons.call,
              onAction: () => _launchPhone(_contactNumberController.text),
              isOwner: isOwner,
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.public_rounded,
              hint: 'Web link',
              value: entry.weblink,
              controller: _weblinkController,
              tint: Colors.blue,
              keyboardType: TextInputType.url,
              actionIcon: Icons.open_in_new_rounded,
              onAction: () => _launchUrl(_weblinkController.text),
              isOwner: isOwner,
            ),
            const SizedBox(height: 12),
            _buildNotesField(entry, isOwner),
            if (isOwner) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _saveEntry(entry),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tint,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteEntry(entry),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String hint,
    required String? value,
    required TextEditingController controller,
    required Color tint,
    required TextInputType keyboardType,
    required IconData actionIcon,
    required VoidCallback onAction,
    required bool isOwner,
  }) {
    final text = isOwner ? controller.text : (value ?? '');
    final hasValue = text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: isOwner
                ? TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 0,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  )
                : Text(
                    hasValue ? text : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? tint : Colors.grey.shade500,
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(
              actionIcon,
              size: 18,
              color: hasValue ? tint : tint.withValues(alpha: 0.35),
            ),
            onPressed: hasValue ? onAction : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField(WhoToNotify entry, bool isOwner) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.notes, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: isOwner
              ? TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Supplementary notes',
                    border: OutlineInputBorder(),
                  ),
                )
              : (entry.supplementaryNotes != null &&
                      entry.supplementaryNotes!.isNotEmpty
                  ? Text(entry.supplementaryNotes!,
                      style: const TextStyle(fontSize: 15))
                  : Text('Supplementary notes',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 15))),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsSection(
      AsyncValue<List<NotifyAccountDetails>> asyncDetails, bool isOwner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Account details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: () => _addAccountDetails(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        asyncDetails.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) =>
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
          data: (details) {
            if (details.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      isOwner
                          ? 'No account details yet.\nTap "Add" to add sort codes, account numbers, etc.'
                          : 'No account details yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: details
                  .map((d) => _AccountDetailsCard(
                        details: d,
                        isOwner: isOwner,
                        onUpdate: (updated) => _updateAccountDetails(updated),
                        onDelete: () => _deleteAccountDetails(d),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addAccountDetails() async {
    final repo = ref.read(whoToNotifyRepositoryProvider);
    final newDetails = NotifyAccountDetails(
      notifyAccountDetailsId: '',
      whoToNotifyId: widget.whoToNotifyId,
      createdAt: DateTime.now(),
    );
    await repo.insertAccountDetails(newDetails);
    ref.invalidate(accountDetailsProvider(widget.whoToNotifyId));
  }

  Future<void> _updateAccountDetails(NotifyAccountDetails details) async {
    final repo = ref.read(whoToNotifyRepositoryProvider);
    await repo.updateAccountDetails(details);
    ref.invalidate(accountDetailsProvider(widget.whoToNotifyId));
  }

  Future<void> _deleteAccountDetails(NotifyAccountDetails details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account details?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(whoToNotifyRepositoryProvider);
      await repo.deleteAccountDetails(details.notifyAccountDetailsId);
      ref.invalidate(accountDetailsProvider(widget.whoToNotifyId));
    }
  }

  void _launchPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return;
    _launchUrl('tel:$digits');
  }

  Future<void> _launchUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final uri = trimmed.startsWith('tel:')
        ? Uri.parse(trimmed)
        : Uri.parse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AccountDetailsCard extends StatefulWidget {
  final NotifyAccountDetails details;
  final bool isOwner;
  final ValueChanged<NotifyAccountDetails> onUpdate;
  final VoidCallback onDelete;

  const _AccountDetailsCard({
    required this.details,
    required this.isOwner,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_AccountDetailsCard> createState() => _AccountDetailsCardState();
}

class _AccountDetailsCardState extends State<_AccountDetailsCard> {
  late TextEditingController _sortCodeController;
  late TextEditingController _accountCodeController;
  late TextEditingController _otherCodeController;
  late TextEditingController _otherDescriptionController;

  @override
  void initState() {
    super.initState();
    _sortCodeController = TextEditingController(text: widget.details.sortCode);
    _accountCodeController =
        TextEditingController(text: widget.details.accountCode);
    _otherCodeController =
        TextEditingController(text: widget.details.otherCode);
    _otherDescriptionController =
        TextEditingController(text: widget.details.otherDescription);
  }

  @override
  void dispose() {
    _sortCodeController.dispose();
    _accountCodeController.dispose();
    _otherCodeController.dispose();
    _otherDescriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.details.copyWith(
      sortCode: _sortCodeController.text.trim().isEmpty
          ? null
          : _sortCodeController.text.trim(),
      accountCode: _accountCodeController.text.trim().isEmpty
          ? null
          : _accountCodeController.text.trim(),
      otherCode: _otherCodeController.text.trim().isEmpty
          ? null
          : _otherCodeController.text.trim(),
      otherDescription: _otherDescriptionController.text.trim().isEmpty
          ? null
          : _otherDescriptionController.text.trim(),
    );
    widget.onUpdate(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.isOwner;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              'Sort code',
              _sortCodeController,
              '00-00-00',
              editing,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(
              'Account number',
              _accountCodeController,
              'e.g. ACC-51OZR4',
              editing,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(
              'Other code',
              _otherCodeController,
              'Reference, member no., etc.',
              editing,
              showHintWhenEmpty: false,
            ),
            const SizedBox(height: 8),
            _buildField(
              'Description',
              _otherDescriptionController,
              'e.g. Kieren current account',
              editing,
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _WhoToNotifyDetailViewState._tint,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint,
    bool editing, {
    List<TextInputFormatter>? inputFormatters,
    bool showHintWhenEmpty = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: editing
              ? TextField(
                  controller: controller,
                  inputFormatters: inputFormatters,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                )
              : (controller.text.isNotEmpty
                  ? Text(
                      controller.text,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 14),
                    )
                  : showHintWhenEmpty
                      ? Text(hint,
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14))
                      : const SizedBox.shrink()),
        ),
      ],
    );
  }
}
