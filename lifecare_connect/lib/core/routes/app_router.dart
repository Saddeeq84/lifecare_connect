// ignore_for_file: avoid_print, depend_on_referenced_packages

import '../../features/chw/presentation/screens/chw_consultation_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/approvals_screen.dart';
import '../../features/admin/presentation/screens/admin_register_facility_screen.dart';
import '../../features/admin/presentation/screens/admin_training_upload_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_analytics_screen.dart';
import '../../features/admin/presentation/screens/admin_analytics_screen.dart';
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import actual screens from features
import '../../features/doctor/presentation/screens/doctor_settings_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
// Ensure that LoginScreen is defined as a class in login_screen.dart
import '../../features/admin/presentation/screens/admin_dashboard.dart';
import '../../features/doctor/presentation/screens/doctor_patient_list_screen.dart';
import '../../features/doctor/presentation/screens/doctor_referrals_screen.dart';
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
// import '../../features/patient/presentation/screens/patient_consultations_screen.dart';
import '../../features/patient/presentation/screens/patient_referrals_screen.dart';
import '../../features/patient/presentation/screens/patient_dashboard.dart';
import '../../features/patient/presentation/screens/patient_appointment_screen.dart';
import '../../features/facility/presentation/screens/facility_dashboard.dart';
import '../../features/shared/presentation/screens/messages_screen.dart';
import '../../features/shared/presentation/screens/chat_screen.dart';
import '../../features/shared/presentation/screens/new_conversation_screen.dart';
import '../../features/admin/presentation/screens/admin_training_screen.dart';
import '../../features/shared/presentation/screens/training_materials_screen.dart';
import '../../features/chw/presentation/screens/chw_training_screen.dart';
import '../../features/chw/presentation/screens/chw_profile_screen.dart';
import '../../features/chw/presentation/screens/chw_edit_profile_screen.dart';
import '../../features/chw/presentation/screens/chw_profile_edit_screen.dart';
import '../../features/chw/presentation/screens/chw_appointments_screen.dart';

class AppRouter {
  static GoRouter get router => _router;
  
  static final _router = GoRouter(
    initialLocation: '/login',
    redirect: _redirect,
    routes: [
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
          final appointmentData = Map<String, dynamic>.from(extra?['appointmentData'] ?? {});
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
        path: '/clinical_documentation',
        name: 'clinical-documentation',
          builder: (context, state) {
            // ...existing code or new screen logic...
            return Container(); // Placeholder for the new screen logic
          },
      ),
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(), // Make sure LoginScreen is a class in login_screen.dart
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
                builder: (context, state) => const AdminTrainingUploadScreen(),
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
            builder: (context, state) => const PatientRegistrationScreen(isCHW: true),
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
                  final conversationId = state.pathParameters['conversationId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  return ChatScreen(
                    conversationId: conversationId,
                    otherParticipantName: extra?['otherParticipantName'] ?? 'Unknown',
                    otherParticipantRole: extra?['otherParticipantRole'] ?? 'USER',
                  );
                },
              ),
            ],
          ),
          // Removed: ANCChecklistScreen route (no longer exists)
          // Removed: CHWANCConsultationScreen (no longer exists)
          // If ANC/PNC details are needed, use chw_anc_consultation_details_screen.dart instead.
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
                  final conversationId = state.pathParameters['conversationId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  return ChatScreen(
                    conversationId: conversationId,
                    otherParticipantName: extra?['otherParticipantName'] ?? 'Unknown',
                    otherParticipantRole: extra?['otherParticipantRole'] ?? 'USER',
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
            builder: (context, state) => const TrainingMaterialsScreen(userRole: 'patient'),
          ),
        ],
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
      // Removed: GoRoute for CHWConsultationScreen (screen does not exist)
    ],
  );
  
  static String? _redirect(context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isOnLoginPage = state.fullPath == '/login';
    
    // If not logged in and not on login page, redirect to login
    if (!isLoggedIn && !isOnLoginPage) {
      return '/login';
    }
    
    // If logged in and on login page, redirect based on user role
    if (isLoggedIn && isOnLoginPage) {
      // Use a more sophisticated role resolution approach
      return _getRouteForUserRole(user);
    }
    
    return null; // No redirect needed
  }
  
  /// Helper method to determine route based on user role
  static String _getRouteForUserRole(User user) {
    // Simple email-based routing (for immediate resolution)
    final rawEmail = user.email ?? '';
    final email = rawEmail.trim().toLowerCase();

    String detectedRole = 'unknown';
    String route = '/login';

    // Facility check is always first and case-insensitive
    if (email.contains('facility') || email.contains('hospital') || 
        email.contains('clinic') || email.startsWith('facility@')) {
      detectedRole = 'facility';
      route = '/facility_dashboard';
    } else if (email == 'admin@lifecare.com' || email == 'admin@yourdomain.com') {
      detectedRole = 'admin';
      route = '/admin_dashboard';
    } else if (email.contains('doctor') || email.contains('dr.') || email.startsWith('doctor@')) {
      detectedRole = 'doctor';
      route = '/doctor_dashboard';
    } else if (email.contains('chw') || email.startsWith('chw@')) {
      detectedRole = 'chw';
      route = '/chw_dashboard';
    }
    // Print detected role for debugging
    print('[AppRouter] Raw email: "$rawEmail", normalized: "$email"');
    print('[AppRouter] Detected role: $detectedRole, routing to: $route');
    return route;
  }
}
