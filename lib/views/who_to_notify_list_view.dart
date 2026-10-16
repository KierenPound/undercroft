import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/who_to_notify.dart';
import '../repositories/sections_repository.dart';
import '../repositories/who_to_notify_repository.dart';
import '../services/estate_service.dart';
import 'widgets/attachments_section.dart';
import 'widgets/checklist_section.dart';
import 'widgets/notes_section.dart';
import 'widgets/photo_section.dart';
import 'widgets/song_for_the_page_section.dart';

final whoToNotifyListProvider =
    FutureProvider.autoDispose<List<WhoToNotify>>((ref) async {
  final repo = ref.watch(whoToNotifyRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

class WhoToNotifyListView extends ConsumerWidget {
  const WhoToNotifyListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEstateId = ref.watch(estateIdProvider);
    final asyncIsOwner = ref.watch(isOwnerProvider);

    return asyncEstateId.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (estateId) {
        if (estateId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No estate found.')),
          );
        }
        final asyncEntries = ref.watch(whoToNotifyListProvider);
        final asyncSection = ref.watch(wtnSectionProvider(estateId));
        final isOwner = asyncIsOwner.valueOrNull ?? true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Who to Notify'),
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
            child: asyncSection.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (section) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PhotoSection(
                      sectionId: section.id,
                      estateId: estateId,
                      isOwner: isOwner,
                      defaultAsset: 'assets/images/who_to_notify_1.jpg',
                      sectionTitle: 'Who to Notify',
                    ),
                    const SizedBox(height: 24),
                    const _LifeLedgerCallout(),
                    const SizedBox(height: 16),
                    _StaticOrgCard.lifeLedger(),
                    // Entries list loads independently so the Memory photo
                    // and section content render without waiting for it.
                    asyncEntries.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Center(
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('Error: $error', textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(whoToNotifyListProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (entries) {
                        if (entries.isEmpty) {
                          return _EmptyState(
                            onAdd: () => _showAddDialog(context, ref, estateId),
                          );
                        }
                        return Column(
                          children: [
                            _AddOrganisationButton(
                              onAdd: () =>
                                  _showAddDialog(context, ref, estateId),
                            ),
                            ...entries.map((entry) => _EntryCard(
                                  entry: entry,
                                  onTap: () => context.push(
                                    '/who-to-notify/${entry.whoToNotifyId}',
                                  ),
                                )),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _StaticOrgCard.digitalSubscriptions(),
                    const SizedBox(height: 24),
                    const _AppleAccountInstructions(),
                    const SizedBox(height: 24),
                    SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    const SizedBox(height: 24),
                    ChecklistSection(
                      sectionId: section.id,
                      isOwner: isOwner,
                    ),
                    const SizedBox(height: 24),
                    NotesSection(
                      sectionId: section.id,
                      isOwner: isOwner,
                    ),
                    const SizedBox(height: 24),
                    AttachmentsSection(
                      sectionId: section.id,
                      estateId: estateId,
                      isOwner: isOwner,
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, String estateId) async {
    if (estateId.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No estate found. Create one first.')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add organisation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Company name'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final repo = ref.read(whoToNotifyRepositoryProvider);
      await repo.insert(WhoToNotify(
        whoToNotifyId: '',
        estateId: estateId,
        companyName: result.trim(),
        createdAt: DateTime.now(),
      ));
      ref.invalidate(whoToNotifyListProvider);
    }
  }
}

class _AddOrganisationButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddOrganisationButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add new organisation'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A8D5A),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final WhoToNotify entry;
  final VoidCallback onTap;

  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.icon == Icons.notifications
                      ? Colors.grey.shade100
                      : const Color(0xFF3A8D5A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  entry.icon,
                  color: const Color(0xFF3A8D5A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.companyName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2E),
                      ),
                    ),
                    if (entry.contactNumber != null &&
                        entry.contactNumber!.isNotEmpty)
                      Text(
                        entry.contactNumber!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifeLedgerCallout extends StatelessWidget {
  const _LifeLedgerCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start with Life Ledger first',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'It bulk-notifies dozens of companies automatically using the accounts below. Only a few exceptions (Tembo, @SIPP) require direct calls.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Static organisation cards cloned from the FamilyPrep (iOS) WTN seed data.
/// These are not user-editable entries — they're fixed reference cards for
/// Life Ledger, Digital Subscriptions and Computers.
class _StaticOrgCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tint;
  final String? leadParagraph;
  final String? linkLabel;
  final String? linkUrl;
  final List<String> notes;

  const _StaticOrgCard({
    required this.title,
    required this.icon,
    required this.tint,
    this.leadParagraph,
    this.linkLabel,
    this.linkUrl,
    required this.notes,
  });

  factory _StaticOrgCard.lifeLedger() => const _StaticOrgCard(
        title: 'Life Ledger',
        icon: Icons.layers,
        tint: Colors.purple,
        leadParagraph:
            'This secure, free online service allows you to report a death to multiple commercial companies all at once.',
        linkLabel: 'Open Official Portal',
        linkUrl: 'https://lifeledger.com/',
        notes: [
          'Automatically notifies banks, savings, utilities and other places in one go.',
          'Completely free — just bring the company names and account numbers listed below.',
          'Exceptions: eToro and Tembo may not be on Life Ledger — follow their individual sections.',
        ],
      );

  factory _StaticOrgCard.digitalSubscriptions() => const _StaticOrgCard(
        title: 'Digital Subscriptions (Amazon, Apple, etc.)',
        icon: Icons.credit_card,
        tint: Colors.grey,
        notes: [
          'Amazon, Apple, and anything else running on a direct debit or recurring card payment should get cancelled automatically by the bank once they freeze the accounts.',
          "You shouldn't have to contact them. Aside from setting up your own Amazon Prime account or paying for your own deliveries!",
        ],
      );

  Future<void> _openLink(BuildContext context) async {
    if (linkUrl == null) return;
    final uri = Uri.parse(linkUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadParagraph != null) ...[
                Text(
                  leadParagraph!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B6B6E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (linkLabel != null && linkUrl != null) ...[
                InkWell(
                  onTap: () => _openLink(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, color: tint, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          linkLabel!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.open_in_new,
                            color: tint.withValues(alpha: 0.8), size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < notes.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, color: tint, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notes[i],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2C2C2E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AppleAccountInstructions extends StatelessWidget {
  const _AppleAccountInstructions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.apple, color: Color(0xFF007AFF), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'How to Access My Apple Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(
                number: '1',
                title: 'Locate Your Legacy Access Key',
                body:
                    'You will have either received an iMessage or an email with the access key.',
                bullets: [
                  'For iPhone users, go to: Settings → {Your Name} → Sign in & Security → Legacy Contact → Asset Key → {My Name}',
                ],
              ),
              SizedBox(height: 18),
              _Step(
                number: '2',
                title: 'Request Access Online',
                bullets: [
                  'Go to digital-legacy.apple.com on any web browser (phone, tablet, PC, or Mac).',
                  'Click Request Access.',
                  'Sign in using your own Apple Account (if you don\'t have one, you can create a free account on that screen).',
                  'Enter or scan your Legacy Access Key.',
                ],
              ),
              SizedBox(height: 18),
              _Step(
                number: '3',
                title: 'Submit Required Documents',
                bullets: [
                  'Apple will ask you to upload a clear photo or copy of the official Death Certificate.',
                  'Submit the request.',
                ],
              ),
              SizedBox(height: 18),
              _Step(
                number: '4',
                title: 'What Happens Next?',
                bullets: [
                  'Apple\'s legal and support team will review the death certificate (this usually takes 2 to 5 business days).',
                  'Once approved, you will receive an email from Apple with a secure link to log in and download all my photos, messages, files, and account data.',
                  'Unlocking Hardware: Approval automatically removes the Activation Lock from my iPhone and Mac, allowing the devices to be safely reset and repurposed or sold.',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String? body;
  final List<String> bullets;

  const _Step({
    required this.number,
    required this.title,
    this.body,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF007AFF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No organisations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add companies to notify about the estate.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add organisation'),
          ),
        ],
      ),
    );
  }
}
