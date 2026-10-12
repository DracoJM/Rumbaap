import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../theme/night_neutrals.dart';
import '../../reservations/data/demo_reservation_store.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/presentation/admin/admin_labels.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../session/demo_identities.dart';
import '../../tickets/presentation/ticket_widgets.dart';
import '../../venues/venue_config.dart';
import '../data/demo_bar_store.dart';
import '../domain/bar.dart';

String barErrorLabel(BarError e) => switch (e) {
  BarError.outsideNight =>
    'Ahora no hay una noche en curso: barra registra durante la noche.',
  BarError.emptySale => 'Añade al menos un producto.',
  BarError.paymentNotConfirmed =>
    'Confirma que recibiste el pago presencial completo antes de registrar.',
  BarError.unknownItem => 'Producto desconocido.',
  BarError.unknownAccount => 'No hay una cuenta con ese QR personal.',
  BarError.notFound => 'No se encontró la venta. No se hizo ningún cambio.',
  BarError.alreadyVoided => 'La venta ya está anulada.',
  BarError.missingReason => 'Escribe el motivo de la corrección.',
  BarError.alreadyAccepted => 'El consumo de esa reserva ya se aceptó.',
  BarError.onlyRemoveUnits =>
    'Una corrección solo puede quitar unidades. No se hizo ningún cambio.',
};

/// Cuenta ficticia a partir del código de su QR personal (lectura
/// simulada). Solo se usa para vincular el comprobante.
DemoIdentity? accountByPersonalQr(String raw) {
  final code = raw.trim().toUpperCase().replaceAll(' ', '');
  for (final i in DemoIdentities.of(DemoProfile.client)) {
    if (personalQrCode(i) == code) return i;
  }
  return null;
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
  String confirm,
) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const ValueKey('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('dialog-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom);

Text _title(BuildContext context, String text) => Text(
  text,
  style: Theme.of(
    context,
  ).textTheme.titleMedium?.copyWith(color: NightNeutrals.white),
);

TextStyle? _muted(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);

/// Líneas e historial de correcciones de una venta.
class SaleSummary extends StatelessWidget {
  const SaleSummary({super.key, required this.sale});

  final BarSale sale;

