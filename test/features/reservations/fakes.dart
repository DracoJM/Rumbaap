import 'dart:async';

import 'package:rumbaap/features/reservations/domain/night_availability.dart';

const nightA = Night(id: 'a', label: 'Noche A');
const nightB = Night(id: 'b', label: 'Noche B');

/// Repositorio cuyas respuestas se completan a mano desde el test, para
/// controlar el orden en que llegan.
class ControlledRepository implements NightAvailabilityRepository {
  ControlledRepository({this.nights = const [nightA, nightB]});

  final List<Night> nights;
  final List<(String, Completer<NightAvailability>)> pending = [];

  @override
  Future<List<Night>> listNights() async => nights;

  @override
  Future<NightAvailability> availabilityFor(String nightId) {
    final completer = Completer<NightAvailability>();
    pending.add((nightId, completer));
    return completer.future;
  }

  Completer<NightAvailability> request(String nightId, {int nth = 0}) =>
      pending.where((p) => p.$1 == nightId).elementAt(nth).$2;
}

NightAvailability availability(
  String nightId,
  Map<String, TableAvailability> byTableId,
) => NightAvailability(nightId: nightId, byTableId: byTableId);
