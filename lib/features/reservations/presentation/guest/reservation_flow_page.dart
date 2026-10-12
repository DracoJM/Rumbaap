import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../session/demo_identities.dart';
import '../../../venues/venue_config.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_book.dart';
import '../../domain/venue_table.dart';
import '../admin/admin_labels.dart';
import '../admin/admin_widgets.dart';
import '../birthday_widgets.dart';
import '../table_presentation.dart';

enum ReservationFlowResult { showMine }

enum _Step { form, summary, done, expired }

/// Trámite de reserva del cliente o del promotor (R13–R16).
///
/// - Mesa normal: llega con [reservationId], el trámite En proceso ya
///   iniciado al pulsar «Reservar esta mesa» (R14). Enviar lo confirma si
///   sigue activo; salir expresamente lo cancela tras confirmar (R15); pasar
///   a segundo plano no lo cancela ni reinicia el plazo.
/// - Mesa VIP: no hay solicitud hasta el envío final válido (R16).
class ReservationFlowPage extends StatefulWidget {
  const ReservationFlowPage({
    super.key,
    required this.store,
    required this.identity,
    required this.night,
    required this.table,
    this.reservationId,
    this.clock = systemClock,
  });

  final DemoReservationStore store;
  final DemoIdentity identity;
  final Night night;
  final VenueTable table;
  final String? reservationId;
  final Clock clock;

  @override
  State<ReservationFlowPage> createState() => _ReservationFlowPageState();
}

