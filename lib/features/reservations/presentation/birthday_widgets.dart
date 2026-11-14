import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../session/demo_identities.dart';
import '../data/demo_reservation_store.dart';
import '../domain/reservation.dart';
import '../domain/reservation_book.dart';
import 'admin/admin_labels.dart';
import 'admin/admin_widgets.dart';
import 'table_presentation.dart';

/// Lo que se escribe del cumpleaños en un formulario de reserva.
class BirthdayDraft {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final notes = TextEditingController();
  bool enabled = false;

  /// El cumpleaños para el alta, o `null` si no se marcó.
  BirthdayCelebration? get value => enabled
      ? BirthdayCelebration(honoreeName: name.text, notes: notes.text)
      : null;

  bool validate() => !enabled || formKey.currentState!.validate();

  void dispose() {
    name.dispose();
    notes.dispose();
  }
}

/// Campos opcionales del cumpleaños: igual para cliente, promotor y
/// administración. No pide fecha de nacimiento, edad ni documentos.
class BirthdayFields extends StatefulWidget {
  const BirthdayFields({super.key, required this.draft, required this.prefix});

  final BirthdayDraft draft;

  /// Prefijo de las claves de los campos (p. ej., `flow`, `direct`).
  final String prefix;

  @override
  State<BirthdayFields> createState() => _BirthdayFieldsState();
}

class _BirthdayFieldsState extends State<BirthdayFields> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Form(
      key: d.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: ValueKey('${widget.prefix}-birthday'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Celebración de cumpleaños'),
            subtitle: const Text('Opcional'),
            value: d.enabled,
            onChanged: (v) => setState(() => d.enabled = v),
          ),
          if (d.enabled) ...[
            TextFormField(
              key: ValueKey('${widget.prefix}-birthday-name'),
              controller: d.name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien cumple años',
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Escribe el nombre de quien cumple años.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('${widget.prefix}-birthday-notes'),
              controller: d.notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 10),
            const NoticeBox(
              icon: Icons.info_outline_rounded,
              text:
                  'Marcar el cumpleaños no incluye promoción ni decoración: la '
                  'administración confirma después las condiciones, si las '
                  'hay. La reserva sigue las mismas reglas de siempre.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado del cumpleaños en pocas palabras, para listas y seguimiento.
String birthdayStageLabel(BirthdayCelebration b) => switch (b.stage) {
  BirthdayStage.requested =>
    'Cumpleaños solicitado · pendiente de confirmar por la administración',
  BirthdayStage.confirmed => 'Cumpleaños confirmado · sin decoración',
  BirthdayStage.decorationPending when b.decorationNeedsReview =>
    'Cumpleaños ajustado · decoración por revisar otra vez',
  BirthdayStage.decorationPending =>
    'Cumpleaños confirmado · decoración por preparar',
  BirthdayStage.decorationPrepared =>
    'Cumpleaños confirmado · decoración preparada',
};

/// Estado corto, para filas de listas estrechas.
String birthdayShortLabel(BirthdayCelebration b) => switch (b.stage) {
  BirthdayStage.requested => 'Cumpleaños por confirmar',
  BirthdayStage.confirmed => 'Cumpleaños confirmado',
  BirthdayStage.decorationPending when b.decorationNeedsReview =>
    'Decoración por revisar',
  BirthdayStage.decorationPending => 'Decoración por preparar',
  BirthdayStage.decorationPrepared => 'Decoración preparada',
};

String _who(ActorStamp s) =>
    '${DemoIdentities.byId(s.actorId)?.name ?? s.actorId} · '
    '${venueDateTimeLabel(s.at)}';

/// Ficha del cumpleaños de una reserva. Con [store] y [actorId] muestra
/// las acciones de la administración (el dominio vuelve a comprobarlo).
class BirthdayCard extends StatelessWidget {
  const BirthdayCard({
    super.key,
    required this.reservation,
    this.store,
    this.actorId,
  });

  final Reservation reservation;
  final DemoReservationStore? store;
  final String? actorId;

  @override
  Widget build(BuildContext context) {
    final b = reservation.birthday!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final t = b.terms;
    final canAct = store != null && actorId != null;
    return Column(
      key: ValueKey('birthday-${reservation.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cumpleaños de ${b.honoreeName}',
          style: theme.textTheme.titleSmall,
        ),
        if (b.notes != null) Text('Notas: ${b.notes}', style: muted),
        const SizedBox(height: 4),
        Text(
          birthdayStageLabel(b),
          key: ValueKey('birthday-stage-${reservation.id}'),
        ),
        if (t == null)
          Text(
            'Sin promoción ni decoración confirmadas: no se promete nada '
            'hasta que la administración lo confirme.',
            style: muted,
          )
        else ...[
          Text('Condiciones: ${t.conditions}'),
          Text('Confirmado por ${_who(t.confirmed)}', style: muted),
        ],
        if (b.decorationPrepared case final d?)
          Text('Decoración preparada por ${_who(d)}', style: muted),
        for (final (i, a) in b.previous.indexed)
          Text(
            'Acuerdo anterior: ${a.terms.conditions} · '
            '${a.terms.decorationRequired ? 'con' : 'sin'} decoración · '
            '${_who(a.terms.confirmed)}'
            '${a.decorationPrepared == null ? '' : ' · decoración preparada por ${_who(a.decorationPrepared!)}'}',
            key: ValueKey('birthday-previous-${reservation.id}-$i'),
            style: muted,
          ),
        if (canAct && reservation.status.isActive) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: ValueKey('birthday-confirm-${reservation.id}'),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              t == null ? 'Confirmar condiciones' : 'Ajustar condiciones',
            ),
            onPressed: () => _confirm(context, t),
          ),
        ],
        if (canAct && b.stage == BirthdayStage.decorationPending) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: ValueKey('birthday-prepared-${reservation.id}'),
            icon: const Icon(Icons.celebration_outlined),
            label: const Text('Marcar decoración preparada'),
            onPressed: () => _run(
              context,
              (b) =>
                  b.markDecorationPrepared(reservation.id, actorId: actorId!),
              'Decoración marcada como preparada.',
            ),
          ),
        ],
      ],
    );
  }

  void _run(
    BuildContext context,
    void Function(ReservationBook book) op,
    String done,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    try {
      store!.perform(op);
      showResultMessage(messenger, done);
    } on ReservationException catch (e) {
      showResultMessage(messenger, actionErrorMessage(e.error), error: true);
    }
  }

  Future<void> _confirm(BuildContext context, BirthdayTerms? current) async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => _ConfirmBirthdayDialog(current: current),
    );
    if (result == null || !context.mounted) return;
    _run(
      context,
      (b) => b.confirmBirthday(
        reservation.id,
        conditions: result.$1,
        decorationRequired: result.$2,
        actorId: actorId!,
      ),
      'Condiciones del cumpleaños confirmadas.',
    );
  }
}

