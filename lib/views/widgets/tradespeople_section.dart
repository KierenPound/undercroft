import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/tradesperson.dart';
import '../../repositories/tradespeople_repository.dart';

/// Tradespeople: the trades the estate relies on — gas, electric, drains and
/// so on — listed on the Running the Houses page.
///
/// Each entry collapses to a row showing the name and a number or address,
/// and expands to reveal name / email / telephone / web link / notes. Owners
/// get editable fields there; everyone else gets a read-only view with
/// tap-to-call, tap-to-email and open-link actions.
class TradespeopleSection extends ConsumerWidget {
  final String estateId;
  final bool isOwner;

  const TradespeopleSection({
    super.key,
    required this.estateId,
    required this.isOwner,
  });

  static const Color tint = Colors.indigo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTradespeople = ref.watch(tradespeopleListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(),
        const SizedBox(height: 14),
        if (isOwner) ...[
          _AddTradespersonButton(
            onAdd: () => _addTradesperson(ref, estateId),
          ),
          const SizedBox(height: 12),
        ],
        asyncTradespeople.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Center(
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text('Error: $error', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(tradespeopleListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (tradespeople) {
            if (tradespeople.isEmpty) return const _EmptyCard();
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < tradespeople.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                    _TradespersonTile(
                      tradesperson: tradespeople[i],
                      isOwner: isOwner,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Adds a blank tradesperson. The tile opens straight into edit mode (it
  /// has no name yet), the same interaction as a new contact.
  Future<void> _addTradesperson(WidgetRef ref, String estateId) async {
    final repo = ref.read(tradespeopleRepositoryProvider);
    await repo.insert(Tradesperson(
      tradespersonId: '',
      estateId: estateId,
      name: '',
      email: '',
      telephone: '',
      url: '',
      notes: '',
      createdAt: DateTime.now(),
    ));
    ref.invalidate(tradespeopleListProvider);
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TradespeopleSection.tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.handyman,
              color: TradespeopleSection.tint, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Tradespeople',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTradespersonButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddTradespersonButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add tradesperson'),
      style: ElevatedButton.styleFrom(
        backgroundColor: TradespeopleSection.tint,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.handyman, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'No tradespeople yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add the gas engineer, electrician, drain specialist — anyone you '
            'call on when the house needs work.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TradespersonTile extends ConsumerStatefulWidget {
  final Tradesperson tradesperson;
  final bool isOwner;

  const _TradespersonTile({
    required this.tradesperson,
    required this.isOwner,
  });

  @override
  ConsumerState<_TradespersonTile> createState() => _TradespersonTileState();
}

class _TradespersonTileState extends ConsumerState<_TradespersonTile> {
  static const Color tint = TradespeopleSection.tint;

  final _tileController = ExpansibleController();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;
  bool _tileIsOpen = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tradesperson.name);
    _emailController = TextEditingController(text: widget.tradesperson.email);
    _phoneController =
        TextEditingController(text: widget.tradesperson.telephone);
    _urlController = TextEditingController(text: widget.tradesperson.url);
    _notesController = TextEditingController(text: widget.tradesperson.notes);
    _tileIsOpen = _startsOpen;
  }

  @override
  void dispose() {
    _tileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// A tradesperson with no name yet is one that has just been added, so it
  /// opens ready to be filled in.
  bool get _startsOpen =>
      widget.isOwner && widget.tradesperson.name.trim().isEmpty;

  void _syncControllers() {
    _nameController.text = widget.tradesperson.name;
    _emailController.text = widget.tradesperson.email;
    _phoneController.text = widget.tradesperson.telephone;
    _urlController.text = widget.tradesperson.url;
    _notesController.text = widget.tradesperson.notes;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this tradesperson a name.')),
      );
      return;
    }

    final repo = ref.read(tradespeopleRepositoryProvider);
    await repo.update(widget.tradesperson.copyWith(
      name: name,
      email: _emailController.text.trim(),
      telephone: _phoneController.text.trim(),
      url: _urlController.text.trim(),
      notes: _notesController.text.trim(),
    ));
    ref.invalidate(tradespeopleListProvider);
    if (!mounted) return;
    if (_tileIsOpen) _tileController.collapse();
  }

  Future<void> _confirmDelete() async {
    final label = widget.tradesperson.name.trim().isEmpty
        ? 'this tradesperson'
        : '"${widget.tradesperson.name.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tradesperson?'),
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

    if (confirmed == true) {
      final repo = ref.read(tradespeopleRepositoryProvider);
      await repo.delete(widget.tradesperson.tradespersonId);
      ref.invalidate(tradespeopleListProvider);
    }
  }

  void _call(String value) {
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return;
    _launch(Uri.parse('tel:$digits'));
  }

  void _email(String value) {
    final address = value.trim();
    if (address.isEmpty) return;
    _launch(Uri(scheme: 'mailto', path: address));
  }

  void _openUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final uri = Uri.tryParse(
      text.contains('://') ? text : 'https://$text',
    );
    if (uri == null) return;
    _launch(uri);
  }

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      controller: _tileController,
      initiallyExpanded: _startsOpen,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: tint,
      collapsedIconColor: Colors.grey.shade400,
      leading: _avatar(),
      title: Text(
        widget.tradesperson.name.trim().isEmpty
            ? 'New tradesperson'
            : widget.tradesperson.name.trim(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: widget.tradesperson.name.trim().isEmpty
              ? Colors.grey.shade500
              : const Color(0xFF2C2C2E),
        ),
      ),
      subtitle: _subtitle(),
      onExpansionChanged: (open) {
        if (open && widget.isOwner) _syncControllers();
        setState(() => _tileIsOpen = open);
      },
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _fieldRow(
          icon: Icons.person_outline,
          hint: 'Name',
          value: widget.tradesperson.name,
          controller: _nameController,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.email_outlined,
          hint: 'Email',
          value: widget.tradesperson.email,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          rowTint: Colors.blue,
          actionIcon: Icons.send,
          onAction: () => _email(_emailController.text),
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.phone,
          hint: 'Telephone',
          value: widget.tradesperson.telephone,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          rowTint: Colors.green,
          actionIcon: Icons.call,
          onAction: () => _call(_phoneController.text),
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.public_rounded,
          hint: 'Web link',
          value: widget.tradesperson.url,
          controller: _urlController,
          keyboardType: TextInputType.url,
          rowTint: Colors.blue,
          actionIcon: Icons.open_in_new_rounded,
          onAction: () => _openUrl(_urlController.text),
        ),
        const SizedBox(height: 10),
        _notesRow(),
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
                    backgroundColor: tint,
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
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                label:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _avatar() {
    final initials = widget.tradesperson.initials;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: initials.isEmpty
            ? const Icon(Icons.handyman, color: tint, size: 20)
            : Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
      ),
    );
  }

  Widget? _subtitle() {
    // The number (or, failing that, the email) anchors the left; the start of
    // the notes sits to its right so a collapsed tile still tells you who they
    // are at a glance.
    final leading = widget.tradesperson.telephone.trim().isNotEmpty
        ? widget.tradesperson.telephone.trim()
        : widget.tradesperson.email.trim();
    final notes = _notesPreview;

    if (leading.isEmpty && notes.isEmpty) return null;
    if (notes.isEmpty) return Text(leading, style: _subtitleStyle);

    return Row(
      children: [
        if (leading.isNotEmpty) ...[
          Text(leading, style: _subtitleStyle),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            notes,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _subtitleStyle,
          ),
        ),
      ],
    );
  }

