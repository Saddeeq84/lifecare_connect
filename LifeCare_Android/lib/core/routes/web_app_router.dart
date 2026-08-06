// ignore_for_file: avoid_print

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/screens/web_login_screen.dart';
import '../../features/auth/presentation/screens/privacy_screen.dart'
    deferred as privacy;
import '../../features/patient/presentation/screens/login_patient.dart'
    deferred as patient_login;
import '../../features/chw/presentation/screens/chw_login_screen.dart'
    deferred as chw_login;
import '../../features/doctor/presentation/screens/login_doctor.dart'
    deferred as doctor_login;
import '../../features/facility/presentation/screens/facility_login_screen.dart'
    deferred as facility_login;
import '../../features/facility/presentation/screens/service_provider_login_screen.dart'
    deferred as service_provider_login;
import '../../features/patient/presentation/screens/login_patient_register.dart'
    deferred as patient_register;
import '../../features/chw/presentation/screens/chw_create_account.dart'
    deferred as chw_register;
import '../../features/doctor/presentation/screens/doctor_create_account.dart'
    deferred as doctor_register;
import '../../features/facility/presentation/screens/owner_register_facility_screen.dart'
    deferred as facility_register;
import '../../features/facility/presentation/screens/verify_email_screen.dart'
    deferred as verify_email;
import '../../features/facility/presentation/screens/staff_password_setup_screen.dart'
    deferred as staff_setup;
import '../../features/public/presentation/screens/public_provider_catalog_screen.dart'
    deferred as catalog;
import '../../features/shared/presentation/screens/public_profile_screen.dart'
    deferred as public_profile;

import '../../features/admin/presentation/screens/admin_dashboard.dart'
    deferred as admin_dashboard;
import '../../features/admin/presentation/screens/approvals_screen.dart'
    deferred as admin_approvals;
import '../../features/admin/presentation/screens/admin_help_videos_screen.dart'
    deferred as admin_help_videos;
import '../../features/admin/presentation/screens/admin_register_facility_screen.dart'
    deferred as admin_register_facility;
import '../../features/admin/presentation/screens/admin_training_help_resources_menu_screen.dart'
    deferred as admin_training_help;
import '../../features/admin/presentation/screens/admin_reports_analytics_screen.dart'
    deferred as admin_reports;
import '../../features/admin/presentation/screens/admin_analytics_screen.dart'
    deferred as admin_analytics;
import '../../features/admin/presentation/screens/admin_training_screen.dart'
    deferred as admin_training;
import '../../features/admin/presentation/screens/admin_settings_screen.dart'
    deferred as admin_settings;
import '../../features/admin/presentation/screens/admin_finance_screen.dart'
    deferred as admin_finance;
import '../../features/admin/presentation/screens/admin_users_management_screen.dart'
    deferred as admin_users;
import '../../features/admin/presentation/screens/admin_training_analytics_screen.dart'
    deferred as admin_training_analytics;
import '../../features/admin/presentation/screens/admin_analytics_hub_screen.dart'
    deferred as admin_analytics_hub;
import '../../features/doctor/presentation/screens/doctor_dashboard.dart'
    deferred as doctor_dashboard;
import '../../features/doctor/presentation/screens/doctor_settings_screen.dart'
    deferred as doctor_settings;
import '../../features/doctor/presentation/screens/doctor_profile_screen.dart'
    deferred as doctor_profile;
import '../../features/doctor/presentation/screens/doctor_patient_list_screen.dart'
    deferred as doctor_patients;
import '../../features/doctor/presentation/doctor_appointments_exports.dart'
    deferred as doctor_appointments;
import '../../features/doctor/presentation/screens/doctor_referrals_screen.dart'
    deferred as doctor_referrals;
import '../../features/doctor/presentation/screens/doctor_create_referral_screen.dart'
    deferred as doctor_create_referral;
import '../../features/doctor/presentation/screens/doctor_analytics_screen.dart'
    deferred as doctor_analytics;
import '../../features/doctor/presentation/screens/doctor_consultation_screen.dart'
    deferred as doctor_consultation;
import '../../features/doctor/presentation/screens/doctor_chw_consultations_screen.dart'
    deferred as doctor_chw_consultations;
import '../../features/doctor/presentation/screens/doctor_clinical_resources_screen.dart'
    deferred as doctor_resources;
import '../../features/chw/presentation/screens/chw_dashboard.dart'
    deferred as chw_dashboard;
import '../../features/chw/presentation/screens/patient_list_screen.dart'
    deferred as chw_patients;
import '../../features/chw/presentation/screens/chw_registered_patients_screen.dart'
    deferred as chw_registered_patients;
import '../../features/chw/presentation/screens/patient_registration_screen.dart'
    deferred as chw_register_patient;
import '../../features/chw/presentation/screens/chw_appointments_screen.dart'
    deferred as chw_appointments;
import '../../features/chw/presentation/screens/chw_referrals_screen.dart'
    deferred as chw_referrals;
import '../../features/chw/presentation/screens/chw_create_referral_screen.dart'
    deferred as chw_create_referral;
import '../../features/chw/presentation/screens/patient_health_records_screen.dart'
    deferred as chw_health_records;
import '../../features/chw/presentation/screens/chw_training_screen.dart'
    deferred as chw_training;
import '../../features/chw/presentation/screens/chw_take_courses_screen.dart'
    deferred as chw_take_courses;
import '../../features/chw/presentation/screens/chw_ask_ai_screen.dart'
    deferred as chw_ask_ai;
