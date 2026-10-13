import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({super.key});

  static const List<_SectionItem> _sections = [
    _SectionItem(
      title: 'What to Do First',
      icon: Icons.flag,
      color: Color(0xFFD64545),
    ),
    _SectionItem(
      title: 'Legal Documents',
      icon: Icons.description,
      color: Color(0xFF2D5FCD),
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
    ),
    _SectionItem(
      title: 'Funeral Arrangements',
      icon: Icons.nature,
      color: Color(0xFF7B3FB0),
    ),
    _SectionItem(
      title: 'Cars',
      icon: Icons.directions_car,
      color: Color(0xFF2B6E8F),
    ),
    _SectionItem(
      title: 'Confirmation',
      icon: Icons.verified,
      color: Color(0xFF2B8F6E),
    ),
    _SectionItem(
      title: "Kieren's Jukebox",
      icon: Icons.music_note,
      color: Color(0xFFC44B8A),
      route: '/kierens-jukebox',
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
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
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

  const _SectionItem({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
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
          } else {
            // Navigate via path parameter so the section survives a
            // browser refresh (go_router's `extra` is lost on reload).
            context.push('/section/${Uri.encodeComponent(section.title)}');
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
