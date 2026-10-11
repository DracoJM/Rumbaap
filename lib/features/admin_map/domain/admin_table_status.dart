/// Estado de una mesa tal como lo ve el administrador en una noche.
///
/// Lo usa la maqueta aprobada del mapa del administrador con datos
/// ficticios. Las transiciones entre estados no están definidas aquí.
enum AdminTableStatus {
  available,
  reserved,
  inProgress,
  occupied,
  vipPaymentPending,
  unknown,
}
