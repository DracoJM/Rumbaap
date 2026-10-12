import 'package:flutter/material.dart';

import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import '../features/reservations/presentation/admin/admin_page.dart';
import '../features/reservations/presentation/guest/guest_home_page.dart';
import '../features/reservations/presentation/staff/staff_page.dart';
import '../features/bar/data/demo_bar_store.dart';
import '../features/dashboard/data/demo_goal_store.dart';
import '../features/session/demo_identities.dart';
import '../features/tickets/data/demo_ticket_store.dart';
import '../features/venues/venue_config.dart';
import '../theme/app_background.dart';
import '../theme/venue_theme.dart';
import 'app_theme.dart';
import 'persistence/demo_bootstrap.dart';

/// Entrada del prototipo: elegir una identidad ficticia por perfil.
///
/// Cada identidad abre su propia navegación. Volver aquí (atrás o «Cambiar
/// identidad») descarta la pila de esa sesión, con sus formularios y los
/// titulares que mostraba; las reservas siguen en el almacén único del local.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.tickets,
    required this.bar,
    this.goals,
    this.clock = systemClock,
    this.onResetDemo,
  });

  /// Reinicia la demo (borra solo sus datos guardados); `null` si los
  /// datos no se guardan.

  final DemoReservationStore store;

  /// Entradas del local, compartidas por todos los perfiles.
  final DemoTicketStore tickets;

  /// Ventas de barra del local, compartidas por todos los perfiles.
  final DemoBarStore bar;

  /// Metas del local; solo las usa la administración.
  final DemoGoalStore? goals;
  final Future<void> Function()? onResetDemo;
  final Clock clock;

  void _enter(BuildContext context, DemoIdentity identity) {
    final page = switch (identity.profile) {
      DemoProfile.admin => AdminPage(
        store: store,
        clock: clock,
        identity: identity,
        tickets: tickets,
        bar: bar,
        goals: goals,
      ),
      DemoProfile.staff => StaffPage(
        store: store,
        clock: clock,
        identity: identity,
        tickets: tickets,
        bar: bar,
      ),
      DemoProfile.client || DemoProfile.promoter => GuestHomePage.withStore(
        store: store,
        clock: clock,
        identity: identity,
        tickets: tickets,
        bar: bar,
      ),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final venue = VenueTheme.of(context);
    final config = VenueScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter(MediaQuery.sizeOf(context).width),
                AppSpace.lg,
                AppSpace.gutter(MediaQuery.sizeOf(context).width),
                AppSpace.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rumbaap',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge,
                    ),
                    Text(
                      config.venue.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: venue.vip,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Elige con quién entrar',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prototipo con identidades de demostración.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final profile in DemoProfile.values) ...[
                      _ProfileGroup(
                        profile: profile,
                        onEnter: (identity) => _enter(context, identity),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    const _DemoNotice(),
                    if (onResetDemo case final reset?) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const ValueKey('demo-reset'),
                        onPressed: () => confirmDemoReset(context, reset),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reiniciar demostración'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.profile, required this.onEnter});

  final DemoProfile profile;
  final ValueChanged<DemoIdentity> onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenueTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(profile.label, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 2),
          Text(profile.summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          for (final identity in DemoIdentities.of(profile))
            ListTile(
              key: ValueKey('identity-${identity.id}'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 52,
              leading: CircleAvatar(
                backgroundColor: venue.primary.withValues(alpha: 0.2),
                child: Icon(_iconOf(profile), color: AppColors.text),
              ),
              title: Text(identity.name),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => onEnter(identity),
            ),
        ],
      ),
    );
  }

  static IconData _iconOf(DemoProfile p) => switch (p) {
    DemoProfile.client => Icons.person_outline_rounded,
    DemoProfile.promoter => Icons.campaign_outlined,
    DemoProfile.admin => Icons.admin_panel_settings_outlined,
    DemoProfile.staff => Icons.room_service_outlined,
  };
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demostración: datos ficticios guardados solo en este '
              'teléfono; se conservan al cerrar la app hasta que reinicies '
              'la demostración. Las sesiones son ficticias, sin contraseñas ni '
              'autenticación real; la cédula no es una contraseña.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
