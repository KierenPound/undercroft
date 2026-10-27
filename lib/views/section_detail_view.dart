import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';
import 'my_letter_view.dart';
import 'widgets/attachments_section.dart';
import 'widgets/cars_dashboard.dart';
import 'widgets/checklist_section.dart';
import 'widgets/confirmation_dashboard.dart';
import 'widgets/funeral_arrangements_dashboard.dart';
import 'widgets/legal_documents_dashboard.dart';
import 'widgets/notes_section.dart';
import 'widgets/photo_section.dart';
import 'widgets/running_the_houses_dashboard.dart';
import 'widgets/song_for_the_page_section.dart';
import 'widgets/what_to_do_first_dashboard.dart';

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

        final isOwner = asyncIsOwner.valueOrNull ?? true;

        // "My Letter to You" is a standalone page: just the letter, with no
        // checklist, notes or attachments sections below it.
        if (config.title == 'My Letter to You') {
          return MyLetterView(config: config);
        }

        final asyncSection = ref.watch(sectionByTitleProvider(config));

        return Scaffold(
          appBar: AppBar(
            title: Text(config.title),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (config.infoText.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'About this page',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(config.title),
                      content: Text(
                        config.infoText,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                    if (section.title == 'What to Do First')
                      WhatToDoFirstDashboard(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        youtubeUrl: section.youtubeUrl,
                      )
                    else if (section.title == 'Legal Documents') ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset:
                            'assets/images/defaults/default_legal_documents.jpeg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 28),
                      LegalDocumentsDashboard(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        youtubeUrl: section.youtubeUrl,
                      ),
                    ] else if (section.title == 'Confirmation') ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset:
                            'assets/images/defaults/default_confirmation.jpeg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 28),
                      const ConfirmationDashboard(),
                      const SizedBox(height: 28),
                      SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    ] else if (section.title == 'Cars') ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset:
                            'assets/images/defaults/default_cars.jpeg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 28),
                      const CarsDashboard(),
                      const SizedBox(height: 28),
                      SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    ] else if (section.title == 'Funeral Arrangements') ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset:
                            'assets/images/defaults/default_funeral.jpeg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 28),
                      FuneralArrangementsDashboard(
                        estateId: estateId,
                        isOwner: isOwner,
                      ),
                      const SizedBox(height: 28),
                      SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    ] else if (section.title == 'Running the Houses') ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset:
                            'assets/images/defaults/default_running_house.jpeg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 28),
                      RunningTheHousesDashboard(
                        estateId: estateId,
                        isOwner: isOwner,
                      ),
                      const SizedBox(height: 28),
                      SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    ] else ...[
                      PhotoSection(
                        sectionId: section.id,
                        estateId: estateId,
                        isOwner: isOwner,
                        defaultAsset: 'assets/images/wtdl_1.jpg',
                        sectionTitle: section.title,
                      ),
                      const SizedBox(height: 24),
                      SongForThePageSection(youtubeUrl: section.youtubeUrl),
                    ],
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
