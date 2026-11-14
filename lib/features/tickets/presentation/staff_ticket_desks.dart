import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../session/demo_identities.dart';
import '../data/demo_ticket_store.dart';
import '../domain/ticket.dart';
import 'credential_scanner.dart';
import 'ticket_widgets.dart';

/// Puesto de puerta (Seguridad) o de taquilla (Caja).
///
/// La credencial se lee con la cámara (botón del personal) o se escribe a
/// mano; las dos van por el mismo camino. Los datos de la persona salen del
/// registro, nunca de lo que diga una captura. Puerta: consultar no
/// registra nada; «Confirmar primer ingreso» lo registra una vez. Taquilla:
/// canjea por manilla una vez. Cada operación espera la respuesta y
/// distingue «consultando», éxito, rechazo y fallo de conexión.
class TicketDesk extends StatefulWidget {
  const TicketDesk.door({
    super.key,
    required this.store,
    required this.identity,
    this.scan = scanCredentialWithCamera,
  }) : boxOffice = false;

  const TicketDesk.boxOffice({
    super.key,
    required this.store,
    required this.identity,
    this.scan = scanCredentialWithCamera,
  }) : boxOffice = true;

  final DemoTicketStore store;
  final DemoIdentity identity;
  final bool boxOffice;

  /// Lectura con la cámara; las pruebas la sustituyen.
  final CredentialScan scan;

  @override
  State<TicketDesk> createState() => _TicketDeskState();
}

