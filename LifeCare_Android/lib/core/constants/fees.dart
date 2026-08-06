/// Consultation and appointment fee constants for the LifeCare Connect app.
///
/// This centralized fee configuration ensures consistency across all booking flows
/// (patient booking, CHW booking, etc.) and makes future updates easier.
class ConsultationFees {
  // Private constructor to prevent instantiation
  ConsultationFees._();

  // Doctor consultation fees (in Naira)

  /// Fee for doctor follow-up appointments
  static const double doctorFollowUp = 1500.0;

  /// Fee for doctor general consultations
  static const double doctorGeneralConsultation = 3000.0;

  /// Fee for doctor mental health consultations
  static const double doctorMentalHealth = 3000.0;

  /// Fee for doctor emergency consultations
  static const double doctorEmergency = 5000.0;

  /// Fee for doctor specialist consultations
  static const double doctorSpecialist = 5000.0;

  // CHW-related fees

  /// Fee for CHW booking appointments with doctors (after free quota exhausted)
  static const double chwDoctorBooking = 2000.0;

  /// Number of free appointments for CHWs
  static const int chwFreeAppointmentQuota = 3;

  // Patient booking with CHW fees

  /// Fee for patients booking appointments with CHWs (any appointment type)
  static const double patientCHWBooking = 1000.0;

  // Payment share percentages

  /// Provider's share of consultation fee (70%)
  static const double providerSharePercentage = 0.7;

  /// Admin's share of consultation fee (30%)
  static const double adminSharePercentage = 0.3;
}