import '../../features/chw/presentation/screens/chw_profile_screen.dart'
    deferred as chw_profile;
import '../../features/chw/presentation/screens/chw_edit_profile_screen.dart'
    deferred as chw_settings;
import '../../features/chw/presentation/screens/chw_profile_edit_screen.dart'
    deferred as chw_edit_profile;
import '../../features/chw/presentation/screens/chw_consultation_screen.dart'
    deferred as chw_consultations;
import '../../features/chw/presentation/screens/chw_doctor_consultations_screen.dart'
    deferred as chw_doctor_consultations;
import '../../features/chw/presentation/screens/chw_analytics_screen.dart'
    deferred as chw_analytics;
import '../../features/chw/presentation/screens/chw_notifications_screen.dart'
    deferred as chw_notifications;
import '../../features/chw/presentation/screens/chw_consultation_details_screen.dart'
    deferred as chw_consultation_details;
import '../../features/chw/presentation/screens/chw_anc_pnc_consultation_screen.dart'
    deferred as chw_anc_pnc;
import '../../features/patient/presentation/screens/patient_dashboard.dart'
    deferred as patient_dashboard;
import '../../features/patient/presentation/screens/patient_appointment_screen.dart'
    deferred as patient_appointments;
import '../../features/patient/presentation/screens/patient_consultations_screen.dart'
    deferred as patient_consultations;
import '../../features/patient/presentation/screens/patient_referrals_screen.dart'
    deferred as patient_referrals;
import '../../features/patient/presentation/screens/patient_wallet_screen.dart'
    deferred as patient_wallet;
import '../../features/patient/presentation/screens/patient_pharmacy_cart_screen.dart'
    deferred as patient_pharmacy_cart;
import '../../features/facility/presentation/screens/facility_dashboard.dart'
    deferred as facility_dashboard;
import '../../features/facility/presentation/screens/facility_procurement_main_screen.dart'
    deferred as facility_procurement;

import '../../features/facility/presentation/screens/opd_dashboard_screen.dart'
    deferred as opd_dashboard;
import '../../features/facility/presentation/screens/nursing_dashboard_screen.dart'
    deferred as nursing_dashboard;
import '../../features/facility/presentation/screens/medical_records_dashboard_screen.dart'
    deferred as medical_records_dashboard;
import '../../features/facility/presentation/screens/pharmacy_dashboard_screen.dart'
    deferred as pharmacy_dashboard;
import '../../features/facility/presentation/screens/laboratory_dashboard_screen.dart'
    deferred as laboratory_dashboard;
import '../../features/facility/presentation/screens/radiology_dashboard_screen.dart'
    deferred as radiology_dashboard;
import '../../features/facility/presentation/screens/public_health_dashboard_screen.dart'
    deferred as public_health_dashboard;
import '../../features/facility/presentation/screens/emergency_dashboard_screen.dart'
    deferred as emergency_dashboard;
import '../../features/facility/presentation/screens/specialist_dashboard_screen.dart'
    deferred as specialist_dashboard;
import '../../features/facility/presentation/screens/ward_dashboard_screen.dart'
    deferred as ward_dashboard;
import '../../features/facility/presentation/screens/ward_rounds_screen.dart'
    deferred as ward_rounds;
import '../../features/facility/presentation/screens/ward_discharges_screen.dart'
    deferred as ward_discharges;
import '../../features/facility/presentation/screens/ward_vital_signs_screen.dart'
    deferred as ward_vital_signs;
import '../../features/facility/presentation/screens/ward_medications_screen.dart'
    deferred as ward_medications;
import '../../features/facility/presentation/screens/ward_admission_billing_screen.dart'
    deferred as ward_admission_billing;
import '../../features/facility/presentation/screens/immunization_management_screen.dart'
    deferred as immunization_management;
import '../../features/facility/presentation/screens/environmental_surveillance_screen.dart'
    deferred as environmental_surveillance;
import '../../features/facility/presentation/screens/disease_surveillance_screen.dart'
    deferred as disease_surveillance;
import '../../features/facility/presentation/screens/infection_prevention_control_screen.dart'
    deferred as infection_prevention_control;
import '../../features/facility/presentation/screens/outbreak_investigation_screen.dart'
    deferred as outbreak_investigation;
import '../../features/facility/presentation/screens/health_education_screen.dart'
    deferred as health_education;
import '../../features/facility/presentation/screens/health_outreach_screen.dart'
    deferred as health_outreach;
import '../../features/patient/presentation/screens/comprehensive_book_appointment_screen.dart'
    deferred as book_appointment;
import '../../features/shared/presentation/screens/training_materials_screen.dart'
    deferred as training_materials;
import '../../features/shared/presentation/screens/messages_screen.dart'
    deferred as messages;
import '../../features/shared/presentation/screens/new_conversation_screen.dart'
    deferred as new_conversation;
import '../../features/shared/presentation/screens/chat_screen.dart'
    deferred as chat;

class AppRouter {
  static GoRouter get router => _router;

