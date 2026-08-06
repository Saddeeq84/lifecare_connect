// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/profession_department_mapper.dart';
import '../../features/chw/presentation/screens/chw_consultation_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/admin_help_videos_screen.dart';
import '../../features/admin/presentation/screens/approvals_screen.dart';
import '../../features/admin/presentation/screens/admin_register_facility_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_analytics_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
import '../../features/admin/presentation/screens/admin_finance_screen.dart'; // Import AdminFinanceScreen
import '../../features/admin/presentation/screens/admin_users_management_screen.dart';
import '../../features/admin/presentation/screens/admin_training_analytics_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_hub_screen.dart';
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import actual screens from features
import '../../features/doctor/presentation/screens/doctor_settings_screen.dart';
import '../../features/doctor/presentation/screens/doctor_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/privacy_screen.dart';
// Ensure that LoginScreen is defined as a class in login_screen.dart
import '../../features/admin/presentation/screens/admin_dashboard.dart';
// Registration screens for deep linking
import '../../features/patient/presentation/screens/login_patient_register.dart';
import '../../features/chw/presentation/screens/chw_create_account.dart';
import '../../features/doctor/presentation/screens/doctor_create_account.dart';
import '../../features/facility/presentation/screens/owner_register_facility_screen.dart';
// Login screens for deep linking
import '../../features/patient/presentation/screens/login_patient.dart';
import '../../features/chw/presentation/screens/chw_login_screen.dart';
import '../../features/doctor/presentation/screens/login_doctor.dart';
import '../../features/facility/presentation/screens/facility_login_screen.dart';
// Public screens
import '../../features/public/presentation/screens/public_provider_catalog_screen.dart';
import '../../features/doctor/presentation/screens/doctor_patient_list_screen.dart';
import '../../features/doctor/presentation/screens/doctor_referrals_screen.dart';
import '../../features/doctor/presentation/screens/doctor_create_referral_screen.dart';
import '../../features/doctor/presentation/screens/doctor_analytics_screen.dart';
import '../../features/doctor/presentation/screens/doctor_consultation_screen.dart';
import '../../features/doctor/presentation/screens/doctor_clinical_resources_screen.dart';
import '../../features/doctor/presentation/screens/doctor_dashboard.dart';
import '../../features/doctor/presentation/doctor_appointments_exports.dart';
import '../../features/chw/presentation/screens/chw_dashboard.dart'; // Ensure this import is present and CHWDashboard is defined as a class
import '../../features/chw/presentation/screens/patient_registration_screen.dart';
import '../../features/chw/presentation/screens/patient_list_screen.dart';
import '../../features/chw/presentation/screens/patient_health_records_screen.dart';
import '../../features/chw/presentation/screens/chw_referrals_screen.dart';
import '../../features/chw/presentation/screens/chw_create_referral_screen.dart';
import '../../features/chw/presentation/screens/chw_consultation_details_screen.dart';
import '../../features/chw/presentation/screens/chw_anc_pnc_consultation_screen.dart';
import '../../features/chw/presentation/screens/chw_analytics_screen.dart';
import '../../features/chw/presentation/screens/chw_ask_ai_screen.dart';
// import '../../features/patient/presentation/screens/patient_consultations_screen.dart';
import '../../features/patient/presentation/screens/patient_referrals_screen.dart';
import '../../features/patient/presentation/screens/patient_dashboard.dart';
import '../../features/patient/presentation/screens/patient_appointment_screen.dart';
import '../../features/facility/presentation/screens/facility_dashboard.dart';
import '../../features/facility/presentation/screens/facility_procurement_main_screen.dart';
import '../../features/facility/presentation/screens/staff_password_setup_screen.dart';

