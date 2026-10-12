import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/sections_repository.dart';

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({super.key});

  static const List<_SectionItem> _sections = [
    _SectionItem(
      title: 'What to Do First',
      icon: Icons.flag,
      color: Color(0xFFD64545),
      config: SectionConfig(
        title: 'What to Do First',
        orderIndex: 0,
        youtubeUrl: 'https://www.youtube.com/watch?v=b4ZypVnbYHM',
      ),
    ),
    _SectionItem(
      title: 'Legal Documents',
      icon: Icons.description,
      color: Color(0xFF2D5FCD),
      config: SectionConfig(
        title: 'Legal Documents',
        orderIndex: 1,
        youtubeUrl: 'https://youtu.be/AL8chWFuM-s',
      ),
    ),
    _SectionItem(
      title: 'Who to Notify',
      icon: Icons.notifications,
      color: Color(0xFF3A8D5A),
      route: '/who-to-notify',
    ),
    _SectionItem(
      title: 'Running the Houses',
      icon: Icons.home,
      color: Color(0xFFE08A2C),
      config: SectionConfig(
        title: 'Running the Houses',
        orderIndex: 3,
        youtubeUrl: 'https://www.youtube.com/watch?v=jqpAgMxhx30',
      ),
    ),
    _SectionItem(
      title: 'Funeral Arrangements',
      icon: Icons.nature,
      color: Color(0xFF7B3FB0),
      config: SectionConfig(
        title: 'Funeral Arrangements',
        orderIndex: 4,
        youtubeUrl: 'https://www.youtube.com/watch?v=02T6xLNXEE0',
      ),
    ),
    _SectionItem(
      title: 'Cars',
      icon: Icons.directions_car,
      color: Color(0xFF2B6E8F),
      config: SectionConfig(
        title: 'Cars',
        orderIndex: 5,
        youtubeUrl: 'https://www.youtube.com/watch?v=rbgiJu7YFvo',
      ),
    ),
    _SectionItem(
      title: 'Confirmation',
      icon: Icons.verified,
      color: Color(0xFF2B8F6E),
      config: SectionConfig(
        title: 'Confirmation',
        orderIndex: 6,
        youtubeUrl: 'https://www.youtube.com/watch?v=lHzhH_tJ7ak',
      ),
    ),
    _SectionItem(
      title: "Kieren's Jukebox",
      icon: Icons.music_note,
      color: Color(0xFFC44B8A),
      config: SectionConfig(
        title: "Kieren's Jukebox",
        orderIndex: 7,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UnderCroft'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
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
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: _sections.length,
          itemBuilder: (context, index) {
            final section = _sections[index];
            return _SectionCard(section: section);
          },
        ),
      ),
    );
  }
}

class _SectionItem {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  final SectionConfig? config;

  const _SectionItem({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
    this.config,
  });
}

class _SectionCard extends StatelessWidget {
  final _SectionItem section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (section.route != null) {
            context.push(section.route!);
          } else if (section.config != null) {
            context.push('/section', extra: section.config);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: section.color, size: 24),
              ),
              const Spacer(),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2E),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