class _ReservationFlowPageState extends State<ReservationFlowPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _idNumber = TextEditingController();
  final _phone = TextEditingController();
  final _birthday = BirthdayDraft();
  _Step _step = _Step.form;
  bool _forOther = false;
  bool _sending = false;
  String? _error;
  Reservation? _result;
  Timer? _ticker;

  bool get _isClient => widget.identity.profile == DemoProfile.client;
  bool get _isNormal => !widget.table.isVip;

  /// Plazo del trámite normal, desde su inicio original (R14).
  DateTime? get _deadline {
    final id = widget.reservationId;
    if (id == null) return null;
    final r = widget.store.book.byId(id);
    return r?.createdAt.add(ReservationBook.inProcessTimeout);
  }

  /// Trámite normal todavía activo: salir lo cancela.
  bool get _activeNormal {
    final id = widget.reservationId;
    if (id == null || _step == _Step.done) return false;
    return widget.store.book.byId(id)?.status == ReservationStatus.inProcess;
  }

  @override
  void initState() {
    super.initState();
    if (_isNormal) {
      // Comprueba el plazo con el reloj del modelo, también al volver de
      // segundo plano: nada lo reinicia.
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkExpiry(),
      );
    }
  }

  void _checkExpiry() {
    final id = widget.reservationId;
    if (!mounted || id == null || _step == _Step.done) return;
    final status = widget.store.book.byId(id)?.status;
    if (status == ReservationStatus.expired && _step != _Step.expired) {
      setState(() => _step = _Step.expired);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _name.dispose();
    _idNumber.dispose();
    _phone.dispose();
    _birthday.dispose();
    super.dispose();
  }

  ReservationHolder get _holder {
    if (_isClient && !_forOther) {
      final i = widget.identity;
      return ReservationHolder(
        name: i.name,
        idNumber: i.idNumber,
        phone: i.phone,
      );
    }
    final id = _idNumber.text.trim();
    return ReservationHolder(
      name: _name.text.trim(),
      idNumber: id.isEmpty ? null : id,
      phone: _phone.text.trim(),
    );
  }

  /// Cuenta ficticia vinculada: la propia del cliente que reserva a su
  /// nombre, o la que coincide exactamente con la cédula escrita (R12), tanto
  /// del promotor como del cliente que reserva para otra persona.
  DemoIdentity? get _linkedAccount {
    if (_isClient && !_forOther) return widget.identity;
    return DemoIdentities.accountByIdNumber(_holder.idNumber);
  }

  Future<bool> _confirmLeave() async {
    if (!_activeNormal) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del trámite?'),
        content: Text(
          'Se cancelará este trámite y ${widget.table.displayName} quedará '
          'libre. Si sigues, conservas el tiempo que te queda.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('leave-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir con el trámite'),
          ),
          FilledButton(
            key: const ValueKey('leave-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir y cancelar'),
          ),
        ],
      ),
    );
    if (leave != true) return false;
    final id = widget.reservationId!;
    try {
      widget.store.perform((b) => b.cancelInProcess(id));
    } on ReservationException {
      // Ya no estaba En proceso (venció o se envió): no hay nada que cancelar.
    }
    return true;
  }

  /// Cambiar de identidad desde el trámite también es salir: pide la misma
  /// confirmación (R15). Si se acepta, cancela el trámite normal activo y
  /// vuelve a la entrada, limpiando la pila. Una VIP enviada no se toca.
  Future<void> _switchIdentity() async {
    final navigator = Navigator.of(context);
    if (!await _confirmLeave() || !mounted) return;
    navigator.popUntil((route) => route.isFirst);
  }

  void _toSummary() {
    setState(() => _error = null);
    final birthdayOk = _birthday.validate();
    if (_isClient && !_forOther) {
      if (birthdayOk) setState(() => _step = _Step.summary);
      return;
    }
    if (_formKey.currentState!.validate() && birthdayOk) {
      setState(() => _step = _Step.summary);
    }
  }

  void _submit() {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final holder = _holder;
    final linked = _linkedAccount?.id;
    try {
      final r = widget.store.perform(
        (b) => _isNormal
            ? b.submitNormal(
                widget.reservationId!,
                holder: holder,
                linkedAccountId: linked,
                birthday: _birthday.value,
              )
            : b.submitVip(
                night: widget.night,
                tableId: widget.table.id,
                holder: holder,
                origin: _isClient
                    ? ReservationOrigin.client
                    : ReservationOrigin.promoter,
                createdBy: widget.identity.id,
                linkedAccountId: linked,
                birthday: _birthday.value,
              ),
      );
      setState(() {
        _result = r;
        _step = _Step.done;
      });
    } on ReservationException catch (e) {
      setState(() {
        _error = actionErrorMessage(e.error);
        if (e.error == ReservationError.expired) _step = _Step.expired;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? v, String message) =>
      (v ?? '').trim().isEmpty ? message : null;

  static final _digits = RegExp(r'^\d+$');

  String? _digitsOnly(String? v, {required bool optional, String? empty}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return optional ? null : empty;
    return _digits.hasMatch(t)
        ? null
        : 'Usa solo dígitos, sin puntos, espacios ni guiones.';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Desde el resumen, «atrás» siempre vuelve al formulario, también en VIP.
      canPop: !_activeNormal && _step != _Step.summary,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (_step == _Step.summary) {
          // Volver del resumen al formulario no es abandonar (R15).
          setState(() => _step = _Step.form);
          return;
        }
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.table.isVip ? 'Solicitud VIP' : 'Reservar mesa'),
          actions: [
            IconButton(
              key: const ValueKey('flow-switch-identity'),
              tooltip: 'Cambiar identidad',
              icon: const Icon(Icons.switch_account_outlined),
              onPressed: _switchIdentity,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _header(context),
              const SizedBox(height: 12),
              ...switch (_step) {
                _Step.form => _form(context),
                _Step.summary => _summary(context),
                _Step.done => _done(context),
                _Step.expired => _expiredView(context),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final deadline = _deadline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.table.displayName} · ${widget.table.kindLabel}',
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          '${widget.night.label} · ${widget.night.scheduleLabel} '
          '(hora de Colombia)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        if (deadline != null &&
            (_step == _Step.form || _step == _Step.summary)) ...[
          const SizedBox(height: 10),
          NoticeBox(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.amber,
            text:
                'Mesa apartada mientras completas el trámite. Si no lo envías '
                'antes de las ${venueTimeLabel(deadline)}, la mesa quedará '
                'libre.',
          ),
        ],
      ],
    );
  }

  List<Widget> _form(BuildContext context) {
    final theme = Theme.of(context);
    final manual = !_isClient || _forOther;
    return [
      Text('Titular de la reserva', style: theme.textTheme.titleMedium),
      const SizedBox(height: 6),
      if (_isClient)
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('A mi nombre')),
            ButtonSegment(value: true, label: Text('Otra persona')),
          ],
          selected: {_forOther},
          onSelectionChanged: (s) => setState(() => _forOther = s.first),
        ),
      const SizedBox(height: 10),
      if (!manual)
        NoticeBox(
          icon: Icons.person_outline_rounded,
          text:
              'Titular: ${widget.identity.name}, con los datos de tu perfil '
              'de demostración.',
        )
      else
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('flow-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del titular',
                ),
                validator: (v) =>
                    _required(v, 'Escribe el nombre del titular.'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('flow-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  helperText: 'Solo dígitos.',
                ),
                validator: (v) => _digitsOnly(
                  v,
                  optional: false,
                  empty: 'Escribe el teléfono.',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('flow-id'),
                controller: _idNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula (opcional)',
                  helperText:
                      'Solo dígitos. Sirve para vincular una cuenta existente; '
                      'no es una contraseña.',
                  helperMaxLines: 3,
                ),
                validator: (v) => _digitsOnly(v, optional: true),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      BirthdayFields(draft: _birthday, prefix: 'flow'),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('flow-review'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        onPressed: _toSummary,
        child: const Text('Revisar'),
      ),
    ];
  }

  List<Widget> _summary(BuildContext context) {
    final theme = Theme.of(context);
    final holder = _holder;
    final linked = _linkedAccount;
    final terms = VenueScope.of(context).termsOf(widget.table);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
    return [
      Text('Resumen', style: theme.textTheme.titleMedium),
      row('Titular', holder.name),
      row('Teléfono', holder.phone ?? ''),
      row(
        'Cédula',
        (holder.idNumber ?? '').isEmpty ? 'Sin cédula' : holder.idNumber!,
      ),
      row(
        'Cuenta',
        // De una cuenta ajena no se muestran sus datos, solo que existe.
        linked == null
            ? 'Sin cuenta vinculada (no se adjudica por nombre ni teléfono)'
            : linked.id == widget.identity.id
            ? 'Cuenta vinculada: ${linked.name}'
            : 'Cuenta encontrada: se vinculará al enviar',
      ),
      if (_birthday.value case final b?)
        row(
          'Cumpleaños',
          '${b.honoreeName.trim()} · pendiente de confirmar por la '
              'administración (sin promoción ni decoración prometidas)',
        ),
      row('Capacidad', terms.capacity),
      for (final c in terms.conditions) Text('· $c'),
      const SizedBox(height: 10),
      NoticeBox(
        icon: widget.table.isVip
            ? Icons.payments_outlined
            : Icons.event_available_rounded,
        color: AppColors.amber,
        text: widget.table.isVip
            ? 'Al enviar, la solicitud queda pendiente de que el '
                  'administrador verifique el prepago, sin caducidad. Esta app '
                  'no cobra ni procesa pagos.'
            : 'Al enviar, la reserva queda confirmada.',
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        NoticeBox(
          key: const ValueKey('flow-error'),
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
          text: _error!,
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('flow-back'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _sending
                  ? null
                  : () => setState(() => _step = _Step.form),
              child: const Text('Editar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const ValueKey('flow-submit'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _sending ? null : _submit,
              child: Text(widget.table.isVip ? 'Enviar solicitud' : 'Enviar'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _done(BuildContext context) {
    final r = _result!;
    final vip = r.status == ReservationStatus.pendingPayment;
    return [
      NoticeBox(
        key: const ValueKey('flow-done'),
        icon: vip ? Icons.payments_outlined : Icons.check_circle_rounded,
        color: AppColors.amber,
        text: vip
            ? 'Solicitud ${r.id} enviada: ${widget.table.displayName} queda '
                  'pendiente de que el administrador verifique el prepago. No '
                  'caduca.'
            : 'Reserva ${r.id} confirmada: ${widget.table.displayName} para '
                  'el ${widget.night.label.toLowerCase()}.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('flow-show-mine'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        onPressed: () =>
            Navigator.of(context).pop(ReservationFlowResult.showMine),
        child: const Text('Ver mis reservas'),
      ),
    ];
  }

  List<Widget> _expiredView(BuildContext context) => [
    const NoticeBox(
      key: ValueKey('flow-expired'),
      icon: Icons.timer_off_outlined,
      color: AppColors.danger,
      text:
          'El trámite venció y la mesa quedó libre. Para reservar, vuelve al '
          'mapa e inicia uno nuevo.',
    ),
    const SizedBox(height: 16),
    FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Volver al mapa'),
    ),
  ];
}