class _TicketDeskState extends State<TicketDesk> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _busy = false;
  bool _scanning = false;
  CheckResult? _result;
  String? _error;

  /// Identificador de la operación en curso: un reintento tras un fallo de
  /// conexión usa el mismo y no puede registrar dos veces.
  String? _requestId;
  String? _requestCode;

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String _idFor(String code) {
    if (_requestId == null || _requestCode != code) {
      _requestCode = code;
      _requestId =
          '${widget.identity.id}-${DateTime.now().microsecondsSinceEpoch}';
    }
    return _requestId!;
  }

  Future<void> _run(Future<CheckResult> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await op();
      if (!mounted) return;
      setState(() {
        _result = r;
        _requestId = null;
      });
    } on TicketGatewayUnavailable {
      if (mounted) {
        setState(
          () => _error =
              'Sin respuesta del servicio: no se sabe si quedó registrado. '
              'Reintenta; no se duplicará.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _consult() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    _requestId = null;
    await _run(() => widget.store.doorCheck(code, actorId: widget.identity.id));
  }

  Future<void> _confirmEntry() async {
    final code = _code.text.trim();
    await _run(
      () => widget.store.confirmFirstEntry(
        code,
        actorId: widget.identity.id,
        requestId: _idFor(code),
      ),
    );
  }

  /// Lee un QR y sigue el mismo camino que la escritura manual: en puerta,
  /// solo consulta (el ingreso se confirma aparte); en taquilla, pide la
  /// confirmación del canje.
  Future<void> _scan() async {
    if (_busy || _scanning) return;
    setState(() => _scanning = true);
    final ScanOutcome? outcome;
    try {
      outcome = await widget.scan(context);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    // La pantalla pudo cerrarse o cambiar de identidad mientras tanto.
    if (outcome == null || !mounted || _busy) return;
    // Pedir escribir a mano lleva el foco al campo; cancelar no lo mueve.
    if (outcome is ManualEntryRequested) {
      _codeFocus.requestFocus();
      return;
    }
    final code = (outcome as ScannedCode).code;
    setState(() {
      _code.text = code;
      _result = null;
      _error = null;
    });
    await (widget.boxOffice ? _redeem() : _consult());
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Con texto al 200 % todo el diálogo se desplaza.
        scrollable: true,
        title: const Text('¿Canjear y entregar manilla?'),
        content: const Text(
          'Se registra una sola vez por entrada. Después la entrada queda «No '
          'canjeable». La manilla no es nominativa.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => widget.store.redeem(
        code,
        actorId: widget.identity.id,
        point: RedeemPoint.boxOffice,
        requestId: _idFor(code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = widget.boxOffice;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final r = _result;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          box ? 'Taquilla: canje de manillas' : 'Puerta: validar entradas',
          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 6),
        Text(
          box
              ? 'Canjea compras de la app y cortesías. Las ventas del promotor '
                    'se canjean con su lote. Una manilla por entrada.'
              : 'Consultar no registra nada. Confirma el primer ingreso tras '
                    'comprobar a la persona: un QR compartido puede usarlo '
                    'otro portador primero. El reingreso es con la manilla.',
          style: muted,
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          key: ValueKey(box ? 'box-scan' : 'door-scan'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _busy || _scanning ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Leer QR con la cámara'),
        ),
        const SizedBox(height: 6),
        Text('Si la cámara no lee el código, escríbelo a mano.', style: muted),
        const SizedBox(height: 10),
        TextField(
          key: ValueKey(box ? 'box-code' : 'door-code'),
          controller: _code,
          focusNode: _codeFocus,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {
            _result = null;
            _error = null;
          }),
          onSubmitted: (_) => box ? _redeem() : _consult(),
          decoration: const InputDecoration(
            labelText: 'Credencial',
            helperText: 'Escribe o pega el ID de la credencial.',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: ValueKey(box ? 'box-redeem' : 'door-consult'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _busy ? null : (box ? _redeem : _consult),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(box ? Icons.watch_outlined : Icons.search_rounded),
          label: Text(
            _busy
                ? 'Consultando…'
                : box
                ? 'Canjear y entregar manilla'
                : 'Consultar credencial',
          ),
        ),
        if (_error case final e?) ...[
          const SizedBox(height: 12),
          NoticeBox(
            key: const ValueKey('desk-error'),
            icon: Icons.wifi_off_rounded,
            color: AppColors.danger,
            text: e,
          ),
        ],
        if (r != null && !_busy) ...[
          const SizedBox(height: 12),
          _ResultCard(result: r),
          if (!box && r.outcome == CheckOutcome.validNoEntry)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton.icon(
                key: const ValueKey('door-confirm-entry'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _confirmEntry,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Confirmar primer ingreso'),
              ),
            ),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = result.ticket;
    final (icon, color, title) = switch (result.outcome) {
      CheckOutcome.validNoEntry => (
        Icons.verified_user_outlined,
        const Color(0xFF7FE3B5),
        'Vigente para esta noche · sin ingreso',
      ),
      CheckOutcome.entryAlreadyRecorded => (
        Icons.info_outline_rounded,
        AppColors.amber,
        // La hora termina en «p. m.»: va entre paréntesis para no repetir
        // el punto.
        'Ingreso ya registrado'
            '${t?.firstEntryAt == null ? '' : ' (${venueTimeLabel(t!.firstEntryAt!)})'}'
            '. No se registra otro; taquilla aún puede canjear.',
      ),
      CheckOutcome.entryRecorded => (
        Icons.login_rounded,
        const Color(0xFF7FE3B5),
        'Primer ingreso registrado.',
      ),
      CheckOutcome.redeemedNow => (
        Icons.watch_outlined,
        const Color(0xFF9CC2FF),
        'Canje registrado: entrega la manilla.',
      ),
      CheckOutcome.rejected => (
        Icons.block_rounded,
        AppColors.danger,
        rejectReasonLabel(result.reason!),
      ),
    };
    final owner = DemoIdentities.byId(t?.ownerId);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    return Container(
      key: const ValueKey('desk-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('desk-result-title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (t != null) ...[
            const SizedBox(height: 8),
            Text('Datos del registro (no de la captura):', style: muted),
            Text(
              owner != null
                  ? '${owner.name} · cédula ${owner.idNumber ?? 'sin dato'}'
                  : '${t.holderName ?? 'Sin nombre'} · sin cédula en el '
                        'registro',
            ),
            Text(
              'Entrada ${t.id} · ${t.night.label} · ${t.channel.label} · '
              '${t.phaseLabel}',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}