class _ConfirmBirthdayDialog extends StatefulWidget {
  const _ConfirmBirthdayDialog({this.current});

  final BirthdayTerms? current;

  @override
  State<_ConfirmBirthdayDialog> createState() => _ConfirmBirthdayDialogState();
}

class _ConfirmBirthdayDialogState extends State<_ConfirmBirthdayDialog> {
  late final _conditions = TextEditingController(
    text: widget.current?.conditions,
  );
  late bool _decoration = widget.current?.decorationRequired ?? false;

  @override
  void dispose() {
    _conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _conditions.text.trim().isNotEmpty;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.current == null ? 'Confirmar cumpleaños' : 'Ajustar cumpleaños',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('birthday-conditions'),
            controller: _conditions,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Detalles y condiciones acordados',
              helperText:
                  'Se escriben a mano; la app no aplica descuentos, '
                  'cortesías ni cobros.',
              helperMaxLines: 3,
            ),
          ),
          CheckboxListTile(
            key: const ValueKey('birthday-decoration'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Requiere decoración antes de la apertura'),
            value: _decoration,
            onChanged: (v) => setState(() => _decoration = v ?? false),
          ),
          if (widget.current != null)
            const Text(
              'El acuerdo anterior queda en el historial. Si había decoración '
              'preparada, habrá que revisarla otra vez.',
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('dialog-confirm'),
          onPressed: ok
              ? () => Navigator.of(context).pop((_conditions.text, _decoration))
              : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
