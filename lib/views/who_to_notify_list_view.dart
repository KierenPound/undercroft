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
            child: asyncEntries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Error: $error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(whoToNotifyListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                return asyncSection.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                  data: (section) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const _LifeLedgerCallout(),
                        if (entries.isEmpty)
                          _EmptyState(
                            onAdd: () => _showAddDialog(context, ref, estateId),
                          )
                        else ...[
                          _AddOrganisationButton(
                            onAdd: () => _showAddDialog(context, ref, estateId),
                          ),
                          ...entries.map((entry) => _EntryCard(
                                entry: entry,
                                onTap: () => context.push(
                                  '/who-to-notify/${entry.whoToNotifyId}',
                                ),
                              )),
                        ],
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
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _launchLifeLedger(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public,
                            color: Colors.purple, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Open Official Portal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.open_in_new,
                            color: Colors.purple.withValues(alpha: 0.8),
                            size: 16),
                      ],
                    ),
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

Future<void> _launchLifeLedger() async {
  final uri = Uri.parse('https://lifeledger.com/');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