import '../../features/facility/presentation/screens/verify_email_screen.dart';
import '../../features/shared/presentation/screens/messages_screen.dart';
import '../../features/shared/presentation/screens/chat_screen.dart';
import '../../features/shared/presentation/screens/new_conversation_screen.dart';
import '../../features/shared/presentation/screens/public_profile_screen.dart';
import '../../features/admin/presentation/screens/admin_training_screen.dart';
import '../../features/admin/presentation/screens/admin_training_help_resources_menu_screen.dart';
import '../../features/shared/presentation/screens/training_materials_screen.dart';
import '../../features/chw/presentation/screens/chw_training_screen.dart';
import '../../features/chw/presentation/screens/chw_take_courses_screen.dart';
import '../../features/chw/presentation/screens/chw_notifications_screen.dart';
import '../../features/chw/presentation/screens/chw_profile_screen.dart';
import '../../features/chw/presentation/screens/chw_edit_profile_screen.dart';
import '../../features/chw/presentation/screens/chw_profile_edit_screen.dart';
import '../../features/chw/presentation/screens/chw_appointments_screen.dart';
import '../../features/patient/presentation/screens/comprehensive_book_appointment_screen.dart';
import '../../features/patient/presentation/screens/patient_pharmacy_cart_screen.dart';
import '../../features/chw/presentation/screens/chw_doctor_consultations_screen.dart';
import '../../features/doctor/presentation/screens/doctor_chw_consultations_screen.dart';
// Department dashboards
import '../../features/facility/presentation/screens/opd_dashboard_screen.dart';
import '../../features/facility/presentation/screens/nursing_dashboard_screen.dart';
import '../../features/facility/presentation/screens/medical_records_dashboard_screen.dart';
import '../../features/facility/presentation/screens/pharmacy_dashboard_screen.dart';
import '../../features/facility/presentation/screens/laboratory_dashboard_screen.dart';
import '../../features/facility/presentation/screens/radiology_dashboard_screen.dart';
import '../../features/facility/presentation/screens/specialist_dashboard_screen.dart';
import '../../features/facility/presentation/screens/emergency_dashboard_screen.dart';
import '../../features/facility/presentation/screens/ward_dashboard_screen.dart';
import '../../features/facility/presentation/screens/public_health_dashboard_screen.dart';
import '../../features/facility/presentation/screens/immunization_management_screen.dart';
import '../../features/facility/presentation/screens/environmental_surveillance_screen.dart';
import '../../features/facility/presentation/screens/disease_surveillance_screen.dart';
import '../../features/facility/presentation/screens/infection_prevention_control_screen.dart';
import '../../features/facility/presentation/screens/outbreak_investigation_screen.dart';
import '../../features/facility/presentation/screens/health_education_screen.dart';
import '../../features/facility/presentation/screens/health_outreach_screen.dart';
import '../../features/facility/presentation/screens/service_provider_login_screen.dart';
import '../../features/facility/presentation/screens/ward_rounds_screen.dart';
import '../../features/facility/presentation/screens/ward_discharges_screen.dart';
import '../../features/facility/presentation/screens/ward_vital_signs_screen.dart';
import '../../features/facility/presentation/screens/ward_medications_screen.dart';
import '../../features/facility/presentation/screens/ward_admission_billing_screen.dart';

class AppRouter {
  static GoRouter get router => _router;