  static final _router = GoRouter(
    redirect: _redirect,
    redirectLimit: 5,
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const WebLoginScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) =>
            _deferred(privacy.loadLibrary, (_) => privacy.PrivacyScreen()),
      ),
      GoRoute(
        path: '/login/patient',
        name: 'login-patient',
        builder: (context, state) => _deferred(
          patient_login.loadLibrary,
          (_) => patient_login.LoginPatient(),
        ),
      ),
      GoRoute(
        path: '/login/chw',
        name: 'login-chw',
        builder: (context, state) =>
            _deferred(chw_login.loadLibrary, (_) => chw_login.CHWLoginScreen()),
      ),
      GoRoute(
        path: '/login/doctor',
        name: 'login-doctor',
        builder: (context, state) => _deferred(
          doctor_login.loadLibrary,
          (_) => doctor_login.LoginDoctorScreen(),
        ),
      ),
      GoRoute(
        path: '/login/facility',
        name: 'login-facility',
        builder: (context, state) => _deferred(
          facility_login.loadLibrary,
          (_) => facility_login.FacilityLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/login/service-provider',
        name: 'login-service-provider',
        builder: (context, state) => _deferred(
          service_provider_login.loadLibrary,
          (_) => service_provider_login.ServiceProviderLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/service_provider_login',
        name: 'service-provider-login',
        redirect: (_, __) => '/login/service-provider',
      ),
      GoRoute(
        path: '/register/patient',
        name: 'register-patient',
        builder: (context, state) => _deferred(
          patient_register.loadLibrary,
          (_) => patient_register.PatientRegisterScreen(),
        ),
      ),
      GoRoute(path: '/signup', redirect: (_, __) => '/register/patient'),
      GoRoute(
        path: '/register/chw',
        name: 'register-chw',
        builder: (context, state) => _deferred(
          chw_register.loadLibrary,
          (_) => chw_register.CHWCreateAccountScreen(),
        ),
      ),
      GoRoute(
        path: '/register/doctor',
        name: 'register-doctor',
        builder: (context, state) => _deferred(
          doctor_register.loadLibrary,
          (_) => doctor_register.DoctorCreateAccountScreen(),
        ),
      ),
      GoRoute(
        path: '/register/facility',
        name: 'register-facility',
        builder: (context, state) => _deferred(
          facility_register.loadLibrary,
          (_) => facility_register.OwnerRegisterFacilityScreen(),
        ),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final collection = state.uri.queryParameters['collection'];
          final docId = state.uri.queryParameters['docId'];
          if (collection == null || docId == null) {
            Future.microtask(() => context.go('/login'));
            return const _RouteLoading();
          }
          return _deferred(
            verify_email.loadLibrary,
            (_) => verify_email.VerifyEmailScreen(
              collection: collection,
              docId: docId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/staff-setup',
        name: 'staff-setup',
        builder: (context, state) {
          final staffId = state.uri.queryParameters['staffId'];
          if (staffId == null || staffId.isEmpty) {
            Future.microtask(() => context.go('/login'));
            return const _RouteLoading();
          }
          return _deferred(
            staff_setup.loadLibrary,
            (_) => staff_setup.StaffPasswordSetupScreen(staffId: staffId),
          );
        },
      ),
      GoRoute(
        path: '/catalog/:providerId',
        name: 'provider-catalog',
        builder: (context, state) {
          final providerId = state.pathParameters['providerId'] ?? '';
          return _deferred(
            catalog.loadLibrary,
            (_) => catalog.PublicProviderCatalogScreen(providerId: providerId),
          );
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        name: 'public-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final returnTo = state.uri.queryParameters['returnTo'];
          return _deferred(
            public_profile.loadLibrary,
            (_) => public_profile.PublicProfileScreen(
              userId: userId,
              returnTo: returnTo,
            ),
          );
        },
      ),
      GoRoute(
        path: '/patientMessaging',
        name: 'patient-messaging',
        builder: (context, state) =>
            _deferred(messages.loadLibrary, (_) => messages.MessagesScreen()),
      ),
      GoRoute(
        path: '/admin_dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => _deferred(
          admin_dashboard.loadLibrary,
          (_) => admin_dashboard.AdminDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'approvals',
            name: 'admin-approvals',
            builder: (context, state) => _deferred(
              admin_approvals.loadLibrary,
              (_) => admin_approvals.ApprovalsScreen(),
            ),
          ),
          GoRoute(
            path: 'register_facility',
            name: 'admin-register-facility',
            builder: (context, state) => _deferred(
              admin_register_facility.loadLibrary,
              (_) => admin_register_facility.AdminRegisterFacilityScreen(),
            ),
          ),
          GoRoute(
            path: 'upload_training',
            name: 'admin-upload-training',
            builder: (context, state) => _deferred(
              admin_training_help.loadLibrary,
              (_) => admin_training_help.AdminTrainingHelpResourcesMenuScreen(),
            ),
          ),
          GoRoute(
            path: 'help_videos',
            name: 'admin-help-videos',
            builder: (context, state) => _deferred(
              admin_help_videos.loadLibrary,
              (_) => admin_help_videos.AdminHelpVideosScreen(),
            ),
          ),
          GoRoute(
            path: 'messages',
            name: 'admin-messages',
            builder: (context, state) => _deferred(
              messages.loadLibrary,
              (_) => messages.MessagesScreen(),
            ),
          ),
          GoRoute(
            path: 'reports_analytics',
            name: 'admin-reports-analytics',
            builder: (context, state) => _deferred(
              admin_reports.loadLibrary,
              (_) => admin_reports.AdminReportsAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: 'analytics',
            name: 'admin-analytics',
            builder: (context, state) => _deferred(
              admin_analytics.loadLibrary,
              (_) => admin_analytics.AdminAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: 'training',
            name: 'admin-training',
            builder: (context, state) => _deferred(
              admin_training.loadLibrary,
              (_) => admin_training.AdminTrainingScreen(),
            ),
          ),
          GoRoute(
            path: 'settings',
            name: 'admin-settings',
            builder: (context, state) => _deferred(
              admin_settings.loadLibrary,
              (_) => admin_settings.AdminSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'finance',
            name: 'admin-finance',
            builder: (context, state) => _deferred(
              admin_finance.loadLibrary,
              (_) => admin_finance.AdminFinanceScreen(),
            ),
          ),
          GoRoute(
            path: 'users_management',
            name: 'admin-users-management',
            builder: (context, state) => _deferred(
              admin_users.loadLibrary,
              (_) => admin_users.AdminUsersManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'training_analytics',
            name: 'admin-training-analytics',
            builder: (context, state) => _deferred(
              admin_training_analytics.loadLibrary,
              (_) => admin_training_analytics.AdminTrainingAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: 'analytics_hub',
            name: 'admin-analytics-hub',
            builder: (context, state) => _deferred(
              admin_analytics_hub.loadLibrary,
              (_) => admin_analytics_hub.AdminAnalyticsHubScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/doctor_dashboard',
        name: 'doctor-dashboard',
        builder: (context, state) => _deferred(
          doctor_dashboard.loadLibrary,
          (_) => doctor_dashboard.DoctorDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'doctor-settings',
            builder: (context, state) => _deferred(
              doctor_settings.loadLibrary,
              (_) => doctor_settings.DoctorSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'profile',
            name: 'doctor-profile',
            builder: (context, state) => _deferred(
              doctor_profile.loadLibrary,
              (_) => doctor_profile.DoctorProfileScreen(),
            ),
          ),
          GoRoute(
            path: 'patients',
            name: 'doctor-patients',
            builder: (context, state) => _deferred(
              doctor_patients.loadLibrary,
              (_) => doctor_patients.DoctorPatientListScreen(),
            ),
          ),
          GoRoute(
            path: 'messages',
            name: 'doctor-messages',
            builder: (context, state) => _deferred(
              messages.loadLibrary,
              (_) => messages.MessagesScreen(),
            ),
          ),
          GoRoute(
            path: 'appointments',
            name: 'doctor-appointments',
            builder: (context, state) {
              final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
              return _deferred(
                doctor_appointments.loadLibrary,
                (_) => doctor_appointments.DoctorAppointmentsTabView(
                  userId: userId,
                ),
              );
            },
          ),
          GoRoute(
            path: 'referrals',
            name: 'doctor-referrals',
            builder: (context, state) => _deferred(
              doctor_referrals.loadLibrary,
              (_) => doctor_referrals.DoctorReferralsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create_referral',
                name: 'doctor-create-referral',
                builder: (context, state) => _deferred(
                  doctor_create_referral.loadLibrary,
                  (_) => doctor_create_referral.DoctorCreateReferralScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'analytics',
            name: 'doctor-analytics',
            builder: (context, state) => _deferred(
              doctor_analytics.loadLibrary,
              (_) => doctor_analytics.DoctorAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: 'consultation',
            name: 'doctor-consultation',
            builder: (context, state) => _deferred(
              doctor_consultation.loadLibrary,
              (_) => doctor_consultation.DoctorConsultationScreen(),
            ),
          ),
          GoRoute(
            path: 'chw_consultations',
            name: 'doctor-chw-consultations',
            builder: (context, state) => _deferred(
              doctor_chw_consultations.loadLibrary,
              (_) => doctor_chw_consultations.DoctorCHWConsultationsScreen(),
            ),
          ),
          GoRoute(
            path: 'take_course',
            name: 'doctor-take-course',
            builder: (context, state) => _deferred(
              chw_take_courses.loadLibrary,
              (_) =>
                  chw_take_courses.CHWTakeCoursesScreen(learnerRole: 'doctor'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/doctor_resources',
        name: 'doctor-resources',
        builder: (context, state) => _deferred(
          doctor_resources.loadLibrary,
          (_) => doctor_resources.DoctorClinicalResourcesScreen(),
        ),
      ),
      GoRoute(
        path: '/chw_dashboard',
        name: 'chw-dashboard',
        builder: (context, state) => _deferred(
          chw_dashboard.loadLibrary,
          (_) => chw_dashboard.CHWDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'patients',
            name: 'chw-patients',
            builder: (context, state) => _deferred(
              chw_patients.loadLibrary,
              (_) => chw_patients.ChwPatientListScreen(),
            ),
          ),
          GoRoute(
            path: 'my_patients',
            name: 'chw-my-patients',
            builder: (context, state) => _deferred(
              chw_registered_patients.loadLibrary,
              (_) => chw_registered_patients.CHWRegisteredPatientsScreen(),
            ),
          ),
          GoRoute(
            path: 'register_patient',
            name: 'chw-register-patient',
            builder: (context, state) => _deferred(
              chw_register_patient.loadLibrary,
              (_) =>
                  chw_register_patient.PatientRegistrationScreen(isCHW: true),
            ),
          ),
          GoRoute(
            path: 'appointments',
            name: 'chw-appointments',
            builder: (context, state) => _deferred(
              chw_appointments.loadLibrary,
              (_) => chw_appointments.CHWAppointmentsScreen(),
            ),
          ),
          GoRoute(
            path: 'regular-consultations',
            name: 'chw-regular-consultations',
            builder: (context, state) => _deferred(
              chw_appointments.loadLibrary,
              (_) => chw_appointments.CHWAppointmentsScreen(initialTab: 1),
            ),
          ),
          GoRoute(
            path: 'referrals',
            name: 'chw-referrals',
            builder: (context, state) => _deferred(
              chw_referrals.loadLibrary,
              (_) => chw_referrals.CHWReferralsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                name: 'chw-create-referral',
                builder: (context, state) => _deferred(
                  chw_create_referral.loadLibrary,
                  (_) => chw_create_referral.CHWCreateReferralScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'messages',
            name: 'chw-messages',
            builder: (context, state) => _deferred(
              messages.loadLibrary,
              (_) => messages.MessagesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'chw-new-conversation',
                builder: (context, state) => _deferred(
                  new_conversation.loadLibrary,
                  (_) => new_conversation.NewConversationScreen(),
                ),
              ),
              GoRoute(
                path: 'chat/:conversationId',
                name: 'chw-chat',
                builder: (context, state) {
                  final conversationId =
                      state.pathParameters['conversationId'] ?? '';
                  final extra = state.extra as Map<String, dynamic>?;
                  return _deferred(
                    chat.loadLibrary,
                    (_) => chat.ChatScreen(
                      conversationId: conversationId,
                      otherParticipantName:
                          extra?['otherParticipantName'] ?? 'Unknown',
                      otherParticipantRole:
                          extra?['otherParticipantRole'] ?? 'USER',
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'notifications',
            name: 'chw-notifications',
            builder: (context, state) => _deferred(
              chw_notifications.loadLibrary,
              (_) => chw_notifications.CHWNotificationsScreen(),
            ),
          ),
          GoRoute(
            path: 'patient_health_records',
            name: 'chw-patient-health-records',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return _deferred(
                chw_health_records.loadLibrary,
                (_) => chw_health_records.PatientHealthRecordsScreen(
                  patientId: extra?['patientId'] ?? '',
                  patientName: extra?['patientName'] ?? 'Unknown Patient',
                ),
              );
            },
          ),
          GoRoute(
            path: 'training',
            name: 'chw-training',
            builder: (context, state) => _deferred(
              chw_training.loadLibrary,
              (_) => chw_training.CHWTrainingScreen(),
            ),
          ),
          GoRoute(
            path: 'take_course',
            name: 'chw-take-course',
            builder: (context, state) => _deferred(
              chw_take_courses.loadLibrary,
              (_) => chw_take_courses.CHWTakeCoursesScreen(),
            ),
          ),
          GoRoute(
            path: 'ask_ai',
            name: 'chw-ask-ai',
            builder: (context, state) => _deferred(
              chw_ask_ai.loadLibrary,
              (_) => chw_ask_ai.CHWAskAIScreen(),
            ),
          ),
          GoRoute(
            path: 'profile',
            name: 'chw-profile',
            builder: (context, state) => _deferred(
              chw_profile.loadLibrary,
              (_) => chw_profile.CHWProfileScreen(),
            ),
          ),
          GoRoute(
            path: 'settings',
            name: 'chw-settings',
            builder: (context, state) => _deferred(
              chw_settings.loadLibrary,
              (_) => chw_settings.CHWEditProfileScreen(),
            ),
          ),
          GoRoute(
            path: 'edit-profile',
            name: 'chw-edit-profile',
            builder: (context, state) => _deferred(
              chw_edit_profile.loadLibrary,
              (_) => chw_edit_profile.CHWProfileEditScreen(),
            ),
          ),
          GoRoute(
            path: 'consultations',
            name: 'chw-consultations',
            builder: (context, state) => _deferred(
              chw_consultations.loadLibrary,
              (_) => chw_consultations.CHWConsultationScreen(),
            ),
          ),
          GoRoute(
            path: 'doctor_consultations',
            name: 'chw-doctor-consultations',
            builder: (context, state) => _deferred(
              chw_doctor_consultations.loadLibrary,
              (_) => chw_doctor_consultations.CHWDoctorConsultationsScreen(),
            ),
          ),
          GoRoute(
            path: 'analytics',
            name: 'chw-analytics',
            builder: (context, state) => _deferred(
              chw_analytics.loadLibrary,
              (_) => chw_analytics.CHWAnalyticsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/patient_dashboard',
        name: 'patient-dashboard',
        builder: (context, state) => _deferred(
          patient_dashboard.loadLibrary,
          (_) => patient_dashboard.PatientDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'appointments',
            name: 'patient-appointments',
            builder: (context, state) => _deferred(
              patient_appointments.loadLibrary,
              (_) => patient_appointments.PatientAppointmentsScreen(),
            ),
          ),
          GoRoute(
            path: 'consultations',
            name: 'patient-consultations',
            builder: (context, state) => _deferred(
              patient_consultations.loadLibrary,
              (_) => patient_consultations.PatientConsultationsScreen(),
            ),
          ),
          GoRoute(
            path: 'referrals',
            name: 'patient-referrals',
            builder: (context, state) => _deferred(
              patient_referrals.loadLibrary,
              (_) => patient_referrals.PatientReferralsScreen(),
            ),
          ),
          GoRoute(
            path: 'messages',
            name: 'patient-messages',
            builder: (context, state) => _deferred(
              messages.loadLibrary,
              (_) => messages.MessagesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'patient-new-conversation',
                builder: (context, state) => _deferred(
                  new_conversation.loadLibrary,
                  (_) => new_conversation.NewConversationScreen(),
                ),
              ),
              GoRoute(
                path: 'chat/:conversationId',
                name: 'patient-chat',
                builder: (context, state) {
                  final conversationId =
                      state.pathParameters['conversationId'] ?? '';
                  final extra = state.extra as Map<String, dynamic>?;
                  return _deferred(
                    chat.loadLibrary,
                    (_) => chat.ChatScreen(
                      conversationId: conversationId,
                      otherParticipantName:
                          extra?['otherParticipantName'] ?? 'Unknown',
                      otherParticipantRole:
                          extra?['otherParticipantRole'] ?? 'USER',
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'training',
            name: 'patient-training',
            builder: (context, state) => _deferred(
              training_materials.loadLibrary,
              (_) => training_materials.TrainingMaterialsScreen(
                userRole: 'patient',
              ),
            ),
          ),
          GoRoute(
            path: 'pharmacy',
            name: 'patient-pharmacy',
            builder: (context, state) {
              final providerId = state.uri.queryParameters['providerId'] ?? '';
              return _deferred(
                patient_pharmacy_cart.loadLibrary,
                (_) => patient_pharmacy_cart.PatientPharmacyCartScreen(
                  facilityId: providerId,
                  facilityData: const {},
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/patient-wallet',
        name: 'patient-wallet',
        builder: (context, state) => _deferred(
          patient_wallet.loadLibrary,
          (_) => patient_wallet.PatientWalletScreen(),
        ),
      ),
      GoRoute(
        path: '/facility_dashboard',
        name: 'facility-dashboard',
        builder: (context, state) => _deferred(
          facility_dashboard.loadLibrary,
          (_) => facility_dashboard.FacilityDashboard(),
        ),
      ),
      GoRoute(
        path: '/service_provider_dashboard',
        name: 'service-provider-dashboard',
        builder: (context, state) => _deferred(
          facility_dashboard.loadLibrary,
          (_) => facility_dashboard.FacilityDashboard(),
        ),
      ),
      GoRoute(
        path: '/facility_procurement',
        name: 'facility-procurement',
        builder: (context, state) => _deferred(
          facility_procurement.loadLibrary,
          (_) => facility_procurement.FacilityProcurementMainScreen(),
        ),
      ),
      _departmentRoute(
        path: '/opd_dashboard',
        name: 'opd-dashboard',
        loadLibrary: opd_dashboard.loadLibrary,
        builder: (data) => opd_dashboard.OPDDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          doctorId: data['userId'] ?? '',
          doctorName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/nursing_dashboard',
        name: 'nursing-dashboard',
        loadLibrary: nursing_dashboard.loadLibrary,
        builder: (data) => nursing_dashboard.NursingDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/medical_records_dashboard',
        name: 'medical-records-dashboard',
        loadLibrary: medical_records_dashboard.loadLibrary,
        builder: (data) =>
            medical_records_dashboard.MedicalRecordsDashboardScreen(
              facilityId: data['facilityId'] ?? '',
              facilityName: data['facilityName'] ?? '',
              staffId: data['userId'] ?? '',
              staffName: data['userName'] ?? '',
            ),
      ),
      _departmentRoute(
        path: '/pharmacy_dashboard',
        name: 'pharmacy-dashboard',
        loadLibrary: pharmacy_dashboard.loadLibrary,
        builder: (data) => pharmacy_dashboard.PharmacyDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/laboratory_dashboard',
        name: 'laboratory-dashboard',
        loadLibrary: laboratory_dashboard.loadLibrary,
        builder: (data) => laboratory_dashboard.LaboratoryDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/radiology_dashboard',
        name: 'radiology-dashboard',
        loadLibrary: radiology_dashboard.loadLibrary,
        builder: (data) => radiology_dashboard.RadiologyDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/public_health_dashboard',
        name: 'public-health-dashboard',
        loadLibrary: public_health_dashboard.loadLibrary,
        builder: (data) => public_health_dashboard.PublicHealthDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/emergency_dashboard',
        name: 'emergency-dashboard',
        loadLibrary: emergency_dashboard.loadLibrary,
        builder: (data) => emergency_dashboard.EmergencyDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          staffId: data['userId'] ?? '',
          staffName: data['userName'] ?? '',
        ),
      ),
      _departmentRoute(
        path: '/specialist_dashboard',
        name: 'specialist-dashboard',
        loadLibrary: specialist_dashboard.loadLibrary,
        builder: (data) => specialist_dashboard.SpecialistDashboardScreen(
          facilityId: data['facilityId'] ?? '',
          facilityName: data['facilityName'] ?? '',
          doctorId: data['userId'] ?? '',
          doctorName: data['userName'] ?? '',
        ),
      ),
      GoRoute(
        path: '/ward_dashboard',
        name: 'ward-dashboard',
        builder: (context, state) {
          final wardId = state.uri.queryParameters['wardId'];
          return _deferredWithUserData(
            ward_dashboard.loadLibrary,
            (data) => ward_dashboard.WardDashboardScreen(
              facilityId: data['facilityId'] ?? '',
              facilityName: data['facilityName'] ?? '',
              staffId: data['userId'] ?? '',
              staffName: data['userName'] ?? '',
              wardId: wardId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ward_rounds',
        name: 'ward-rounds',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            ward_rounds.loadLibrary,
            (_) => ward_rounds.WardRoundsScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
              excludeEmergencyAdmissions:
                  extra?['excludeEmergencyAdmissions'] ?? false,
              filterByEmergency: extra?['filterByEmergency'] ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ward_discharges',
        name: 'ward-discharges',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            ward_discharges.loadLibrary,
            (_) => ward_discharges.WardDischargesScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
              excludeEmergencyAdmissions:
                  extra?['excludeEmergencyAdmissions'] ?? false,
              filterByEmergency: extra?['filterByEmergency'] ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ward_vital_signs',
        name: 'ward-vital-signs',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            ward_vital_signs.loadLibrary,
            (_) => ward_vital_signs.WardVitalSignsScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
              excludeEmergencyAdmissions:
                  extra?['excludeEmergencyAdmissions'] ?? false,
              filterByEmergency: extra?['filterByEmergency'] ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ward_medications',
        name: 'ward-medications',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            ward_medications.loadLibrary,
            (_) => ward_medications.WardMedicationsScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
              excludeEmergencyAdmissions:
                  extra?['excludeEmergencyAdmissions'] ?? false,
              filterByEmergency: extra?['filterByEmergency'] ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/ward_admission_billing',
        name: 'ward-admission-billing',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            ward_admission_billing.loadLibrary,
            (_) => ward_admission_billing.WardAdmissionBillingScreen(
              admissionId: extra?['admissionId'] ?? '',
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/immunization_management',
        name: 'immunization-management',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            immunization_management.loadLibrary,
            (_) => immunization_management.ImmunizationManagementScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/environmental_surveillance',
        name: 'environmental-surveillance',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            environmental_surveillance.loadLibrary,
            (_) => environmental_surveillance.EnvironmentalSurveillanceScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/disease_surveillance',
        name: 'disease-surveillance',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            disease_surveillance.loadLibrary,
            (_) => disease_surveillance.DiseaseSurveillanceScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/infection_prevention_control',
        name: 'infection-prevention-control',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return _deferredWithUserData(
              infection_prevention_control.loadLibrary,
              (data) =>
                  infection_prevention_control.InfectionPreventionControlScreen(
                    facilityId: data['facilityId'] ?? '',
                    facilityName: data['facilityName'] ?? '',
                    staffId: data['userId'] ?? '',
                    staffName: data['userName'] ?? '',
                  ),
            );
          }
          return _deferred(
            infection_prevention_control.loadLibrary,
            (_) =>
                infection_prevention_control.InfectionPreventionControlScreen(
                  facilityId: extra['facilityId'] ?? '',
                  facilityName: extra['facilityName'] ?? '',
                  staffId: extra['staffId'] ?? '',
                  staffName: extra['staffName'] ?? '',
                  initialTabIndex: extra['initialTabIndex'] ?? 0,
                ),
          );
        },
      ),
      GoRoute(
        path: '/outbreak_investigation',
        name: 'outbreak-investigation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            outbreak_investigation.loadLibrary,
            (_) => outbreak_investigation.OutbreakInvestigationScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/health_education',
        name: 'health-education',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            health_education.loadLibrary,
            (_) => health_education.HealthEducationScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/health_outreach',
        name: 'health-outreach',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            health_outreach.loadLibrary,
            (_) => health_outreach.HealthOutreachScreen(
              facilityId: extra?['facilityId'] ?? '',
              facilityName: extra?['facilityName'] ?? '',
              staffId: extra?['staffId'] ?? '',
              staffName: extra?['staffName'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/book_appointment',
        name: 'book-appointment',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _deferred(
            book_appointment.loadLibrary,
            (_) => book_appointment.ComprehensiveBookAppointmentScreen(
              preSelectedProvider: args['preSelectedProvider'],
              fromReferral: args['fromReferral'] ?? false,
            ),
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
          return _deferred(
            patient_pharmacy_cart.loadLibrary,
            (_) => patient_pharmacy_cart.PatientPharmacyCartScreen(
              facilityId: facilityId,
              facilityData: facilityData,
            ),
          );
        },
      ),
      GoRoute(
        path: '/training-materials',
        name: 'training-materials',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userRole = extra?['userRole'] ?? 'chw';
          return _deferred(
            training_materials.loadLibrary,
            (_) =>
                training_materials.TrainingMaterialsScreen(userRole: userRole),
          );
        },
      ),
      GoRoute(
        path: '/chw_anc_consultation_details',
        name: 'chw-anc-consultation-details',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final appointmentData = Map<String, dynamic>.from(
            extra?['appointmentData'] ?? {},
          );
          if (extra?['appointmentType'] != null) {
            appointmentData['appointmentType'] = extra?['appointmentType'];
          }
          return _deferred(
            chw_consultation_details.loadLibrary,
            (_) => chw_consultation_details.CHWConsultationDetailsScreen(
              appointmentId: extra?['appointmentId'] ?? '',
              patientId: extra?['patientId'] ?? '',
              patientName: extra?['patientName'] ?? '',
              appointmentData: appointmentData,
              isReadOnly: extra?['isReadOnly'] ?? false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/chw_anc_pnc_consultation',
        name: 'chw-anc-pnc-consultation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _deferred(
            chw_anc_pnc.loadLibrary,
            (_) => chw_anc_pnc.CHWAncPncConsultationScreen(
              appointmentId: extra?['appointmentId'] ?? '',
              patientId: extra?['patientId'] ?? '',
              patientName: extra?['patientName'] ?? '',
              appointmentType: extra?['appointmentType'] ?? 'ANC',
            ),
          );
        },
      ),
    ],
  );

  static FutureOr<String?> _redirect(context, state) async {
    final path = state.uri.path;

    if (path == '/privacy' ||
        path == '/login' ||
        path.startsWith('/staff-setup') ||
        path.startsWith('/verify-email') ||
        path.startsWith('/profile/') ||
        path.startsWith('/register/') ||
        path.startsWith('/login/') ||
        path.startsWith('/catalog/')) {
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final staffRole = prefs.getString('user_role');
    final userId = prefs.getString('user_id');

    final isStaffLoggedIn =
        (staffRole == 'facility_staff' ||
            staffRole == 'service_provider_staff') &&
        user == null;
    final isPhoneLoggedIn = userId != null && staffRole != null && user == null;
    final isLoggedIn = user != null || isStaffLoggedIn || isPhoneLoggedIn;

    if (path == '/') {
      if (!isLoggedIn) return '/login';
      if (user != null) return await _getRouteForUserRole(user);
      if (isStaffLoggedIn) return await _getRouteForStaffRole();
      if (isPhoneLoggedIn) return _getRouteForPhoneLogin(staffRole);
    }

    if (!isLoggedIn) {
      return '/login';
    }

    return null;
  }

  static Future<String> _getRouteForUserRole(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return '/login';

      final data = userDoc.data();
      final role = (data?['role'] as String?)?.toLowerCase();
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
      }

      final department =
          (data?['department'] as String?) ??
          (data?['profession'] as String?) ??
          '';
      if (_isIpcDashboardValue(data?['department'] as String?) ||
          _isIpcDashboardValue(data?['profession'] as String?)) {
        return '/infection_prevention_control';
      }
      return _routeForDepartment(department);
    } catch (e) {
      print('Error fetching web user role: $e');
      return '/login';
    }
  }

  static Future<String> _getRouteForStaffRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    if (userRole == 'service_provider_staff') {
      return '/service_provider_dashboard';
    }
    final department =
        prefs.getString('staff_department') ??
        prefs.getString('staff_profession') ??
        '';
    if (_isIpcDashboardValue(prefs.getString('staff_department')) ||
        _isIpcDashboardValue(prefs.getString('staff_profession'))) {
      return '/infection_prevention_control';
    }
    return _routeForDepartment(department);
  }

  static String _getRouteForPhoneLogin(String role) {
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
        return '/login';
    }
  }

  static String _routeForDepartment(String value) {
    final department = value.toLowerCase().trim();
    if (_isIpcDashboardValue(department)) {
      return '/infection_prevention_control';
    }
    if (department.contains('emergency')) return '/emergency_dashboard';
    if (department.contains('opd') || department.contains('out-patient')) {
      return '/opd_dashboard';
    }
    if (department.contains('specialist')) return '/specialist_dashboard';
    if (department.contains('nursing')) return '/nursing_dashboard';
    if (department.contains('medical records') ||
        department.contains('records')) {
      return '/medical_records_dashboard';
    }
    if (department.contains('pharmacy')) return '/pharmacy_dashboard';
    if (department.contains('laboratory') || department.contains('lab')) {
      return '/laboratory_dashboard';
    }
    if (department.contains('radiology') || department.contains('imaging')) {
      return '/radiology_dashboard';
    }
    if (department.contains('public health')) return '/public_health_dashboard';
    if (department.contains('ward') ||
        department.contains('ipd') ||
        department.contains('inpatient')) {
      return '/ward_dashboard';
    }
    return '/login';
  }

  static bool _isIpcDashboardValue(String? value) {
    final normalized = value?.toLowerCase().trim() ?? '';
    return normalized.startsWith('ipc ') ||
        normalized.contains('infection prevention') ||
        normalized.contains('infection control');
  }

  static Future<Map<String, dynamic>> _getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'facility_staff') {
        return {
          'userId': prefs.getString('staff_id') ?? '',
          'userName': prefs.getString('staff_name') ?? '',
          'facilityId': prefs.getString('facility_id') ?? '',
          'facilityName': prefs.getString('facility_name') ?? '',
          'profession': prefs.getString('staff_profession') ?? '',
        };
      }

      if (user == null) return {};

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? {};
      return {
        'userId': user.uid,
        'userName': data['name'] ?? data['fullName'] ?? '',
        'facilityId': data['facilityId'] ?? '',
        'facilityName': data['facilityName'] ?? '',
        'profession': data['profession'] ?? '',
      };
    } catch (e) {
      print('Error fetching web user data: $e');
      return {};
    }
  }
}

GoRoute _departmentRoute({
  required String path,
  required String name,
  required Future<void> Function() loadLibrary,
  required Widget Function(Map<String, dynamic> data) builder,
}) {
  return GoRoute(
    path: path,
    name: name,
    builder: (context, state) => _deferredWithUserData(loadLibrary, builder),
  );
}

Widget _deferred(
  Future<void> Function() loadLibrary,
  Widget Function(BuildContext context) builder,
) {
  return FutureBuilder<void>(
    future: loadLibrary(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _RouteLoading();
      }
      if (snapshot.hasError) {
        return _RouteError(error: snapshot.error);
      }
      return builder(context);
    },
  );
}

Widget _deferredWithUserData(
  Future<void> Function() loadLibrary,
  Widget Function(Map<String, dynamic> data) builder,
) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait([loadLibrary(), AppRouter._getUserData()]),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _RouteLoading();
      }
      if (snapshot.hasError) {
        return _RouteError(error: snapshot.error);
      }
      return builder(snapshot.data?[1] as Map<String, dynamic>? ?? {});
    },
  );
}

class _RouteLoading extends StatelessWidget {
  const _RouteLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load this page. Please refresh and try again.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
