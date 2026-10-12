import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../theme/night_neutrals.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../session/demo_identities.dart';
import '../domain/ticket.dart';

/// Importe en COP con separador de miles: «50.000 COP».
String copLabel(int amount) {
  final digits = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '$buf COP';
}

/// Credencial en grupos de 4 para leerla y dictarla: «SG2A KM7Q 9XPT».
String credentialLabel(String code) => [
  for (var i = 0; i < code.length; i += 4)
    code.substring(i, (i + 4).clamp(0, code.length)),
].join(' ');

/// Nombre de quien hizo una operación (identidad ficticia) o su ID.
String actorLabel(String actorId) =>
    DemoIdentities.byId(actorId)?.name ?? actorId;

extension TicketChannelLabels on TicketChannel {
  String get label => switch (this) {
    TicketChannel.app => 'App',
    TicketChannel.promoter => 'Promotor',
    TicketChannel.courtesy => 'Cortesía',
  };
}

extension PaymentLabels on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.pending => 'Pendiente de pago',
    PaymentStatus.paidSimulated => 'Pago simulado',
    PaymentStatus.verifiedByPromoter => 'Pago comprobado por el promotor',
    PaymentStatus.courtesy => 'Cortesía autorizada (sin pago)',
  };
}

extension TicketLabels on Ticket {
  /// Fase visible: pago, derecho, primer ingreso y canje.
  String get phaseLabel => switch (status) {
    TicketStatus.pendingPayment => 'Pendiente de pago',
    TicketStatus.active when firstEntryAt != null =>
      'Ingreso registrado · pendiente de canje',
    TicketStatus.active => 'Vigente · sin ingreso',
    TicketStatus.redeemed => 'Canjeada · No canjeable',
    TicketStatus.voided => 'Anulada',
  };

  IconData get statusIcon => switch (status) {
    TicketStatus.pendingPayment => Icons.payments_outlined,
    TicketStatus.active when firstEntryAt != null => Icons.login_rounded,
    TicketStatus.active => Icons.confirmation_number_outlined,
    TicketStatus.redeemed => Icons.verified_outlined,
    TicketStatus.voided => Icons.block_rounded,
  };

  Color get statusColor => switch (status) {
    TicketStatus.pendingPayment => AppColors.amber,
    TicketStatus.active => const Color(0xFF7FE3B5),
    TicketStatus.redeemed => const Color(0xFF9CC2FF),
    TicketStatus.voided => AppColors.textMuted,
  };

  String get circuitLabel => switch (channel) {
    TicketChannel.promoter =>
      'Manilla: del lote físico del promotor (su circuito).',
    _ => 'Manilla: se canjea en taquilla.',
  };

  String? get requestLabel {
    final r = request;
    if (r == null) return null;
    final what = r.type == TicketRequestType.refund
        ? 'Devolución'
        : 'Cambio a ${r.targetNight?.label.toLowerCase()}';
    return switch (r.status) {
      TicketRequestStatus.requested =>
        '$what solicitada · pendiente de la administración',
      TicketRequestStatus.authorized =>
        r.type == TicketRequestType.refund
            ? 'Devolución autorizada · dinero aún no devuelto (se hace '
                  'fuera de la app)'
            : '$what autorizado',
      TicketRequestStatus.rejected => '$what rechazada por la administración',
      TicketRequestStatus.refundRecorded =>
        'Devolución efectuada (registrada; hecha fuera de la app)',
    };
  }
}

String ticketEventLabel(TicketEventType type) => switch (type) {
  TicketEventType.sold => 'Venta creada (sin pago)',
  TicketEventType.paymentSimulated => 'Pago simulado: derecho activo',
  TicketEventType.paymentVerified =>
    'Pago comprobado por el promotor: derecho activo',
  TicketEventType.courtesyAuthorized => 'Cortesía autorizada: derecho activo',
  TicketEventType.credentialIssued => 'Credencial emitida',
  TicketEventType.credentialRetired => 'Credencial retirada (no se recicla)',
  TicketEventType.doorChecked => 'Consulta en puerta',
  TicketEventType.firstEntryRecorded => 'Primer ingreso registrado',
  TicketEventType.redeemed => 'Canje: manilla entregada',
  TicketEventType.rejected => 'Lectura rechazada (incidencia)',
  TicketEventType.refundRequested => 'Devolución solicitada',
  TicketEventType.changeRequested => 'Cambio de noche solicitado',
  TicketEventType.requestRejected => 'Solicitud rechazada',
  TicketEventType.refundAuthorized => 'Devolución autorizada: entrada anulada',
  TicketEventType.refundRecorded =>
    'Devolución efectuada (registrada; fuera de la app)',
  TicketEventType.nightChanged => 'Noche cambiada',
};

