class AppConstants {
  // Reglas de reservas
  static const int weeklyReservationLimit = 3;
  static const int dailyReservationLimit = 1;
  static const int bookingWindowDays = 14; // días hacia adelante reservables
  static const int firstBookingHour = 6;   // 6:00 AM
  static const int lastBookingHour = 19;   // último bloque 19:00-20:00
  static const int bookingDurationHours = 1;

  // Torres del conjunto
  static const int totalTowers = 6;

  // App info
  static const String appName = 'La Alameda';
  static const String appSubtitle = 'Reserva de zonas comunes';

  // Supabase table names
  static const String tableProfiles = 'profiles';
  static const String tableReservations = 'reservations';
  static const String tableAmenities = 'amenities';
  static const String tableTimeSlots = 'time_slots';
  static const String tableNotifications = 'notifications';
  static const String tableUserNotifications = 'user_notifications';
  static const String tableLotteryEntries = 'lottery_entries';
  static const String tableLotteryDraws = 'lottery_draws';

  // Lottery
  static const int lotteryMaxEntries = 3;
  static const String lotteryAmenityId = 'tenis';

  // Supabase storage buckets
  static const String bucketAmenityImages = 'amenity-images';

  // Reservation status
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusCancelled = 'cancelled';

  // User status (approval flow)
  static const String userPending = 'pending';
  static const String userApproved = 'approved';
  static const String userRejected = 'rejected';
  static const String userSuspended = 'suspended';

  // User roles
  static const String roleResident = 'resident';
  static const String roleAdmin = 'admin';
}