  /// The first line of the saved notes, for the collapsed tile only.
  String get _notesPreview {
    final raw = widget.tradesperson.notes.trim();
    if (raw.isEmpty) return '';
    return raw.split('\n').first.trim();
  }

  static final TextStyle _subtitleStyle = TextStyle(
    fontSize: 13,
    color: Colors.grey.shade600,
  );

  /// A single detail row: icon, then either an editable field (owner) or
  /// read-only text, with an action button that dials, emails or opens a link.
  Widget _fieldRow({
    required IconData icon,
    required String hint,
    required String value,
    required TextEditingController controller,
    required TextInputType keyboardType,
    Color? rowTint,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    final color = rowTint ?? tint;
    final text = widget.isOwner ? controller.text : value;
    final hasValue = text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: widget.isOwner
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
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 0,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  )
                : Text(
                    hasValue ? text : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? color : Colors.grey.shade500,
                    ),
                  ),
          ),
          if (actionIcon != null)
            IconButton(
              icon: Icon(
                actionIcon,
                size: 18,
                color: hasValue ? color : color.withValues(alpha: 0.35),
              ),
              onPressed: hasValue ? onAction : null,
            ),
        ],
      ),
    );
  }

  /// The notes row: multi-line, so instructions can wrap rather than being
  /// cut off at the edge of the card.
  Widget _notesRow() {
    const color = Colors.blueGrey;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 14),
            child: Icon(Icons.notes, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: widget.isOwner
                ? TextField(
                    controller: _notesController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Notes',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 0,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2C2C2E),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                    child: Text(
                      widget.tradesperson.notes.trim().isEmpty
                          ? 'Notes'
                          : widget.tradesperson.notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.tradesperson.notes.trim().isEmpty
                            ? Colors.grey.shade500
                            : const Color(0xFF2C2C2E),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
