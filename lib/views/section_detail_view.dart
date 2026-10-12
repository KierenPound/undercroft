import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';
import 'widgets/attachments_section.dart';
import 'widgets/checklist_section.dart';
import 'widgets/notes_section.dart';
import 'widgets/song_for_the_page_section.dart';

class SectionDetailView extends ConsumerWidget {
  final SectionConfig config;

  const SectionDetailView({super.key, required this.config});

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

        final asyncSection = ref.watch(sectionByTitleProvider(config));
        final isOwner = asyncIsOwner.valueOrNull ?? true;

        return Scaffold(
          appBar: AppBar(
            title: Text(config.title),
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
}