  @override
  Widget build(BuildContext context) {
    final muted = _muted(context);
    final voided = sale.status == BarSaleStatus.voided;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in sale.lines)
          Text(
            '${l.quantity} × ${l.name} · ${copLabel(l.total)}',
            style: voided
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        Text(
          voided ? 'Anulada · total 0 COP' : 'Total: ${copLabel(sale.total)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          'Registrada ${venueDateTimeLabel(sale.registeredAt)} · '
          '${actorLabel(sale.registeredBy)} · pago presencial (simulado)'
          '${sale.tableId == null ? '' : ' · Mesa ${sale.tableId}'}',
          style: muted,
        ),
        for (final c in sale.corrections)
          Text(
            '${c.kind == CorrectionKind.voided ? 'Anulada' : 'Ajustada'} '
            '${venueDateTimeLabel(c.at)} · ${actorLabel(c.actorId)} · '
            '${c.reason} · antes ${copLabel(c.previousTotal)}',
            style: muted?.copyWith(color: AppColors.amber),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Cliente

/// «Menú» del cliente: carta INFORMATIVA y sus comprobantes de consumo
/// (ventas de barra vinculadas a su QR personal). No se compra en la app.
class ClientMenu extends StatelessWidget {
  const ClientMenu({super.key, required this.store, required this.identity});

  final DemoBarStore store;
  final DemoIdentity identity;

  @override
  Widget build(BuildContext context) {
    final menu = VenueScope.of(context).menu;
    final categories = {for (final m in menu) m.category}.toList();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mine = store.book.salesOfAccount(identity.id)
          ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        return ListView(
          padding: _pad(context),
          children: [
            _title(context, 'Menú'),
            const SizedBox(height: 6),
            const NoticeBox(
              icon: Icons.info_outline_rounded,
              text:
                  'Menú informativo con precios de DEMOSTRACIÓN. Se pide y se '
                  'paga en barra; la app no cobra. Muestra tu QR personal en '
                  'barra para recibir el comprobante aquí.',
            ),
            for (final c in categories) ...[
              SectionLabel(c),
              for (final m in menu.where((m) => m.category == c))
                ListTile(
                  key: ValueKey('menu-${m.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.name),
                  trailing: Text(copLabel(m.demoPrice)),
                ),
            ],
            SectionLabel('Comprobantes de consumo', count: mine.length),
            if (mine.isEmpty)
              Text(
                'Todavía no hay compras de barra vinculadas a tu cuenta.',
                style: _muted(context),
              ),
            for (final s in mine)
              Card(
                key: ValueKey('receipt-${s.id}'),
                color: NightNeutrals.glass(0.06),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SaleSummary(sale: s),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------- Barra

/// Puesto de barra: registra una compra YA pagada en persona, vinculada si
/// se quiere a una reserva de la noche y a la cuenta por el QR personal.
class BarDesk extends StatefulWidget {
  const BarDesk({
    super.key,
    required this.store,
    required this.reservations,
    required this.identity,
  });

  final DemoBarStore store;
  final DemoReservationStore reservations;
  final DemoIdentity identity;

  @override
  State<BarDesk> createState() => _BarDeskState();
}

class _BarDeskState extends State<BarDesk> {
  final _qty = <String, int>{};
  final _qr = TextEditingController();
  String? _reservationId;
  bool _paid = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _qr.dispose();
    super.dispose();
  }

  List<Reservation> _tonight() {
    final night = widget.store.book.currentNight;
    if (night == null) return const [];
    return widget.reservations.book
        .forNight(night)
        .where(
          (r) =>
              r.status == ReservationStatus.confirmed ||
              r.status == ReservationStatus.seated,
        )
        .toList();
  }

  Future<void> _register() async {
    final qrText = _qr.text.trim();
    final account = qrText.isEmpty ? null : accountByPersonalQr(qrText);
    if (qrText.isNotEmpty && account == null) {
      setState(() {
        _ok = false;
        _message = barErrorLabel(BarError.unknownAccount);
      });
      return;
    }
    final total = _qty.entries.fold<int>(0, (t, e) {
      final item = VenueScope.of(context).menu.firstWhere((m) => m.id == e.key);
      return t + item.demoPrice * e.value;
    });
    final ok = await _confirm(
      context,
      '¿Registrar la venta?',
      'Total ${copLabel(total)}. Registra solo si ya recibiste el pago '
          'presencial completo. Después solo caja o administración pueden '
          'corregirla.',
      'Registrar',
    );
    if (!ok || !mounted) return;
    final reservation = _reservationId == null
        ? null
        : widget.reservations.book.byId(_reservationId!);
    try {
      final s = widget.store.perform(
        (b) => b.register(
          quantities: Map.of(_qty),
          paidInFull: _paid,
          actorId: widget.identity.id,
          reservationId: reservation?.id,
          tableId: reservation?.tableId,
          accountId: account?.id,
        ),
      );
      setState(() {
        _ok = true;
        _message =
            'Venta ${s.id} registrada: ${copLabel(s.total)}'
            '${account == null ? '' : ' · comprobante enviado a la cuenta'}'
            '${reservation == null ? '' : ' · mesa ${reservation.tableId}'}.';
        _qty.clear();
        _qr.clear();
        _reservationId = null;
        _paid = false;
      });
    } on BarException catch (e) {
      setState(() {
        _ok = false;
        _message = barErrorLabel(e.error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = VenueScope.of(context).menu;
    final tonight = _tonight();
    final venue = widget.reservations.venue;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final night = widget.store.book.currentNight;
        final mine =
            widget.store.book.sales.where((s) => s.night == night).toList()
              ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        return ListView(
          padding: _pad(context),
          children: [
            _title(context, 'Barra: registrar compra pagada'),
            const SizedBox(height: 6),
            Text(
              'Se registra después de recibir el pago presencial completo. La '
              'app no cobra (pago simulado).',
              style: _muted(context),
            ),
            if (night == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: NoticeBox(
                  icon: Icons.schedule_rounded,
                  color: AppColors.amber,
                  text: 'No hay una noche en curso: no se registran ventas.',
                ),
              ),
            for (final m in menu)
              Row(
                children: [
                  Expanded(child: Text('${m.name} · ${copLabel(m.demoPrice)}')),
                  IconButton(
                    tooltip: 'Quitar ${m.name}',
                    onPressed: (_qty[m.id] ?? 0) > 0
                        ? () =>
                              setState(() => _qty[m.id] = (_qty[m.id] ?? 0) - 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text('${_qty[m.id] ?? 0}', key: ValueKey('bar-qty-${m.id}')),
                  IconButton(
                    key: ValueKey('bar-add-${m.id}'),
                    tooltip: 'Añadir ${m.name}',
                    onPressed: () =>
                        setState(() => _qty[m.id] = (_qty[m.id] ?? 0) + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: const ValueKey('bar-reservation'),
              initialValue: _reservationId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mesa con reserva (opcional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin mesa'),
                ),
                for (final r in tonight)
                  DropdownMenuItem<String?>(
                    value: r.id,
                    child: Text('${r.tableIn(venue).displayName} · ${r.id}'),
                  ),
              ],
              onChanged: (v) => setState(() => _reservationId = v),
            ),
            TextField(
              key: const ValueKey('bar-qr'),
              controller: _qr,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText:
                    'QR personal del cliente (opcional, lectura simulada)',
                hintText: 'QRP-…',
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('bar-paid'),
              contentPadding: EdgeInsets.zero,
              value: _paid,
              onChanged: (v) => setState(() => _paid = v ?? false),
              title: const Text('Pago presencial completo recibido'),
            ),
            FilledButton.icon(
              key: const ValueKey('bar-register'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: night == null || _qty.values.every((q) => q <= 0)
                  ? null
                  : _register,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Registrar venta pagada'),
            ),
            if (_message case final m?)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: NoticeBox(
                  key: const ValueKey('bar-result'),
                  icon: _ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: _ok ? const Color(0xFF7FE3B5) : AppColors.amber,
                  text: m,
                ),
              ),
            SectionLabel('Ventas de esta noche', count: mine.length),
            for (final s in mine)
              Card(
                key: ValueKey('bar-sale-${s.id}'),
                color: NightNeutrals.glass(0.06),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SaleSummary(sale: s),
                ),
              ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------- Correcciones (caja/admin)

/// Ventas del local para corregir (caja y administración). Cada corrección
/// pide motivo y confirmación, y deja lo que había.
class BarCorrections extends StatelessWidget {
  const BarCorrections({
    super.key,
    required this.store,
    required this.identity,
    this.showAcceptances = false,
  });

  final DemoBarStore store;
  final DemoIdentity identity;
  final bool showAcceptances;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sales = store.book.sales
          ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        final active = sales.where((s) => s.status == BarSaleStatus.active);
        final acceptances = store.book.acceptances;
        return ListView(
          padding: _pad(context),
          children: [
            _title(context, 'Pedidos de barra'),
            const SizedBox(height: 6),
            Text(
              '${sales.length} ${sales.length == 1 ? 'venta' : 'ventas'} · ${copLabel(active.fold(0, (t, s) => t + s.total))} '
              'vigentes (importes de demostración; pago presencial simulado).',
              key: const ValueKey('bar-admin-summary'),
              style: _muted(context),
            ),
            if (sales.isEmpty)
              const NoticeBox(
                icon: Icons.inbox_outlined,
                text: 'Todavía no hay ventas de barra.',
              ),
            for (final s in sales)
              Card(
                key: ValueKey('bar-correct-${s.id}'),
                color: NightNeutrals.glass(0.06),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BarSalePage(
                        store: store,
                        identity: identity,
                        saleId: s.id,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Venta ${s.id} · ${s.night.shortLabel}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SaleSummary(sale: s),
                      ],
                    ),
                  ),
                ),
              ),
            if (showAcceptances) ...[
              SectionLabel('Consumos aceptados', count: acceptances.length),
              for (final a in acceptances)
                Text(
                  'Mesa ${a.tableId} · ${a.reservationId} · '
                  '${venueDateTimeLabel(a.at)} · ${actorLabel(a.acceptedBy)} · '
                  'vio ${copLabel(a.totalSeen)}',
                  style: _muted(context),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Ficha de una venta con sus correcciones.
class BarSalePage extends StatelessWidget {
  const BarSalePage({
    super.key,
    required this.store,
    required this.identity,
    required this.saleId,
  });

  final DemoBarStore store;
  final DemoIdentity identity;
  final String saleId;

  Future<String?> _reason(BuildContext context, String title) =>
      showDialog<String>(
        context: context,
        builder: (context) => _ReasonDialog(title: title),
      );

  Future<void> _apply(
    BuildContext context,
    BarSale before,
    BarSale Function(String reason) op,
    String title,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _reason(context, title);
    if (reason == null) return;
    // H1: la venta debe seguir igual que al abrir la corrección.
    final now = store.book.saleById(before.id);
    if (now == null ||
        now.status != before.status ||
        now.corrections.length != before.corrections.length) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La venta cambió mientras decidías. No se hizo ningún cambio.',
          ),
        ),
      );
      return;
    }
    try {
      store.perform((_) => op(reason));
    } on BarException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(barErrorLabel(e.error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Venta de barra')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.book.saleById(saleId);
          if (s == null) return const Center(child: Text('No encontrada.'));
          return ListView(
            key: ValueKey('bar-sale-page-${s.id}'),
            padding: _pad(context),
            children: [
              _title(context, 'Venta ${s.id}'),
              const SizedBox(height: 8),
              SaleSummary(sale: s),
              const SizedBox(height: 14),
              if (s.status == BarSaleStatus.active) ...[
                for (final l in s.lines.where((l) => l.quantity > 1))
                  OutlinedButton(
                    key: ValueKey('bar-minus-${l.itemId}'),
                    onPressed: () => _apply(
                      context,
                      s,
                      (reason) => store.book.adjust(
                        s.id,
                        quantities: {
                          for (final x in s.lines)
                            x.itemId: x.itemId == l.itemId
                                ? x.quantity - 1
                                : x.quantity,
                        },
                        actorId: identity.id,
                        reason: reason,
                      ),
                      'Quitar 1 × ${l.name}',
                    ),
                    child: Text('Quitar 1 × ${l.name}'),
                  ),
                const SizedBox(height: 6),
                OutlinedButton(
                  key: const ValueKey('bar-void'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: () => _apply(
                    context,
                    s,
                    (reason) => store.book.voidSale(
                      s.id,
                      actorId: identity.id,
                      reason: reason,
                    ),
                    'Anular venta ${s.id}',
                  ),
                  child: const Text('Anular venta'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------- Mesero

/// Consumo de reservas para el mesero: consulta lo registrado por barra en
/// cada mesa reservada de la noche y acepta el consumo A MANO. La suma no
/// declara nada cumplido.
class WaiterConsumption extends StatelessWidget {
  const WaiterConsumption({
    super.key,
    required this.bar,
    required this.reservations,
    required this.identity,
  });

  final DemoBarStore bar;
  final DemoReservationStore reservations;
  final DemoIdentity identity;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([bar, reservations]),
      builder: (context, _) {
        final night = bar.book.currentNight;
        final venue = reservations.venue;
        final list = night == null
            ? const <Reservation>[]
            : reservations.book
                  .forNight(night)
                  .where(
                    (r) =>
                        r.status == ReservationStatus.confirmed ||
                        r.status == ReservationStatus.seated,
                  )
                  .toList();
        return ListView(
          padding: _pad(context),
          children: [
            _title(context, 'Consumo de mesas reservadas'),
            const SizedBox(height: 6),
            Text(
              'Consulta lo registrado por barra y acepta el consumo con el '
              'titular. La suma es informativa: aceptar es una decisión tuya.',
              style: _muted(context),
            ),
            if (night == null)
              const NoticeBox(
                icon: Icons.schedule_rounded,
                text: 'No hay una noche en curso.',
              ),
            for (final r in list)
              Card(
                key: ValueKey('consumption-${r.id}'),
                color: NightNeutrals.glass(0.06),
                child: ListTile(
                  minTileHeight: 56,
                  title: Text('${r.tableIn(venue).displayName} · ${r.id}'),
                  subtitle: Text(
                    bar.book.acceptanceFor(r.id) == null
                        ? 'Consumo sin aceptar'
                        : 'Consumo aceptado',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConsumptionPage(
                        bar: bar,
                        reservations: reservations,
                        identity: identity,
                        reservationId: r.id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ConsumptionPage extends StatefulWidget {
  const ConsumptionPage({
    super.key,
    required this.bar,
    required this.reservations,
    required this.identity,
    required this.reservationId,
  });

  final DemoBarStore bar;
  final DemoReservationStore reservations;
  final DemoIdentity identity;
  final String reservationId;

  @override
  State<ConsumptionPage> createState() => _ConsumptionPageState();
}

class _ConsumptionPageState extends State<ConsumptionPage> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = VenueScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consumo de la reserva')),
      body: ListenableBuilder(
        listenable: widget.bar,
        builder: (context, _) {
          final r = widget.reservations.book.byId(widget.reservationId);
          if (r == null) return const Center(child: Text('No encontrada.'));
          final table = r.tableIn(widget.reservations.venue);
          final sales = widget.bar.book.salesForReservation(r.id);
          final active = sales.where((s) => s.status == BarSaleStatus.active);
          final sum = active.fold<int>(0, (t, s) => t + s.total);
          final accepted = widget.bar.book.acceptanceFor(r.id);
          final terms = config.termsOf(table);
          // Se compara con lo que vio el mesero al aceptar, no por la hora:
          // cualquier venta nueva, ajustada o anulada después cuenta.
          final activeIds = {for (final s in active) s.id};
          final changedAfter =
              accepted != null &&
              (sum != accepted.totalSeen ||
                  activeIds.length != accepted.saleIds.length ||
                  !activeIds.containsAll(accepted.saleIds));
          return ListView(
            key: ValueKey('consumption-page-${r.id}'),
            padding: _pad(context),
            children: [
              _title(context, '${table.displayName} · ${r.holderName}'),
              const SizedBox(height: 6),
              for (final c in terms.conditions)
                Text('· $c', style: _muted(context)),
              SectionLabel('Ventas de barra de esta mesa', count: sales.length),
              for (final s in sales)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SaleSummary(sale: s),
                ),
              Text(
                'Suma de ventas vigentes: ${copLabel(sum)} (informativa)',
                key: const ValueKey('consumption-sum'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (accepted != null) ...[
                NoticeBox(
                  key: const ValueKey('consumption-accepted'),
                  icon: Icons.verified_outlined,
                  text:
                      'Consumo aceptado ${venueDateTimeLabel(accepted.at)} por '
                      '${actorLabel(accepted.acceptedBy)}. Vio '
                      '${copLabel(accepted.totalSeen)}'
                      '${accepted.note == null ? '' : ' · ${accepted.note}'}.',
                ),
                if (changedAfter)
                  NoticeBox(
                    key: const ValueKey('consumption-changed'),
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.amber,
                    text:
                        'Las ventas de barra de esta mesa cambiaron después de '
                        'la aceptación: ahora suman ${copLabel(sum)}.',
                  ),
              ] else ...[
                TextField(
                  key: const ValueKey('consumption-note'),
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('consumption-accept'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await _confirm(
                      context,
                      '¿Aceptar el consumo?',
                      'Registra que revisaste el consumo de '
                          '${table.displayName} con lo que hay en barra '
                          '(${copLabel(sum)}). Es una aceptación manual.',
                      'Aceptar consumo',
                    );
                    if (!ok) return;
                    try {
                      widget.bar.perform(
                        (b) => b.acceptConsumption(
                          reservationId: r.id,
                          tableId: r.tableId,
                          night: r.night,
                          actorId: widget.identity.id,
                          note: _note.text,
                        ),
                      );
                    } on BarException catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(barErrorLabel(e.error))),
                      );
                    }
                  },
                  child: const Text('Aceptar consumo'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Pide el motivo de una corrección. Es dueño de su campo de texto: lo
/// libera al desaparecer, no antes (la animación de cierre aún lo usa).
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('bar-reason'),
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Motivo'),
      ),
      actions: [
        TextButton(
          key: const ValueKey('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('dialog-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
