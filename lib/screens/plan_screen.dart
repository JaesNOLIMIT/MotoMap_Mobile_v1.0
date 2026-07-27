import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'route_detail_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({required this.onOpenRides, super.key});

  final VoidCallback onOpenRides;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final promptController = TextEditingController();
  int routeType = 0;
  bool generated = false;
  bool generating = false;

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => generating = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      generating = false;
      generated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan a ride', style: MotoMapText.headlineLg),
                    const SizedBox(height: 5),
                    Text(
                      'From an idea to a road-ready route.',
                      style: MotoMapText.bodyMd.copyWith(
                        color: MotoMapColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: widget.onOpenRides,
                tooltip: 'Saved plans',
                icon: const Icon(Icons.bookmark_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            borderColor: MotoMapColors.primary.withValues(alpha: 0.28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: MotoMapColors.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 19,
                        color: MotoMapColors.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Route Planner',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Describe the ride you want',
                            style: TextStyle(
                              fontSize: 10,
                              color: MotoMapColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppPill(label: 'BETA', compact: true),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promptController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. A relaxed 3-hour morning loop from Quezon City with mountain views and a good coffee stop.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: generating ? null : _generate,
                    icon: generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MotoMapColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: Text(
                      generating ? 'Mapping your ride…' : 'Generate route',
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: generated
                ? Padding(
                    key: const ValueKey('generated'),
                    padding: const EdgeInsets.only(top: 14),
                    child: _GeneratedRoute(),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            'Build it yourself',
            subtitle: 'Choose a destination and tune the route',
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              children: [
                _LocationField(
                  icon: Icons.my_location_rounded,
                  label: 'START',
                  value: 'Current location',
                  color: MotoMapColors.success,
                  onTap: () =>
                      showAppMessage(context, 'Using your current location.'),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 19),
                  child: Row(
                    children: [
                      Container(
                        width: 1,
                        height: 24,
                        color: MotoMapColors.outlineVariant,
                      ),
                      const Expanded(child: Divider(indent: 14)),
                    ],
                  ),
                ),
                _LocationField(
                  icon: Icons.location_on_rounded,
                  label: 'DESTINATION',
                  value: 'Where do you want to go?',
                  color: MotoMapColors.primary,
                  onTap: () =>
                      showAppMessage(context, 'Destination search opened.'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PreferenceButton(
                        icon: Icons.swap_calls_rounded,
                        label: 'Round trip',
                        value: 'On',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PreferenceButton(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '2–3 hours',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: const ['Fastest', 'Scenic', 'Curvy'].length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => AppPill(
                      label: const ['Fastest', 'Scenic', 'Curvy'][index],
                      selected: routeType == index,
                      onTap: () => setState(() => routeType = index),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Preview route',
                  icon: Icons.map_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RouteDetailScreen(
                        title: 'Custom Weekend Loop',
                        distance: '108 km',
                        duration: '2h 55m',
                        elevation: '780 m',
                        variant: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Quick ideas'),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _IdeaCard(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Sunrise loop',
                  detail: '2 hours · Scenic',
                  color: Color(0xFF3D514A),
                ),
                SizedBox(width: 10),
                _IdeaCard(
                  icon: Icons.coffee_rounded,
                  title: 'Coffee run',
                  detail: '90 min · Relaxed',
                  color: Color(0xFF514337),
                ),
                SizedBox(width: 10),
                _IdeaCard(
                  icon: Icons.landscape_rounded,
                  title: 'Mountain day',
                  detail: 'Full day · Curvy',
                  color: Color(0xFF3B4556),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: const Color(0xFF14201B),
      borderColor: MotoMapColors.success.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: MotoMapColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                'Your route is ready',
                style: MotoMapText.labelCaps.copyWith(
                  color: MotoMapColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const RouteArtwork(height: 125, variant: 3),
          const SizedBox(height: 12),
          const Text(
            'Rizal Coffee Ridge Loop',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              TinyStat(icon: Icons.route_rounded, label: '104 km'),
              SizedBox(width: 14),
              TinyStat(icon: Icons.schedule_rounded, label: '2h 54m'),
              SizedBox(width: 14),
              TinyStat(icon: Icons.coffee_rounded, label: '2 stops'),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Review route',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RouteDetailScreen(
                  title: 'Rizal Coffee Ridge Loop',
                  distance: '104 km',
                  duration: '2h 54m',
                  elevation: '980 m',
                  variant: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MotoMapText.labelCaps.copyWith(fontSize: 8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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
      ),
    );
  }
}

class _PreferenceButton extends StatelessWidget {
  const _PreferenceButton({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MotoMapColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MotoMapColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: MotoMapColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: MotoMapColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => showAppMessage(context, '$title selected.'),
      color: color.withValues(alpha: 0.65),
      borderColor: color,
      child: SizedBox(
        width: 142,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MotoMapColors.primary),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 9,
                color: MotoMapColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
