import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/contact.dart';
import '../../repositories/contacts_repository.dart';

/// Contacts: the individual people to notify (family, friends, GP, solicitor),
/// listed above the organisation entries on the Who to Notify page.
///
/// Each contact collapses to a single row showing their name and number, and
/// expands to reveal their name / telephone / email. Owners get editable
/// fields there; everyone else gets a read-only view with tap-to-call and
/// tap-to-email actions.
class ContactsSection extends ConsumerStatefulWidget {
  final String estateId;
  final bool isOwner;

  const ContactsSection({
    super.key,
    required this.estateId,
    required this.isOwner,
  });

  static const Color tint = Color(0xFF3A8D5A);

  @override
  ConsumerState<ContactsSection> createState() => _ContactsSectionState();
}

class _ContactsSectionState extends ConsumerState<ContactsSection> {
  /// A contact that has not been written to the database yet. It only exists
  /// in memory, so backing out of it leaves nothing behind.
  Contact? _draft;

  void _startDraft() {
    setState(() {
      _draft = Contact(
        contactId: '',
        estateId: widget.estateId,
        name: '',
        telephone: '',
        email: '',
        createdAt: DateTime.now(),
      );
    });
  }

  void _clearDraft() => setState(() => _draft = null);

  @override
  Widget build(BuildContext context) {
    final asyncContacts = ref.watch(contactsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(),
        const SizedBox(height: 14),
        if (widget.isOwner && _draft == null) ...[
          _AddContactButton(onAdd: _startDraft),
          const SizedBox(height: 12),
        ],
        asyncContacts.when(
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
                  onPressed: () => ref.invalidate(contactsListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (contacts) {
            final draft = _draft;
            if (contacts.isEmpty && draft == null) return const _EmptyCard();
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < contacts.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                    _ContactTile(
                      key: ValueKey(contacts[i].contactId),
                      contact: contacts[i],
                      isOwner: widget.isOwner,
                    ),
                  ],
                  if (draft != null) ...[
                    if (contacts.isNotEmpty)
                      Divider(height: 1, color: Colors.grey.shade200),
                    _ContactTile(
                      key: const ValueKey('contact-draft'),
                      contact: draft,
                      isOwner: true,
                      isDraft: true,
                      onCommitted: _clearDraft,
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
            color: ContactsSection.tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.contacts,
              color: ContactsSection.tint, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Contacts',
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

class _AddContactButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddContactButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add contact'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ContactsSection.tint,
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
          Icon(Icons.person_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add the people you would want told — family, friends, the GP.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends ConsumerStatefulWidget {
  final Contact contact;
  final bool isOwner;

  /// True while this tile represents an unsaved contact. Saving inserts it,
  /// and deleting simply discards the draft.
  final bool isDraft;
  final VoidCallback? onCommitted;

  const _ContactTile({
    super.key,
    required this.contact,
    required this.isOwner,
    this.isDraft = false,
    this.onCommitted,
  });

  @override
  ConsumerState<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends ConsumerState<_ContactTile> {
  static const Color tint = ContactsSection.tint;

  final _tileController = ExpansibleController();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _tileIsOpen = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _phoneController = TextEditingController(text: widget.contact.telephone);
    _emailController = TextEditingController(text: widget.contact.email);
    _tileIsOpen = _startsOpen;
  }

  @override
  void dispose() {
    _tileController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// A contact with no name yet is one that has just been added, so it opens
  /// ready to be filled in.
  bool get _startsOpen => widget.isOwner && widget.contact.name.trim().isEmpty;

  void _syncControllers() {
    _nameController.text = widget.contact.name;
    _phoneController.text = widget.contact.telephone;
    _emailController.text = widget.contact.email;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this contact a name.')),
      );
      return;
    }

    final repo = ref.read(contactsRepositoryProvider);
    if (widget.isDraft) {
      await repo.insert(Contact(
        contactId: '',
        estateId: widget.contact.estateId,
        name: name,
        telephone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        createdAt: DateTime.now(),
      ));
      ref.invalidate(contactsListProvider);
      widget.onCommitted?.call();
      return;
    }

    await repo.update(widget.contact.copyWith(
      name: name,
      telephone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
    ));
    ref.invalidate(contactsListProvider);
    if (!mounted) return;
    if (_tileIsOpen) _tileController.collapse();
  }

  Future<void> _confirmDelete() async {
    // A draft was never saved, so there is nothing to confirm or delete.
    if (widget.isDraft) {
      widget.onCommitted?.call();
      return;
    }

    final label = widget.contact.name.trim().isEmpty
        ? 'this contact'
        : '"${widget.contact.name.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
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
      final repo = ref.read(contactsRepositoryProvider);
      await repo.delete(widget.contact.contactId);
      ref.invalidate(contactsListProvider);
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
        widget.contact.name.trim().isEmpty
            ? 'New contact'
            : widget.contact.name.trim(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: widget.contact.name.trim().isEmpty
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
          value: widget.contact.name,
          controller: _nameController,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.phone,
          hint: 'Telephone',
          value: widget.contact.telephone,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          rowTint: Colors.green,
          actionIcon: Icons.call,
          onAction: () => _call(_phoneController.text),
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.email_outlined,
          hint: 'Email',
          value: widget.contact.email,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          rowTint: Colors.blue,
          actionIcon: Icons.send,
          onAction: () => _email(_emailController.text),
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
                label: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _avatar() {
    final initials = widget.contact.initials;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: initials.isEmpty
            ? const Icon(Icons.person_outline, color: tint, size: 20)
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
    final phone = widget.contact.telephone.trim();
    if (phone.isNotEmpty) return Text(phone, style: _subtitleStyle);
    final email = widget.contact.email.trim();
    if (email.isNotEmpty) return Text(email, style: _subtitleStyle);
    return null;
  }

  static final TextStyle _subtitleStyle = TextStyle(
    fontSize: 13,
    color: Colors.grey.shade600,
  );

  /// A single contact detail row: icon, then either an editable field (owner)
  /// or read-only text, with an action button that dials or emails.
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
}