  static final _router = GoRouter(
    // No initialLocation - let the browser URL determine the route
    // This is crucial for deep links like email verification to work
    redirect: _redirect,
    redirectLimit: 5,
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      // Deep link routes for public registration
      GoRoute(
        path: '/register/patient',
        name: 'register-patient',
        builder: (context, state) => const PatientRegisterScreen(),
      ),
      GoRoute(path: '/signup', redirect: (_, __) => '/register/patient'),
      GoRoute(
        path: '/register/chw',
        name: 'register-chw',
        builder: (context, state) => const CHWCreateAccountScreen(),
      ),
      GoRoute(
        path: '/register/doctor',
        name: 'register-doctor',
        builder: (context, state) => const DoctorCreateAccountScreen(),
      ),
      GoRoute(
        path: '/register/facility',
        name: 'register-facility',
        builder: (context, state) => const OwnerRegisterFacilityScreen(),
      ),
      // Login routes for deep linking
      GoRoute(
        path: '/login/patient',
        name: 'login-patient',
        builder: (context, state) => const LoginPatient(),
      ),
      GoRoute(
        path: '/login/chw',
        name: 'login-chw',
        builder: (context, state) => const CHWLoginScreen(),
      ),
      GoRoute(
        path: '/login/doctor',
        name: 'login-doctor',
        builder: (context, state) => const LoginDoctorScreen(),
      ),
      GoRoute(
        path: '/login/facility',
        name: 'login-facility',
        builder: (context, state) => const FacilityLoginScreen(),
      ),
      GoRoute(
        path: '/login/service-provider',
        name: 'login-service-provider',
        builder: (context, state) => const ServiceProviderLoginScreen(),
      ),
      // Public Provider Catalog Route (accessible without login)
      GoRoute(
        path: '/catalog/:providerId',
        name: 'provider-catalog',
        builder: (context, state) {
          final providerId = state.pathParameters['providerId'] ?? '';
          return PublicProviderCatalogScreen(providerId: providerId);
        },
      ),
      // Public Profile Route (accessible without login)
      GoRoute(
        path: '/profile/:userId',
        name: 'public-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final returnTo = state.uri.queryParameters['returnTo'];
          return PublicProfileScreen(userId: userId, returnTo: returnTo);
        },
      ),
      GoRoute(
        path: '/patientMessaging',
        name: 'patient-messaging',
        builder: (context, state) {
          // Link to the central/shared messaging system
          return const MessagesScreen();
        },
      ),
      // Custom routes for CHW consultation flows
      // Doctor dashboard with nested settings route
      GoRoute(
        path: '/doctor_dashboard',
        name: 'doctor-dashboard',
        builder: (context, state) => const DoctorDashboard(),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'doctor-settings',
            builder: (context, state) => const DoctorSettingsScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'doctor-profile',
            builder: (context, state) => const DoctorProfileScreen(),
          ),
          GoRoute(
            path: 'patients',
            name: 'doctor-patients',
            builder: (context, state) => const DoctorPatientListScreen(),
          ),
          GoRoute(
            path: 'messages',
            name: 'doctor-messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: 'appointments',
            name: 'doctor-appointments',
            builder: (context, state) {
              final user = FirebaseAuth.instance.currentUser;
              final userId = user?.uid ?? '';
              return DoctorAppointmentsTabView(userId: userId);
            },
          ),
          GoRoute(
            path: 'referrals',
            name: 'doctor-referrals',
            builder: (context, state) => const DoctorReferralsScreen(),
            routes: [
              GoRoute(
                path: 'create_referral',
                name: 'doctor-create-referral',
                builder: (context, state) => const DoctorCreateReferralScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'analytics',
            name: 'doctor-analytics',
            builder: (context, state) => const DoctorAnalyticsScreen(),
          ),
          GoRoute(
            path: 'consultation',
            builder: (context, state) {
              return const DoctorConsultationScreen();
            },
          ),
          GoRoute(
            path: 'chw_consultations',
            name: 'doctor-chw-consultations',
            builder: (context, state) => const DoctorCHWConsultationsScreen(),
          ),
          GoRoute(
            path: 'take_course',
            name: 'doctor-take-course',
            builder: (context, state) =>
                const CHWTakeCoursesScreen(learnerRole: 'doctor'),
          ),
        ],
      ),
      GoRoute(
        path: '/doctor_resources',
        name: 'doctor-resources',
        builder: (context, state) => const DoctorClinicalResourcesScreen(),
      ),
      GoRoute(
        path: '/chw_anc_consultation_details',
        name: 'chw-anc-consultation-details',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          // Merge appointmentType into appointmentData if present
          final appointmentData = Map<String, dynamic>.from(
            extra?['appointmentData'] ?? {},
          );
          if (extra?['appointmentType'] != null) {
            appointmentData['appointmentType'] = extra?['appointmentType'];
          }
          return CHWConsultationDetailsScreen(
            appointmentId: extra?['appointmentId'] ?? '',
            patientId: extra?['patientId'] ?? '',
            patientName: extra?['patientName'] ?? '',
            appointmentData: appointmentData,
          );
        },
      ),
      GoRoute(
        path: '/chw_anc_pnc_consultation',
        name: 'chw-anc-pnc-consultation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CHWAncPncConsultationScreen(
            appointmentId: extra?['appointmentId'] ?? '',
            patientName: extra?['patientName'] ?? '',
            patientId: extra?['patientId'] ?? '',
            appointmentType: extra?['appointmentType'] ?? 'ANC',
          );
        },
      ),
      GoRoute(
        path: '/clinical_documentation',
        name: 'clinical-documentation',
        builder: (context, state) {
          // ...existing code or new screen logic...
          return Container(); // Placeholder for the new screen logic
        },
      ),
      // Email Verification Route - MUST BE BEFORE LOGIN ROUTE
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          print('🔗 [Router] Verify-email route accessed');
          print('🔗 [Router] Query params: ${state.uri.queryParameters}');

          final collection = state.uri.queryParameters['collection'];
          final docId = state.uri.queryParameters['docId'];

          if (collection == null || docId == null) {
            print('❌ [Router] Missing parameters, redirecting to login');
            Future.microtask(() => context.go('/login'));
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          print('✅ [Router] Loading VerifyEmailScreen');
          return VerifyEmailScreen(collection: collection, docId: docId);
        },
      ),
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            const LoginScreen(), // Make sure LoginScreen is a class in login_screen.dart
      ),

      // Service Provider Login Route
      GoRoute(
        path: '/service_provider_login',
        name: 'service-provider-login',
        builder: (context, state) => const ServiceProviderLoginScreen(),
      ),

      // Service Provider Dashboard Route
      GoRoute(
        path: '/service_provider_dashboard',
        name: 'service-provider-dashboard',
        builder: (context, state) =>
            const FacilityDashboard(), // Uses facility dashboard with service provider routing
      ),

      // Staff Password Setup Route
      GoRoute(
        path: '/staff-setup',
        name: 'staff-setup',
        builder: (context, state) {
          print('🔗 [Router] Staff-setup route accessed');
          print('🔗 [Router] Full path: ${state.fullPath}');
          print('🔗 [Router] URI: ${state.uri}');
          print('🔗 [Router] Query params: ${state.uri.queryParameters}');

          final staffId = state.uri.queryParameters['staffId'];
          final token = state.uri.queryParameters['token'];
          print('🔗 [Router] StaffId extracted: $staffId');

          if (staffId == null || staffId.isEmpty) {
            print('❌ [Router] No staffId found, redirecting to login');
            // Navigate to login if staffId is missing
            Future.microtask(() => context.go('/login'));
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          print(
            '✅ [Router] Loading StaffPasswordSetupScreen with staffId: $staffId',
          );
          return StaffPasswordSetupScreen(staffId: staffId, resetToken: token);
        },
      ),

      // Admin Routes
      GoRoute(
        path: '/admin_dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
        routes: [
          GoRoute(
            path: 'approvals',
            name: 'admin-approvals',
            builder: (context, state) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: 'register_facility',
            name: 'admin-register-facility',
            builder: (context, state) => const AdminRegisterFacilityScreen(),
          ),
          GoRoute(
            path: 'upload_training',
            name: 'admin-upload-training',
            builder: (context, state) =>
                const AdminTrainingHelpResourcesMenuScreen(),
          ),
          GoRoute(
            path: 'help_videos',
            name: 'admin-help-videos',
            builder: (context, state) => const AdminHelpVideosScreen(),
          ),
          GoRoute(
            path: 'messages',
            name: 'admin-messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: 'reports_analytics',
            name: 'admin-reports-analytics',
            builder: (context, state) => const AdminReportsAnalyticsScreen(),
          ),
          GoRoute(
            path: 'analytics',
            name: 'admin-analytics',
            builder: (context, state) => const AdminAnalyticsScreen(),
          ),
          GoRoute(
            path: 'training',
            name: 'admin-training',
            builder: (context, state) => const AdminTrainingScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'admin-settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: 'finance',
            name: 'admin-finance',
            builder: (context, state) => const AdminFinanceScreen(),
          ),
          GoRoute(
            path: 'users_management',
            name: 'admin-users-management',
            builder: (context, state) => const AdminUsersManagementScreen(),
          ),
          GoRoute(
            path: 'training_analytics',
            name: 'admin-training-analytics',
            builder: (context, state) => const AdminTrainingAnalyticsScreen(),
          ),
          GoRoute(
            path: 'analytics_hub',
            name: 'admin-analytics-hub',
            builder: (context, state) => const AdminAnalyticsHubScreen(),
          ),
        ],
      ),

      // CHW Routes
      GoRoute(
        path: '/chw_dashboard',
        name: 'chw-dashboard',
        builder: (context, state) => const CHWDashboard(),
        routes: [
          GoRoute(
            path: 'patients',
            name: 'chw-patients',
            builder: (context, state) => const ChwPatientListScreen(),
          ),
          GoRoute(
            path: 'register_patient',
            name: 'chw-register-patient',
            builder: (context, state) =>
                const PatientRegistrationScreen(isCHW: true),
          ),
          GoRoute(
            path: 'registration',
            name: 'chw-registration',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: 'appointments',
            name: 'chw-appointments',
            // builder: (context, state) => const CHWAppointmentsScreen(),
            builder: (context, state) => CHWAppointmentsScreen(),
          ),
          // Book Appointment is now handled as a modal/dialog in CHWAppointmentsScreen. No separate route needed.
          GoRoute(
            path: 'referrals',
            name: 'chw-referrals',
            builder: (context, state) => const CHWReferralsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'chw-create-referral',
                builder: (context, state) => const CHWCreateReferralScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'regular-consultations',
            name: 'chw-regular-consultations',
            builder: (context, state) => CHWAppointmentsScreen(initialTab: 1),
          ),
          GoRoute(
            path: 'messages',
            name: 'chw-messages',
            builder: (context, state) => const MessagesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'chw-new-conversation',
                builder: (context, state) => const NewConversationScreen(),
              ),
              GoRoute(
                path: 'chat/:conversationId',
                name: 'chw-chat',
                builder: (context, state) {
                  final conversationId =
                      state.pathParameters['conversationId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  return ChatScreen(
                    conversationId: conversationId,
                    otherParticipantName:
                        extra?['otherParticipantName'] ?? 'Unknown',
                    otherParticipantRole:
                        extra?['otherParticipantRole'] ?? 'USER',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'notifications',
            name: 'chw-notifications',
            builder: (context, state) => const CHWNotificationsScreen(),
          ),
          GoRoute(
            path: 'patient_health_records',
            name: 'chw-patient-health-records',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return PatientHealthRecordsScreen(
                patientId: extra?['patientId'] ?? '',
                patientName: extra?['patientName'] ?? 'Unknown Patient',
              );
            },
          ),
          GoRoute(
            path: 'training',
            name: 'chw-training',
            builder: (context, state) => const CHWTrainingScreen(),
          ),
          GoRoute(
            path: 'take_course',
            name: 'chw-take-course',
            builder: (context, state) => const CHWTakeCoursesScreen(),
          ),
          GoRoute(
            path: 'ask_ai',
            name: 'chw-ask-ai',
            builder: (context, state) => const CHWAskAIScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'chw-profile',
            builder: (context, state) => const CHWProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'chw-settings',
            builder: (context, state) => const CHWEditProfileScreen(),
          ),
          GoRoute(
            path: 'edit-profile',
            name: 'chw-edit-profile',
            builder: (context, state) => const CHWProfileEditScreen(),
          ),
          GoRoute(
            path: 'consultations',
            name: 'chw-consultations',
            builder: (context, state) => const CHWConsultationScreen(),
          ),
          GoRoute(
            path: 'doctor_consultations',
            name: 'chw-doctor-consultations',
            builder: (context, state) => const CHWDoctorConsultationsScreen(),
          ),
          GoRoute(
            path: 'analytics',
            name: 'chw-analytics',
            builder: (context, state) => const CHWAnalyticsScreen(),
          ),
        ],
      ),

      // Patient Routes
      GoRoute(
        path: '/patient_dashboard',
        name: 'patient-dashboard',
        builder: (context, state) => const PatientDashboard(),
        routes: [
          GoRoute(
            path: 'appointments',
            name: 'patient-appointments',
            builder: (context, state) => const PatientAppointmentsScreen(),
          ),
          GoRoute(
            path: 'consultations',
            name: 'patient-consultations',
            builder: (context, state) => const PatientConsultationsScreen(),
          ),
          GoRoute(
            path: 'referrals',
            name: 'patient-referrals',
            builder: (context, state) => const PatientReferralsScreen(),
          ),
          GoRoute(
            path: 'messages',
            name: 'patient-messages',
            builder: (context, state) => const MessagesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'patient-new-conversation',
                builder: (context, state) => const NewConversationScreen(),
              ),
              GoRoute(
                path: 'chat/:conversationId',
                name: 'patient-chat',
                builder: (context, state) {
                  final conversationId =
                      state.pathParameters['conversationId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  return ChatScreen(
                    conversationId: conversationId,
                    otherParticipantName:
                        extra?['otherParticipantName'] ?? 'Unknown',
                    otherParticipantRole:
                        extra?['otherParticipantRole'] ?? 'USER',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'health-records',
            name: 'patient-health-records',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: 'profile',
            name: 'patient-profile',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: 'training',
            name: 'patient-training',
            builder: (context, state) =>
                const TrainingMaterialsScreen(userRole: 'patient'),
          ),
          GoRoute(
            path: 'pharmacy',
            name: 'patient-pharmacy',
            builder: (context, state) {
              final providerId = state.uri.queryParameters['providerId'] ?? '';
              return PatientPharmacyCartScreen(
                facilityId: providerId,
                facilityData: const {},
              );
            },
          ),
        ],
      ),

      // Book Appointment Route (for patient referrals)
      GoRoute(
        path: '/book_appointment',
        name: 'book-appointment',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return ComprehensiveBookAppointmentScreen(
            preSelectedProvider: args['preSelectedProvider'],
            fromReferral: args['fromReferral'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/order',
        name: 'order',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          final product = args['product'];
          final facilityId = args['facilityId'] ?? product?['facilityId'] ?? '';
          final facilityData = args['facilityData'] is Map<String, dynamic>
              ? args['facilityData'] as Map<String, dynamic>
              : <String, dynamic>{
                  'name': product?['facilityName'],
                  'type': 'Pharmacy',
                };
          return PatientPharmacyCartScreen(
            facilityId: facilityId,
            facilityData: facilityData,
          );
        },
      ),

      // Facility Routes
      GoRoute(
        path: '/facility_dashboard',
        name: 'facility-dashboard',
        builder: (context, state) => const FacilityDashboard(),
        routes: [
          GoRoute(
            path: 'staff',
            name: 'facility-staff',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: 'appointments',
            name: 'facility-appointments',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: 'patients',
            name: 'facility-patients',
            builder: (context, state) => Container(),
          ),
        ],
      ),
      GoRoute(
        path: '/facility_procurement',
        name: 'facility-procurement',
        builder: (context, state) => const FacilityProcurementMainScreen(),
      ),

      // Department Dashboards (Profession-based routing)
      GoRoute(
        path: '/opd_dashboard',
        name: 'opd-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return OPDDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                doctorId: userData['userId'] ?? '',
                doctorName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/nursing_dashboard',
        name: 'nursing-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return NursingDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/medical_records_dashboard',
        name: 'medical-records-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return MedicalRecordsDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/pharmacy_dashboard',
        name: 'pharmacy-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return PharmacyDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/laboratory_dashboard',
        name: 'laboratory-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return LaboratoryDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/radiology_dashboard',
        name: 'radiology-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return RadiologyDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/public_health_dashboard',
        name: 'public-health-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return PublicHealthDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/emergency_dashboard',
        name: 'emergency-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return EmergencyDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),

      // Public Health Feature Routes
      GoRoute(
        path: '/immunization_management',
        name: 'immunization-management',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ImmunizationManagementScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/environmental_surveillance',
        name: 'environmental-surveillance',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return EnvironmentalSurveillanceScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/disease_surveillance',
        name: 'disease-surveillance',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DiseaseSurveillanceScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/infection_prevention_control',
        name: 'infection-prevention-control',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _getUserData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final userData = snapshot.data ?? {};
                return InfectionPreventionControlScreen(
                  facilityId: userData['facilityId'] ?? '',
                  facilityName: userData['facilityName'] ?? '',
                  staffId: userData['userId'] ?? '',
                  staffName: userData['userName'] ?? '',
                );
              },
            );
          }
          return InfectionPreventionControlScreen(
            facilityId: extra['facilityId'] ?? '',
            facilityName: extra['facilityName'] ?? '',
            staffId: extra['staffId'] ?? '',
            staffName: extra['staffName'] ?? '',
            initialTabIndex: extra['initialTabIndex'] ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/outbreak_investigation',
        name: 'outbreak-investigation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OutbreakInvestigationScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/health_education',
        name: 'health-education',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return HealthEducationScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/health_outreach',
        name: 'health-outreach',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return HealthOutreachScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
          );
        },
      ),

      GoRoute(
        path: '/specialist_dashboard',
        name: 'specialist-dashboard',
        builder: (context, state) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return SpecialistDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                doctorId: userData['userId'] ?? '',
                doctorName: userData['userName'] ?? '',
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/ward_dashboard',
        name: 'ward-dashboard',
        builder: (context, state) {
          final wardId = state.uri.queryParameters['wardId'];
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final userData = snapshot.data ?? {};
              return WardDashboardScreen(
                facilityId: userData['facilityId'] ?? '',
                facilityName: userData['facilityName'] ?? '',
                staffId: userData['userId'] ?? '',
                staffName: userData['userName'] ?? '',
                wardId: wardId,
              );
            },
          );
        },
      ),

      // Ward Management Routes
      GoRoute(
        path: '/ward_rounds',
        name: 'ward-rounds',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WardRoundsScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
            excludeEmergencyAdmissions:
                extra?['excludeEmergencyAdmissions'] ?? false,
            filterByEmergency: extra?['filterByEmergency'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/ward_discharges',
        name: 'ward-discharges',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WardDischargesScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
            excludeEmergencyAdmissions:
                extra?['excludeEmergencyAdmissions'] ?? false,
            filterByEmergency: extra?['filterByEmergency'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/ward_vital_signs',
        name: 'ward-vital-signs',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WardVitalSignsScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
            excludeEmergencyAdmissions:
                extra?['excludeEmergencyAdmissions'] ?? false,
            filterByEmergency: extra?['filterByEmergency'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/ward_medications',
        name: 'ward-medications',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WardMedicationsScreen(
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
            staffId: extra?['staffId'] ?? '',
            staffName: extra?['staffName'] ?? '',
            excludeEmergencyAdmissions:
                extra?['excludeEmergencyAdmissions'] ?? false,
            filterByEmergency: extra?['filterByEmergency'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/ward_admission_billing',
        name: 'ward-admission-billing',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WardAdmissionBillingScreen(
            admissionId: extra?['admissionId'] ?? '',
            facilityId: extra?['facilityId'] ?? '',
            facilityName: extra?['facilityName'] ?? '',
          );
        },
      ),

      // Shared Routes
      GoRoute(
        path: '/training-materials',
        name: 'training-materials',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userRole = extra?['userRole'] ?? 'chw';
          return TrainingMaterialsScreen(userRole: userRole);
        },
      ),

      // Consultation Routes
    ],
  );

  static FutureOr<String?> _redirect(context, state) async {
    final path = state.uri.path;

    // PUBLIC ROUTES - Allow access without authentication
    if (path == '/privacy' ||
        path == '/login' ||
        path.startsWith('/staff-setup') ||
        path.startsWith('/verify-email') ||
        path.startsWith('/profile/') ||
        path.startsWith('/register/') ||
        path.startsWith('/login/') ||
        path.startsWith('/catalog/')) {
      return null; // Allow access
    }

    // Now check auth status for protected routes
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final staffRole = prefs.getString('user_role');
    final userId = prefs.getString('user_id'); // Check for Termii/OTP login

    // IMPORTANT: Firebase Auth users take priority over SharedPreferences login
    // This prevents conflicts when the same email is used for multiple roles
    final isStaffLoggedIn =
        (staffRole == 'facility_staff' ||
            staffRole == 'service_provider_staff') &&
        user == null;
    final isPhoneLoggedIn =
        userId != null &&
        staffRole != null &&
        user == null; // Termii/Phone OTP login (all roles)
    final isLoggedIn = user != null || isStaffLoggedIn || isPhoneLoggedIn;
    final isOnLoginPage = path == '/login';
    final isRootPath = path == '/';

    // Root path handling
    if (isRootPath) {
      if (!isLoggedIn) return '/login';
      if (user != null) return await _getRouteForUserRole(user);
      if (isStaffLoggedIn) return await _getRouteForStaffRole();
      if (isPhoneLoggedIn) return await _getRouteForPhoneLogin(staffRole);
    }

    // Not logged in and not on login page
    if (!isLoggedIn && !isOnLoginPage) {
      return '/login';
    }

    // Already logged in and on login page
    if (isLoggedIn && isOnLoginPage) {
      if (user != null) return await _getRouteForUserRole(user);
      if (isStaffLoggedIn) return await _getRouteForStaffRole();
      if (isPhoneLoggedIn) return await _getRouteForPhoneLogin(staffRole);
    }

    return null; // No redirect needed
  }

  /// Helper method to determine route based on user role
  static Future<String> _getRouteForUserRole(User user) async {
    // Fetch user role from Firestore (this is the source of truth)
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print('⚠️ User document not found for ${user.uid}');
        return '/login';
      }

      final userData = userDoc.data();
      final role = userData?['role'] as String?;

      print('👤 User role from Firestore: $role');

      // Route based on role field in users collection
      if (role != null) {
        switch (role.toLowerCase()) {
          case 'admin':
            return '/admin_dashboard';
          case 'doctor':
            return '/doctor_dashboard';
          case 'chw':
            return '/chw_dashboard';
          case 'facility':
            return '/facility_dashboard';
          case 'patient':
            return '/patient_dashboard';
        }
      }

      // If role is not one of the standard roles, check for department field first
      final departmentField = userData?['department'] as String?;
      final profession = userData?['profession'] as String?;
      print('👤 User department: $departmentField');
      print('👤 User profession: $profession');

      if (_isIpcDashboardValue(departmentField) ||
          _isIpcDashboardValue(profession)) {
        return '/infection_prevention_control';
      }

      // Determine department - prioritize department field over profession mapping
      DepartmentType? department;
      if (departmentField != null && departmentField.isNotEmpty) {
        department = _getDepartmentTypeFromString(departmentField);
        print('🏥 Department from field: $department');
      }

      // If no department field or not recognized, fall back to profession mapping
      if (department == null && profession != null && profession.isNotEmpty) {
        department = ProfessionDepartmentMapper.getDepartmentForProfession(
          profession,
        );
        print('🏥 Department from profession mapping: $department');
      }

      if (department == null) {
        print('⚠️ Could not determine department for user ${user.uid}');
        return '/login';
      }

      // Route based on department
      switch (department) {
        case DepartmentType.opd:
          return '/opd_dashboard';
        case DepartmentType.nursing:
          return '/nursing_dashboard';
        case DepartmentType.medicalRecords:
          return '/medical_records_dashboard';
        case DepartmentType.pharmacy:
          return '/pharmacy_dashboard';
        case DepartmentType.laboratory:
          return '/laboratory_dashboard';
        case DepartmentType.radiology:
          return '/radiology_dashboard';
        case DepartmentType.publicHealth:
          return '/public_health_dashboard';
        case DepartmentType.emergency:
          return '/emergency_dashboard';
        case DepartmentType.specialist:
          return '/specialist_dashboard';
        case DepartmentType.ward:
          return '/ward_dashboard';
      }
    } catch (e) {
      print('❌ Error fetching user role/profession: $e');
      return '/login';
    }
  }

  /// Helper method to determine route based on staff role from SharedPreferences
  static Future<String> _getRouteForStaffRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      // Check if this is a service provider staff (pharmacy, lab, scan center, mental health)
      if (userRole == 'service_provider_staff') {
        print(
          '👤 Service provider staff - routing to service provider dashboard',
        );
        return '/service_provider_dashboard';
      }

      // For facility staff, route to department-specific dashboard
      final departmentField = prefs.getString('staff_department');
      final profession = prefs.getString('staff_profession');

      print('👤 Staff department: $departmentField');
      print('👤 Staff profession: $profession');

      if (_isIpcDashboardValue(departmentField) ||
          _isIpcDashboardValue(profession)) {
        return '/infection_prevention_control';
      }

      // Determine department - prioritize department field over profession mapping
      DepartmentType? department;
      if (departmentField != null && departmentField.isNotEmpty) {
        department = _getDepartmentTypeFromString(departmentField);
        print('🏥 Department from field: $department');
      }

      // If no department field or not recognized, fall back to profession mapping
      if (department == null && profession != null && profession.isNotEmpty) {
        department = ProfessionDepartmentMapper.getDepartmentForProfession(
          profession,
        );
        print('🏥 Department from profession mapping: $department');
      }

      if (department == null) {
        print('⚠️ Could not determine department for staff');
        return '/login';
      }

      // Route based on department
      switch (department) {
        case DepartmentType.opd:
          return '/opd_dashboard';
        case DepartmentType.nursing:
          return '/nursing_dashboard';
        case DepartmentType.medicalRecords:
          return '/medical_records_dashboard';
        case DepartmentType.pharmacy:
          return '/pharmacy_dashboard';
        case DepartmentType.laboratory:
          return '/laboratory_dashboard';
        case DepartmentType.radiology:
          return '/radiology_dashboard';
        case DepartmentType.publicHealth:
          return '/public_health_dashboard';
        case DepartmentType.emergency:
          return '/emergency_dashboard';
        case DepartmentType.specialist:
          return '/specialist_dashboard';
        case DepartmentType.ward:
          return '/ward_dashboard';
      }
    } catch (e) {
      print('❌ Error getting staff route: $e');
      return '/login';
    }
  }

  /// Helper method to convert department string to DepartmentType enum
  static DepartmentType? _getDepartmentTypeFromString(String department) {
    final departmentLower = department.toLowerCase().trim();

    // Map department strings to enum values
    if (departmentLower.contains('emergency')) {
      return DepartmentType.emergency;
    } else if (departmentLower.contains('opd') ||
        departmentLower.contains('out-patient')) {
      return DepartmentType.opd;
    } else if (departmentLower.contains('specialist')) {
      return DepartmentType.specialist;
    } else if (departmentLower.contains('nursing')) {
      return DepartmentType.nursing;
    } else if (departmentLower.contains('medical records') ||
        departmentLower.contains('records')) {
      return DepartmentType.medicalRecords;
    } else if (departmentLower.contains('pharmacy')) {
      return DepartmentType.pharmacy;
    } else if (departmentLower.contains('laboratory') ||
        departmentLower.contains('lab')) {
      return DepartmentType.laboratory;
    } else if (departmentLower.contains('radiology') ||
        departmentLower.contains('imaging')) {
      return DepartmentType.radiology;
    } else if (departmentLower.contains('public health')) {
      return DepartmentType.publicHealth;
    } else if (departmentLower.contains('ward') ||
        departmentLower.contains('ipd') ||
        departmentLower.contains('inpatient')) {
      return DepartmentType.ward;
    }

    return null;
  }

  static bool _isIpcDashboardValue(String? value) {
    final normalized = value?.toLowerCase().trim() ?? '';
    return normalized.startsWith('ipc ') ||
        normalized.contains('infection prevention') ||
        normalized.contains('infection control');
  }

  /// Helper method to fetch current user data from Firestore
  static Future<Map<String, dynamic>> _getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // First check SharedPreferences for staff login data
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'facility_staff') {
        // Staff logged in with simplified login (no Firebase Auth)
        return {
          'userId': prefs.getString('staff_id') ?? '',
          'userName': prefs.getString('staff_name') ?? '',
          'facilityId': prefs.getString('facility_id') ?? '',
          'facilityName': prefs.getString('facility_name') ?? '',
          'profession': prefs.getString('staff_profession') ?? '',
        };
      }

      // For other users (admins, doctors, etc.) - check Firebase Auth
      if (user == null) {
        return {};
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return {'userId': user.uid};
      }

      final data = userDoc.data() ?? {};
      return {
        'userId': user.uid,
        'userName': data['name'] ?? data['fullName'] ?? '',
        'facilityId': data['facilityId'] ?? '',
        'facilityName': data['facilityName'] ?? '',
        'profession': data['profession'] ?? '',
      };
    } catch (e) {
      print('❌ Error fetching user data: $e');
      return {};
    }
  }

  /// Helper method to determine route based on phone login role
  static Future<String> _getRouteForPhoneLogin(String role) async {
    print('📱 Phone login - routing for role: $role');

    switch (role) {
      case 'admin':
        return '/admin_dashboard';
      case 'doctor':
        return '/doctor_dashboard';
      case 'chw':
        return '/chw_dashboard';
      case 'facility':
        return '/facility_dashboard';
      case 'patient':
        return '/patient_dashboard';
      default:
        print('⚠️ Unknown phone login role: $role');
        return '/login';
    }
  }
}
