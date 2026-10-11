import 'package:flutter/material.dart';

import '../../../../theme/venue_theme.dart';

import '../../../../app/app_theme.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';

/// Reserva directa del administrador para una mesa y una noche concretas
/// (R7): queda confirmada al crearla, también en VIP.
///
/// La mesa y la noche se fijan al abrir el formulario; el libro vuelve a
/// validar al crear (mesa libre, noche no terminada).
class DirectReservationPage extends StatefulWidget {
  const DirectReservationPage({
    super.key,
    required this.store,
    required this.night,
    required this.table,
  });

  final DemoReservationStore store;
  final Night night;
  final VenueTable table;

  @override
  State<DirectReservationPage> createState() => _DirectReservationPageState();
}

class _DirectReservationPageState extends State<DirectReservationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _idNumber = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  bool _validateOnChange = false;
  String? _error;

  static final _digits = RegExp(r'^\d+$');

  @override
  void dispose() {
    _name.dispose();
    _idNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = widget.table;
    final night = widget.night;
    return Scaffold(
      appBar: AppBar(title: const Text('Reserva directa')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                autovalidateMode: _validateOnChange
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${table.displayName} · ${table.kindLabel}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${night.label} · ${night.scheduleLabel} '
                      '(hora de Colombia)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NoticeBox(
                      icon: table.isVip
                          ? Icons.payments_outlined
                          : Icons.event_available_rounded,
                      color: table.isVip
                          ? VenueTheme.of(context).vip
                          : Theme.of(context).colorScheme.primary,
                      text: table.isVip
                          ? 'Mesa VIP: quedará confirmada al crearla, sin otro '
                                'paso de aprobación. Créala solo si ya '
                                'verificaste el prepago; esta app no cobra ni '
                                'registra comprobantes.'
                          : 'Quedará confirmada (Reservada) al crearla.',
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 12),
                      NoticeBox(
                        key: const ValueKey('form-error'),
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        text: error,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('field-name'),
                      controller: _name,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del titular',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Escribe el nombre del titular.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('field-id'),
                      controller: _idNumber,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        helperText: 'Solo dígitos.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _digitsError(v, 'la cédula'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('field-phone'),
                      controller: _phone,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        helperText: 'Solo dígitos.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _digitsError(v, 'el teléfono'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Demostración: los datos quedan solo en la memoria de '
                      'este teléfono y se pierden al cerrar la app.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          key: const ValueKey('form-cancel'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('form-submit'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Crear reserva'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _digitsError(String? value, String field) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Escribe $field.';
    if (!_digits.hasMatch(v)) {
      return 'Usa solo dígitos, sin puntos, espacios ni guiones.';
    }
    return null;
  }

  void _submit() {
    if (_submitting) return;
    setState(() {
      _validateOnChange = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final created = widget.store.perform(
        (book) => book.createDirect(
          night: widget.night,
          tableId: widget.table.id,
          holder: ReservationHolder(
            name: _name.text.trim(),
            idNumber: _idNumber.text.trim(),
            phone: _phone.text.trim(),
          ),
        ),
      );
      showResultMessage(
        messenger,
        'Reserva ${created.id} creada: ${widget.table.displayName} queda '
        'reservada para el ${widget.night.label.toLowerCase()}.',
      );
      // _submitting sigue activo: el formulario se cierra y un segundo toque
      // durante la transición no crea otra reserva.
      Navigator.of(context).pop(created.id);
    } on ReservationException catch (e) {
      setState(() {
        _submitting = false;
        _error = actionErrorMessage(e.error);
      });
    }
  }
}
