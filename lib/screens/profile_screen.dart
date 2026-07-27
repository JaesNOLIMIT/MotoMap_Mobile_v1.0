import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'route_detail_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Row(
            children: [
              const MotoMapLogo(compact: true),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Center(
            child: RiderAvatar(
              initials: 'AR',
              size: 92,
              color: Color(0xFF54463D),
              verified: true,
            ),
          ),
          const SizedBox(height: 15),
          Center(child: Text('Alex Rider', style: MotoMapText.headlineMd)),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '@alexrides · Quezon City',
              style: TextStyle(
                color: MotoMapColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: AppPill(
              label: 'BMW R1250GS',
              icon: Icons.two_wheeler_rounded,
              compact: true,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 39,
                child: FilledButton.icon(
                  onPressed: () => showAppMessage(context, 'Edit profile'),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit profile'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () =>
                    showAppMessage(context, 'Profile link copied.'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: _ProfileStat(value: '12,450', label: 'KM RIDDEN'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ProfileStat(value: '342', label: 'HOURS'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ProfileStat(value: '28', label: 'ROUTES'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _SocialStat(value: '1,284', label: 'Followers'),
                SizedBox(height: 28, child: VerticalDivider()),
                _SocialStat(value: '386', label: 'Following'),
                SizedBox(height: 28, child: VerticalDivider()),
                _SocialStat(value: '14', label: 'Clubs'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            'Recent rides',
            action: 'View all',
            onAction: () => showAppMessage(context, 'Full ride history'),
          ),
          const SizedBox(height: 12),
          _ProfileRide(
            title: 'Marilaque Sunrise Loop',
            date: '27 July · 68 km',
            variant: 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RouteDetailScreen(
                  title: 'Marilaque Sunrise Loop',
                  distance: '68 km',
                  duration: '2h 14m',
                  elevation: '920 m',
                  variant: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileRide(
            title: 'Tagaytay Backroads',
            date: '20 July · 92 km',
            variant: 2,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RouteDetailScreen(
                  title: 'Tagaytay Backroads',
                  distance: '92 km',
                  duration: '3h 06m',
                  elevation: '740 m',
                  variant: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Badges'),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _Badge(
                  icon: Icons.explore_rounded,
                  label: 'Explorer',
                  color: MotoMapColors.info,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _Badge(
                  icon: Icons.wb_twilight_rounded,
                  label: 'Early bird',
                  color: MotoMapColors.warning,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _Badge(
                  icon: Icons.route_rounded,
                  label: '10K club',
                  color: MotoMapColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      radius: 15,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
        ],
      ),
    );
  }
}

class _SocialStat extends StatelessWidget {
  const _SocialStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(
            color: MotoMapColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _ProfileRide extends StatelessWidget {
  const _ProfileRide({
    required this.title,
    required this.date,
    required this.variant,
    required this.onTap,
  });

  final String title;
  final String date;
  final int variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: RouteArtwork(height: 86, variant: variant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  date,
                  style: const TextStyle(
                    color: MotoMapColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),
                const TinyStat(
                  icon: Icons.favorite_rounded,
                  label: '128',
                  color: MotoMapColors.primary,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: MotoMapColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      radius: 15,
      child: Column(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
