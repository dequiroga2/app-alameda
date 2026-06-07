// ═══════════════════════════════════════════════════════════════════════
// MODO DEMO — para grabar tutoriales sin ningún elemento de debug visible.
//
// Cambia kActiveScenario, haz hot reload y la app se ve exactamente
// como producción pero con ese escenario activo.
//
// DemoScenario.realTime → producción normal (no hay ningún override)
// ═══════════════════════════════════════════════════════════════════════
const kActiveScenario = DemoScenario.realTime;

enum DemoScenario {
  realTime,      // App normal — datos y hora reales
  available,     // Lunes 10:00 AM  · cancha Disponible
  occupied,      // Lunes 14:00 PM  · cancha Ocupada
  closed,        // Lunes 22:00 PM  · cancha Cerrada
  weekend,       // Sábado 11:00 AM · cupo próxima semana
  fridayBefore,  // Viernes 17:00   · sorteo pendiente (Vie < 6pm)
  fridayDraw,    // Viernes 18:00   · sorteo en curso  (Vie = 6pm)
  results,       // Lunes 10:00 AM  · viendo resultados del sorteo
}

extension DemoScenarioX on DemoScenario {
  bool get isActive => this != DemoScenario.realTime;

  /// Hora ficticia — el reloj arranca desde aquí y sigue corriendo.
  DateTime get fakeTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysToMonday =
        now.weekday == DateTime.monday ? 0 : (8 - now.weekday) % 7;
    final monday = today.add(Duration(days: daysToMonday));

    return switch (this) {
      DemoScenario.realTime     => now,
      DemoScenario.available    => monday.add(const Duration(hours: 10)),
      DemoScenario.occupied     => monday.add(const Duration(hours: 14)),
      DemoScenario.closed       => monday.add(const Duration(hours: 22)),
      DemoScenario.weekend      => monday
          .subtract(const Duration(days: 2))
          .add(const Duration(hours: 11)),
      DemoScenario.fridayBefore => monday
          .add(const Duration(days: 4, hours: 17)),
      DemoScenario.fridayDraw   => monday
          .add(const Duration(days: 4, hours: 18)),
      DemoScenario.results      => monday.add(const Duration(hours: 10)),
    };
  }
}
