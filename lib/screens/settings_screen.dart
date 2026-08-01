import 'package:flutter/material.dart';

import '../models/legal_document.dart';
import '../services/auth_service.dart';
import '../services/elm327_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/legal_documents_sheet.dart';
import 'garage_flow.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool voice = true;
  bool weatherAlerts = true;
  bool emergencySharing = true;

  @override
  void initState() {
    super.initState();
    Elm327Service.instance.addListener(_elmChanged);
  }

  @override
  void dispose() {
    Elm327Service.instance.removeListener(_elmChanged);
    super.dispose();
  }

  void _elmChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final elm = Elm327Service.instance;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              const _SettingsSectionLabel('RIDE'),
              const SizedBox(height: 9),
              SurfaceCard(
                padding: EdgeInsets.zero,
                radius: 18,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.navigation_outlined,
                      title: 'Navigation',
                      detail: 'Scenic routing, avoid tolls',
                      onTap: () =>
                          showAppMessage(context, 'Navigation preferences'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.volume_up_outlined,
                      title: 'Voice guidance',
                      detail: 'Spoken turn instructions',
                      trailing: Switch(
                        value: voice,
                        onChanged: (value) => setState(() => voice = value),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.straighten_rounded,
                      title: 'Units',
                      detail: 'Kilometers · Celsius',
                      onTap: () => showAppMessage(context, 'Units selected'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SettingsSectionLabel('SAFETY'),
              const SizedBox(height: 9),
              SurfaceCard(
                padding: EdgeInsets.zero,
                radius: 18,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.shield_outlined,
                      title: 'Emergency sharing',
                      detail: 'Share live location while riding',
                      trailing: Switch(
                        value: emergencySharing,
                        onChanged: (value) =>
                            setState(() => emergencySharing = value),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.contacts_outlined,
                      title: 'Emergency contacts',
                      detail: '2 contacts configured',
                      onTap: () =>
                          showAppMessage(context, 'Emergency contacts'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.cloud_outlined,
                      title: 'Weather alerts',
                      detail: 'Warn before risky conditions',
                      trailing: Switch(
                        value: weatherAlerts,
                        onChanged: (value) =>
                            setState(() => weatherAlerts = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SettingsSectionLabel('MOTORCYCLE'),
              const SizedBox(height: 9),
              SurfaceCard(
                padding: EdgeInsets.zero,
                radius: 18,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: elm.isConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      title: 'Primary motorcycle',
                      detail: elm.motorcycle == null
                          ? 'N/A · No primary motorcycle selected'
                          : '${elm.motorcycle!.displayName} · ${elm.statusLabel}',
                      iconColor: elm.isConnected
                          ? MotoMapColors.success
                          : MotoMapColors.warning,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MotorcycleDetailScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.monitor_heart_outlined,
                      title: 'System diagnostics',
                      detail: elm.isConnected && elm.ecuAvailable
                          ? 'Live ECU data is available'
                          : 'N/A · No live ECU data',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SystemDiagnosticsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SettingsSectionLabel('ACCOUNT'),
              const SizedBox(height: 9),
              SurfaceCard(
                padding: EdgeInsets.zero,
                radius: 18,
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy & security',
                      detail: 'EULA, Terms, and Privacy Policy',
                      onTap: () => showLegalDocumentsSheet(
                        context,
                        initialType: LegalDocumentType.privacy,
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      detail: 'Rides, follows, comments',
                      onTap: () =>
                          showAppMessage(context, 'Notification preferences'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & support',
                      detail: 'FAQs and contact support',
                      onTap: () => showAppMessage(context, 'Help center'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MotoMapColors.error,
                  side: BorderSide(
                    color: MotoMapColors.error.withValues(alpha: 0.35),
                  ),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'MotoMap 1.0.0',
                  style: MotoMapText.labelCaps.copyWith(fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your saved rides will stay on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await AuthService.instance.signOut();
              } catch (_) {
                if (context.mounted) {
                  showAppMessage(context, 'Could not sign out. Try again.');
                }
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: MotoMapText.labelCaps.copyWith(
        color: MotoMapColors.primary,
        fontSize: 9,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? MotoMapColors.primary).withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? MotoMapColors.primary,
              ),
            ),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: MotoMapColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
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