String rejectReasonLabel(RejectReason r) => switch (r) {
  RejectReason.notFound => 'No existe una entrada con esa credencial.',
  RejectReason.retiredCredential =>
    'Credencial retirada: se reemplazó o se anuló. Pide la vigente.',
  RejectReason.otherVenue => 'La credencial es de otro local.',
  RejectReason.otherNight => 'La entrada es de otra noche.',
  RejectReason.outsideNight =>
    'Ahora no hay una noche en curso (8:30 p. m. – 3:00 a. m., hora de '
        'Colombia).',
  RejectReason.unpaid => 'La entrada no está pagada.',
  RejectReason.voided => 'La entrada está anulada.',
  RejectReason.redeemed =>
    'No canjeable: ya se entregó la manilla. El reingreso es con la manilla.',
  RejectReason.wrongCircuit =>
    'Otro circuito: la manilla de esta entrada no se entrega aquí.',
  RejectReason.vipPendingApproval =>
    'Cortesía VIP sin aprobación de la reserva y verificación del prepago '
        'acreditadas: requiere revisión de la administración.',
};

String ticketErrorLabel(TicketError e) => switch (e) {
  TicketError.nightEnded => 'Esa noche ya terminó. No se hizo ningún cambio.',
  TicketError.noPrice => 'No hay precio de demostración para esa noche.',
  TicketError.invalidQuantity => 'Elige al menos una entrada.',
  TicketError.invalidHolder => 'Completa el nombre (y el motivo, si aplica).',
  TicketError.notFound => 'No se encontró. No se hizo ningún cambio.',
  TicketError.wrongChannel => 'Esa operación no aplica a este circuito.',
  TicketError.alreadyPaid => 'Esa venta ya está pagada.',
  TicketError.notEligible =>
    'La entrada ya no admite esta acción. No se hizo ningún cambio.',
  TicketError.sameNight => 'Elige una noche distinta.',
  TicketError.noOpenRequest =>
    'La solicitud ya cambió. No se hizo ningún cambio.',
};

/// QR REAL de la credencial vigente de una entrada.
///
/// Codifica SOLO la credencial opaca: identidad y estado los consulta el
/// personal en `TicketGateway`, nunca salen del QR. Negro sobre blanco
/// opaco, con un margen de 4 módulos (zona de silencio) y un tamaño que se
/// adapta al ancho disponible.
class CredentialQrView extends StatelessWidget {
  const CredentialQrView({
    super.key,
    required this.code,
    required this.caption,
    this.maxSize = 260,
  });

  final String code;
  final String caption;
  final double maxSize;

  /// Corrección de errores media: tolera algo de brillo o suciedad en la
  /// pantalla y una credencial de 12 caracteres sigue en la versión 1.
  static const errorCorrectionLevel = QrErrorCorrectLevel.M;

  /// Módulos de margen blanco a cada lado.
  static const quietZoneModules = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qr = QrValidator.validate(
      data: code,
      errorCorrectionLevel: errorCorrectionLevel,
    ).qrCode!;
    return Semantics(
      label:
          '${caption.endsWith('.') ? caption : '$caption.'} Credencial '
          '${credentialLabel(code)}',
      excludeSemantics: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth.clamp(0.0, maxSize);
              final module = side / (qr.moduleCount + 2 * quietZoneModules);
              return RepaintBoundary(
                key: const ValueKey('credential-qr'),
                child: Container(
                  width: side,
                  height: side,
                  padding: EdgeInsets.all(module * quietZoneModules),
                  // Blanco opaco y esquinas rectas en el área del código: el
                  // vidrio de la tarjeta queda fuera.
                  color: Colors.white,
                  child: QrImageView.withQr(
                    qr: qr,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SelectableText(
            credentialLabel(code),
            key: const ValueKey('credential-text'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.4,
            ),
          ),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Historial de una entrada: qué pasó, cuándo y quién lo hizo.
class TicketHistory extends StatelessWidget {
  const TicketHistory({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in ticket.history.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: e.type == TicketEventType.rejected
                        ? AppColors.amber
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticketEventLabel(e.type)),
                      Text(
                        '${venueDateTimeLabel(e.at)} · ${actorLabel(e.actorId)}'
                        '${e.note == null ? '' : ' · ${e.note}'}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de una entrada en las listas.
class TicketTile extends StatelessWidget {
  const TicketTile({super.key, required this.ticket, this.onTap, this.extra});

  final Ticket ticket;
  final VoidCallback? onTap;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    return Card(
      key: ValueKey('ticket-${t.id}'),
      color: NightNeutrals.glass(0.06),
      child: ListTile(
        minTileHeight: 56,
        onTap: onTap,
        leading: Icon(t.statusIcon, color: t.statusColor),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        title: Text('Entrada ${t.id} · ${t.night.shortLabel}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.phaseLabel),
            if (extra case final e?) Text(e, style: muted),
            if (t.requestLabel case final r?) Text(r, style: muted),
          ],
        ),
      ),
    );
  }
}
