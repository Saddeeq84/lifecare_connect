import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': _enTranslations,
    'ha': _haTranslations,
    'sw': _swTranslations,
    'fr': _frTranslations,
    'es': _esTranslations,
    'ig': _igTranslations,
    'yo': _yoTranslations,
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters for common strings
  String get appName => translate('app_name');
  String get login => translate('login');
  String get logout => translate('logout');
  String get email => translate('email');
  String get password => translate('password');
  String get phoneNumber => translate('phone_number');
  String get forgotPassword => translate('forgot_password');
  String get resetPassword => translate('reset_password');
  String get register => translate('register');
  String get fullName => translate('full_name');
  String get firstName => translate('first_name');
  String get lastName => translate('last_name');
  String get dateOfBirth => translate('date_of_birth');
  String get gender => translate('gender');
  String get male => translate('male');
  String get female => translate('female');
  String get address => translate('address');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get search => translate('search');
  String get settings => translate('settings');
  String get profile => translate('profile');
  String get notifications => translate('notifications');
  String get language => translate('language');
  String get selectLanguage => translate('select_language');

  // Dashboard
  String get dashboard => translate('dashboard');
  String get patients => translate('patients');
  String get appointments => translate('appointments');
  String get consultations => translate('consultations');
  String get referrals => translate('referrals');
  String get wallet => translate('wallet');
  String get analytics => translate('analytics');
  String get training => translate('training');
  String get education => translate('education');

  // Patient
  String get patientList => translate('patient_list');
  String get registerPatient => translate('register_patient');
  String get patientDetails => translate('patient_details');
  String get medicalHistory => translate('medical_history');
  String get vitals => translate('vitals');
  String get prescriptions => translate('prescriptions');
  String get labTests => translate('lab_tests');

  // Appointment
  String get bookAppointment => translate('book_appointment');
  String get appointmentDate => translate('appointment_date');
  String get appointmentTime => translate('appointment_time');
  String get appointmentType => translate('appointment_type');
  String get upcomingAppointments => translate('upcoming_appointments');
  String get pastAppointments => translate('past_appointments');
  String get cancelAppointment => translate('cancel_appointment');

  // Consultation
  String get chiefComplaint => translate('chief_complaint');
  String get symptoms => translate('symptoms');
  String get diagnosis => translate('diagnosis');
  String get treatment => translate('treatment');
  String get clinicalNotes => translate('clinical_notes');
  String get followUp => translate('follow_up');

  // AI Assistant
  String get aiAssistant => translate('ai_assistant');
  String get askAI => translate('ask_ai');
  String get aiThinking => translate('ai_thinking');
  String get typeMessage => translate('type_message');

  // Health conditions
  String get malaria => translate('malaria');
  String get diabetes => translate('diabetes');
  String get hypertension => translate('hypertension');
  String get fever => translate('fever');
  String get cough => translate('cough');
  String get headache => translate('headache');
  String get bodyPain => translate('body_pain');
  String get nausea => translate('nausea');
  String get vomiting => translate('vomiting');
  String get diarrhea => translate('diarrhea');

  // Messages
  String get success => translate('success');
  String get error => translate('error');
  String get warning => translate('warning');
  String get loading => translate('loading');
  String get noData => translate('no_data');
  String get retry => translate('retry');
  String get confirm => translate('confirm');

  // Time
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get tomorrow => translate('tomorrow');
  String get thisWeek => translate('this_week');
  String get thisMonth => translate('this_month');

  // Common actions
  String get viewDetails => translate('view_details');
  String get update => translate('update');
  String get submit => translate('submit');
  String get close => translate('close');
  String get back => translate('back');
  String get next => translate('next');
  String get previous => translate('previous');

  // Settings specific
  String get preferences => translate('preferences');
  String get preferredLanguage => translate('preferred_language');
  String get darkMode => translate('dark_mode');
  String get enableNotifications => translate('enable_notifications');
  String get pushNotifications => translate('push_notifications');
  String get emailNotifications => translate('email_notifications');
  String get smsNotifications => translate('sms_notifications');
  String get appearance => translate('appearance');
  String get accountActions => translate('account_actions');
  String get helpAndSupport => translate('help_and_support');
  String get serviceAgreement => translate('service_agreement');
  String get privacyPolicy => translate('privacy_policy');
  String get shareYourProfile => translate('share_your_profile');
  String get appPreferences => translate('app_preferences');
  String get legalAndSupport => translate('legal_and_support');
  String get theme => translate('theme');
  String get light => translate('light');
  String get dark => translate('dark');
  String get system => translate('system');
  String get changePassword => translate('change_password');
  String get signOut => translate('sign_out');
  String get deleteAccount => translate('delete_account');
  String get permanentlyDeleteAccount =>
      translate('permanently_delete_account');
  String get receiveNotificationsViaEmail =>
      translate('receive_notifications_via_email');
  String get receiveNotificationsViaSMS =>
      translate('receive_notifications_via_sms');
  String get choosePreferredTheme => translate('choose_preferred_theme');
  String get viewTermsOfService => translate('view_terms_of_service');
  String get viewPrivacyPolicy => translate('view_privacy_policy');
  String get getHelpAndSupport => translate('get_help_and_support');
  String get updateAccountPassword => translate('update_account_password');
  String get needHelpWithLifeCare => translate('need_help_with_lifecare');
  String get phone => translate('phone');
  String get hours => translate('hours');
  String get mondayToFriday => translate('monday_to_friday');
  String get commonIssues => translate('common_issues');
  String get loginProblems => translate('login_problems');
  String get bookingIssues => translate('booking_issues');
  String get emergencyServices => translate('emergency_services');
  String get changePasswordComingSoon =>
      translate('change_password_coming_soon');
  String get signOutComingSoon => translate('sign_out_coming_soon');
  String get requestAccountDeletion => translate('request_account_deletion');
  String get adminWillReview => translate('admin_will_review');
  String get youWillBeNotified => translate('you_will_be_notified');
  String get pendingWithdrawals => translate('pending_withdrawals');
  String get actionCannotBeUndone => translate('action_cannot_be_undone');
  String get submitDeletionRequest => translate('submit_deletion_request');
  String get deletionRequestSubmitted =>
      translate('deletion_request_submitted');
  String get failedToSubmitRequest => translate('failed_to_submit_request');
  String get pendingDeletionRequest => translate('pending_deletion_request');
  String get submittedOn => translate('submitted_on');
  String get reason => translate('reason');
  String get cancelRequest => translate('cancel_request');
  String get cancelRequestQuestion => translate('cancel_request_question');
  String get areYouSureCancelRequest =>
      translate('are_you_sure_cancel_request');
  String get no => translate('no');
  String get yes => translate('yes');
  String get yesCancelRequest => translate('yes_cancel_request');
  String get deletionRequestCancelled =>
      translate('deletion_request_cancelled');
  String get failedToCancelRequest => translate('failed_to_cancel_request');
  String get legalAndPrivacy => translate('legal_and_privacy');
  String get selected => translate('selected');
  String get adminApprovalRequired => translate('admin_approval_required');
  String get healthcareProviderDeletionNote =>
      translate('healthcare_provider_deletion_note');
  String get whatWillBeDeleted => translate('what_will_be_deleted');
  String get doctorProfileAndCredentials =>
      translate('doctor_profile_and_credentials');
  String get walletBalanceAndHistory => translate('wallet_balance_and_history');
  String get appointmentHistory => translate('appointment_history');
  String get medicalConsultationRecords =>
      translate('medical_consultation_records');
  String get patientReferralsAndReports =>
      translate('patient_referrals_and_reports');
  String get paymentAndWithdrawalHistory =>
      translate('payment_and_withdrawal_history');
  String get notificationsAndMessages =>
      translate('notifications_and_messages');
  String get accountSettingsAndPreferences =>
      translate('account_settings_and_preferences');
  String get importantNotes => translate('important_notes');
  String get reasonForDeletion => translate('reason_for_deletion');
  String get provideDeletionReason => translate('provide_deletion_reason');
  String get requestStatus => translate('request_status');
  String get pending => translate('pending');
  String get requestBeingReviewed => translate('request_being_reviewed');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en',
      'ha',
      'sw',
      'fr',
      'es',
      'ig',
      'yo',
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// English translations
const Map<String, String> _enTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Login',
  'logout': 'Logout',
  'email': 'Email',
  'password': 'Password',
  'phone_number': 'Phone Number',
  'forgot_password': 'Forgot Password?',
  'reset_password': 'Reset Password',
  'register': 'Register',
  'full_name': 'Full Name',
  'first_name': 'First Name',
  'last_name': 'Last Name',
  'date_of_birth': 'Date of Birth',
  'gender': 'Gender',
  'male': 'Male',
  'female': 'Female',
  'address': 'Address',
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'edit': 'Edit',
  'search': 'Search',
  'settings': 'Settings',
  'profile': 'Profile',
  'notifications': 'Notifications',
  'language': 'Language',
  'select_language': 'Select Language',

  'dashboard': 'Dashboard',
  'patients': 'Patients',
  'appointments': 'Appointments',
  'consultations': 'Consultations',
  'referrals': 'Referrals',
  'wallet': 'Wallet',
  'analytics': 'Analytics',
  'training': 'Training',
  'education': 'Education',

  'patient_list': 'Patient List',
  'register_patient': 'Register Patient',
  'patient_details': 'Patient Details',
  'medical_history': 'Medical History',
  'vitals': 'Vitals',
  'prescriptions': 'Prescriptions',
  'lab_tests': 'Lab Tests',

  'book_appointment': 'Book Appointment',
  'appointment_date': 'Appointment Date',
  'appointment_time': 'Appointment Time',
  'appointment_type': 'Appointment Type',
  'upcoming_appointments': 'Upcoming Appointments',
  'past_appointments': 'Past Appointments',
  'cancel_appointment': 'Cancel Appointment',

  'chief_complaint': 'Chief Complaint',
  'symptoms': 'Symptoms',
  'diagnosis': 'Diagnosis',
  'treatment': 'Treatment',
  'clinical_notes': 'Clinical Notes',
  'follow_up': 'Follow-up',

  'ai_assistant': 'AI Assistant',
  'ask_ai': 'Ask AI',
  'ai_thinking': 'AI is thinking...',
  'type_message': 'Type your message...',

  'malaria': 'Malaria',
  'diabetes': 'Diabetes',
  'hypertension': 'Hypertension',
  'fever': 'Fever',
  'cough': 'Cough',
  'headache': 'Headache',
  'body_pain': 'Body Pain',
  'nausea': 'Nausea',
  'vomiting': 'Vomiting',
  'diarrhea': 'Diarrhea',

  'success': 'Success',
  'error': 'Error',
  'warning': 'Warning',
  'loading': 'Loading...',
  'no_data': 'No data available',
  'retry': 'Retry',
  'confirm': 'Confirm',

  'today': 'Today',
  'yesterday': 'Yesterday',
  'tomorrow': 'Tomorrow',
  'this_week': 'This Week',
  'this_month': 'This Month',

  'view_details': 'View Details',
  'update': 'Update',
  'submit': 'Submit',
  'close': 'Close',
  'back': 'Back',
  'next': 'Next',
  'previous': 'Previous',

  // Settings
  'preferences': 'Preferences',
  'preferred_language': 'Preferred Language',
  'dark_mode': 'Dark Mode',
  'enable_notifications': 'Enable Notifications',
  'push_notifications': 'Push Notifications',
  'email_notifications': 'Email Notifications',
  'sms_notifications': 'SMS Notifications',
  'appearance': 'Appearance',
  'account_actions': 'Account Actions',
  'help_and_support': 'Help & Support',
  'service_agreement': 'Service Agreement',
  'privacy_policy': 'Privacy Policy',
  'share_your_profile': 'Share Your Profile',
  'app_preferences': 'App Preferences',
  'legal_and_support': 'Legal & Support',
  'selected': 'selected',

  // Additional Settings
  'theme': 'Theme',
  'light': 'Light',
  'dark': 'Dark',
  'system': 'System',
  'change_password': 'Change Password',
  'sign_out': 'Sign Out',
  'delete_account': 'Delete Account',
  'permanently_delete_account': 'Permanently delete your account',
  'receive_notifications_via_email': 'Receive notifications via email',
  'receive_notifications_via_sms': 'Receive notifications via SMS',
  'choose_preferred_theme': 'Choose your preferred theme',
  'view_terms_of_service': 'View terms of service and user agreement',
  'view_privacy_policy': 'View our privacy policy',
  'get_help_and_support': 'Get help and contact support',
  'update_account_password': 'Update your account password',
  'need_help_with_lifecare': 'Need help with LifeCare Connect?',
  'phone': 'Phone',
  'hours': 'Hours',
  'monday_to_friday': 'Monday - Friday, 8AM - 6PM',
  'common_issues': 'Common Issues',
  'login_problems': 'Login problems: Check internet connection',
  'booking_issues': 'Booking issues: Ensure all fields are filled',
  'emergency_services': 'Emergency services: Call 199 for immediate help',
  'change_password_coming_soon': 'Change password feature coming soon',
  'sign_out_coming_soon': 'Sign out feature coming soon',
  'request_account_deletion': 'Request Account Deletion',
  'admin_will_review': 'Admin will review your request within 48 hours',
  'you_will_be_notified': 'You will be notified once your request is processed',
  'pending_withdrawals':
      'Pending withdrawals will be processed before deletion',
  'action_cannot_be_undone': 'This action cannot be undone once approved',
  'submit_deletion_request': 'SUBMIT DELETION REQUEST',
  'deletion_request_submitted':
      '✅ Deletion request submitted successfully! Admin will review it shortly.',
  'failed_to_submit_request': 'Failed to submit request',
  'pending_deletion_request': 'Pending Deletion Request',
  'submitted_on': 'Submitted on',
  'reason': 'Reason',
  'cancel_request': 'Cancel Request',
  'cancel_request_question': 'Cancel Request?',
  'are_you_sure_cancel_request':
      'Are you sure you want to cancel your deletion request?',
  'no': 'No',
  'yes': 'Yes',
  'yes_cancel_request': 'Yes, Cancel',
  'deletion_request_cancelled': 'Deletion request cancelled',
  'failed_to_cancel_request': 'Failed to cancel request',
  'legal_and_privacy': 'Legal & Privacy',
  'admin_approval_required': 'ADMIN APPROVAL REQUIRED',
  'healthcare_provider_deletion_note':
      'As a healthcare provider, your account deletion requires administrator approval to ensure proper handling of medical records and patient data.',
  'what_will_be_deleted': 'What will be deleted:',
  'doctor_profile_and_credentials': 'Your doctor profile and credentials',
  'wallet_balance_and_history': 'Wallet balance and transaction history',
  'appointment_history': 'All appointment history and schedules',
  'medical_consultation_records': 'Medical consultation records',
  'patient_referrals_and_reports': 'Patient referrals and reports',
  'payment_and_withdrawal_history': 'Payment and withdrawal history',
  'notifications_and_messages': 'All notifications and messages',
  'account_settings_and_preferences': 'Account settings and preferences',
  'important_notes': 'Important Notes:',
  'reason_for_deletion': 'Reason for deletion (optional):',
  'provide_deletion_reason': 'Please provide a reason for account deletion',
  'request_status': 'Request Status',
  'pending': 'PENDING',
  'request_being_reviewed':
      'Your account deletion request is being reviewed by an administrator. You will be notified once it\'s processed.',
};

// Hausa translations
const Map<String, String> _haTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Shiga',
  'logout': 'Fita',
  'email': 'Imel',
  'password': 'Kalmar Sirri',
  'phone_number': 'Lambar Waya',
  'forgot_password': 'Ka Manta da Kalmar Sirri?',
  'reset_password': 'Sake Saita Kalmar Sirri',
  'register': 'Yi Rajista',
  'full_name': 'Cikakken Suna',
  'first_name': 'Sunan Farko',
  'last_name': 'Sunan Iyali',
  'date_of_birth': 'Ranar Haihuwa',
  'gender': 'Jinsi',
  'male': 'Namiji',
  'female': 'Mace',
  'address': 'Adireshi',
  'save': 'Ajiye',
  'cancel': 'Soke',
  'delete': 'Share',
  'edit': 'Gyara',
  'search': 'Bincika',
  'settings': 'Saitunan',
  'profile': 'Bayanan Sirri',
  'notifications': 'Sanarwa',
  'language': 'Harshe',
  'select_language': 'Zaɓi Harshe',

  'dashboard': 'Dashboard',
  'patients': 'Marasa Lafiya',
  'appointments': 'Alƙawura',
  'consultations': 'Shawarwari',
  'referrals': 'Tura Majiyyaci',
  'wallet': 'Jakar Kuɗi',
  'analytics': 'Bincike',
  'training': 'Horo',
  'education': 'Ilimi',

  'patient_list': 'Jerin Marasa Lafiya',
  'register_patient': 'Yi Rajistar Majiyyaci',
  'patient_details': 'Bayanan Majiyyaci',
  'medical_history': 'Tarihin Lafiya',
  'vitals': 'Ma\'aunin Lafiya',
  'prescriptions': 'Takardar Magani',
  'lab_tests': 'Gwajin Dakin Gwaje-gwaje',

  'book_appointment': 'Yi Alƙawari',
  'appointment_date': 'Ranar Alƙawari',
  'appointment_time': 'Lokacin Alƙawari',
  'appointment_type': 'Nau\'in Alƙawari',
  'upcoming_appointments': 'Alƙawuran Gaba',
  'past_appointments': 'Alƙawuran Da Suka Wuce',
  'cancel_appointment': 'Soke Alƙawari',

  'chief_complaint': 'Babban Koke',
  'symptoms': 'Alamomi',
  'diagnosis': 'Gano Cuta',
  'treatment': 'Magani',
  'clinical_notes': 'Bayanan Asibiti',
  'follow_up': 'Sake Dubawa',

  'ai_assistant': 'Mataimakin AI',
  'ask_ai': 'Tambayi AI',
  'ai_thinking': 'AI yana tunani...',
  'type_message': 'Rubuta saƙonka...',

  'malaria': 'Zazzabin Ciwo',
  'diabetes': 'Ciwon Sukari',
  'hypertension': 'Hawan Jini',
  'fever': 'Zazzabi',
  'cough': 'Tari',
  'headache': 'Ciwon Kai',
  'body_pain': 'Ciwon Jiki',
  'nausea': 'Tashin Zuciya',
  'vomiting': 'Amai',
  'diarrhea': 'Gudawa',

  'success': 'Nasara',
  'error': 'Kuskure',
  'warning': 'Gargaɗi',
  'loading': 'Ana ɗaukar nauyi...',
  'no_data': 'Babu bayanai',
  'retry': 'Sake Gwadawa',
  'confirm': 'Tabbatar',

  'today': 'Yau',
  'yesterday': 'Jiya',
  'tomorrow': 'Gobe',
  'this_week': 'Wannan Makon',
  'this_month': 'Wannan Watan',

  'view_details': 'Duba Cikakken Bayani',
  'update': 'Sabunta',
  'submit': 'Tura',
  'close': 'Rufe',
  'back': 'Koma',
  'next': 'Na Gaba',
  'previous': 'Na Baya',

  // Settings
  'preferences': 'Zaɓuɓɓuka',
  'preferred_language': 'Harshen da Kake So',
  'dark_mode': 'Yanayin Duhu',
  'enable_notifications': 'Kunna Sanarwa',
  'push_notifications': 'Tura Sanarwa',
  'email_notifications': 'Sanarwar Imel',
  'sms_notifications': 'Sanarwar SMS',
  'appearance': 'Kamannin App',
  'account_actions': 'Ayyukan Asusun',
  'help_and_support': 'Taimako & Goyon Baya',
  'service_agreement': 'Yarjejeniyar Sabis',
  'privacy_policy': 'Manufar Keɓantawa',
  'share_your_profile': 'Raba Bayanan Ka',
  'app_preferences': 'Zaɓuɓɓukan App',
  'legal_and_support': 'Doka & Goyon Baya',
  'selected': 'zaɓaɓɓe',

  // Additional Settings
  'theme': 'Jigon App',
  'light': 'Mai Haske',
  'dark': 'Mai Duhu',
  'system': 'Na Tsarin',
  'change_password': 'Canza Kalmar Sirri',
  'sign_out': 'Fita',
  'delete_account': 'Share Asusun',
  'permanently_delete_account': 'Share asusunku har abada',
  'receive_notifications_via_email': 'Karɓi sanarwa ta imel',
  'receive_notifications_via_sms': 'Karɓi sanarwa ta SMS',
  'choose_preferred_theme': 'Zaɓi jigon da kake so',
  'view_terms_of_service': 'Duba sharuɗɗan sabis da yarjejeniya',
  'view_privacy_policy': 'Duba manufar keɓantawa',
  'get_help_and_support': 'Sami taimako da goyon baya',
  'update_account_password': 'Sabunta kalmar sirrin asusun',
  'need_help_with_lifecare': 'Kuna buƙatar taimako game da LifeCare Connect?',
  'phone': 'Waya',
  'hours': 'Lokuta',
  'monday_to_friday': 'Litinin - Juma\'a, 8AM - 6PM',
  'common_issues': 'Matsalolin Gama Gari',
  'login_problems': 'Matsalolin shiga: Duba haɗin intanet',
  'booking_issues': 'Matsalolin yin alƙawari: Tabbatar cikakken kowane fili',
  'emergency_services': 'Sabis na gaggawa: Kira 199 don taimako nan take',
  'change_password_coming_soon':
      'Fasalin canza kalmar sirri yana zuwa ba da daɗewa ba',
  'sign_out_coming_soon': 'Fasalin fita yana zuwa ba da daɗewa ba',
  'request_account_deletion': 'Nemi Share Asusun',
  'admin_will_review': 'Admin zai duba buƙatarka a cikin sa\'o\'i 48',
  'you_will_be_notified': 'Za a sanar da ku da zarar an sarrafa buƙatarku',
  'pending_withdrawals':
      'Za a sarrafa cire kuɗin da ke jiran a yi kafin sharewa',
  'action_cannot_be_undone':
      'Ba za a iya soke wannan aiki ba da zarar an amince',
  'submit_deletion_request': 'TURA BUƘATAR SHAREWA',
  'deletion_request_submitted':
      '✅ An tura buƙatar sharewa cikin nasara! Admin zai duba shi ba da daɗewa ba.',
  'failed_to_submit_request': 'An kasa tura buƙata',
  'pending_deletion_request': 'Buƙatar Share da Ke Jira',
  'submitted_on': 'An tura a ranar',
  'reason': 'Dalili',
  'cancel_request': 'Soke Buƙata',
  'cancel_request_question': 'Soke Buƙata?',
  'are_you_sure_cancel_request': 'Ka tabbata kana son soke buƙatar sharewa?',
  'no': 'A\'a',
  'yes': 'Eh',
  'yes_cancel_request': 'Eh, Soke',
  'deletion_request_cancelled': 'An soke buƙatar sharewa',
  'failed_to_cancel_request': 'An kasa soke buƙata',
  'legal_and_privacy': 'Doka & Keɓantawa',
  'admin_approval_required': 'ANA BUƘATAR IZININ ADMIN',
  'healthcare_provider_deletion_note':
      'A matsayinka na mai ba da kiwon lafiya, share asusun ka yana buƙatar amincewar mai gudanarwa don tabbatar da yadda ake sarrafa bayanan likita da na majiyyata.',
  'what_will_be_deleted': 'Abin da za a share:',
  'doctor_profile_and_credentials': 'Bayanan likita da takaddun shaida',
  'wallet_balance_and_history': 'Ma\'auni da tarihin ciniki na walat',
  'appointment_history': 'Duk tarihin alkawari da jadawalin',
  'medical_consultation_records': 'Bayanan shawarwarin likita',
  'patient_referrals_and_reports': 'Tura majiyyata da rahotanni',
  'payment_and_withdrawal_history': 'Tarihin biyan kuɗi da cirewa',
  'notifications_and_messages': 'Duk sanarwa da saƙonni',
  'account_settings_and_preferences':
      'Saitunan asusun da abubuwan da aka fi so',
  'important_notes': 'Bayanai Masu Muhimmanci:',
  'reason_for_deletion': 'Dalilin share (na zaɓi):',
  'provide_deletion_reason': 'Da fatan za a bayar da dalilin share asusun',
  'request_status': 'Matsayin Buƙata',
  'pending': 'ANA JIRA',
  'request_being_reviewed':
      'Mai gudanarwa yana duba buƙatar share asusun ka. Za a sanar da kai da zarar an sarrafa ta.',
};

// Swahili translations
const Map<String, String> _swTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Ingia',
  'logout': 'Toka',
  'email': 'Barua pepe',
  'password': 'Nywila',
  'phone_number': 'Nambari ya Simu',
  'forgot_password': 'Umesahau Nywila?',
  'reset_password': 'Weka Upya Nywila',
  'register': 'Jisajili',
  'full_name': 'Jina Kamili',
  'first_name': 'Jina la Kwanza',
  'last_name': 'Jina la Ukoo',
  'date_of_birth': 'Tarehe ya Kuzaliwa',
  'gender': 'Jinsia',
  'male': 'Mwanaume',
  'female': 'Mwanamke',
  'address': 'Anwani',
  'save': 'Hifadhi',
  'cancel': 'Ghairi',
  'delete': 'Futa',
  'edit': 'Hariri',
  'search': 'Tafuta',
  'settings': 'Mipangilio',
  'profile': 'Wasifu',
  'notifications': 'Arifa',
  'language': 'Lugha',
  'select_language': 'Chagua Lugha',

  'dashboard': 'Dashibodi',
  'patients': 'Wagonjwa',
  'appointments': 'Miadi',
  'consultations': 'Ushauri wa Kitabibu',
  'referrals': 'Rufaa',
  'wallet': 'Pochi',
  'analytics': 'Takwimu',
  'training': 'Mafunzo',
  'education': 'Elimu',

  'patient_list': 'Orodha ya Wagonjwa',
  'register_patient': 'Sajili Mgonjwa',
  'patient_details': 'Maelezo ya Mgonjwa',
  'medical_history': 'Historia ya Kiafya',
  'vitals': 'Alama Muhimu',
  'prescriptions': 'Dawa Zilizoandikwa',
  'lab_tests': 'Vipimo vya Maabara',

  'book_appointment': 'Weka Miadi',
  'appointment_date': 'Tarehe ya Miadi',
  'appointment_time': 'Muda wa Miadi',
  'appointment_type': 'Aina ya Miadi',
  'upcoming_appointments': 'Miadi Inayokuja',
  'past_appointments': 'Miadi Iliyopita',
  'cancel_appointment': 'Ghairi Miadi',

  'chief_complaint': 'Malalamiko Makuu',
  'symptoms': 'Dalili',
  'diagnosis': 'Uchunguzi',
  'treatment': 'Matibabu',
  'clinical_notes': 'Maelezo ya Kitabibu',
  'follow_up': 'Ufuatiliaji',

  'ai_assistant': 'Msaidizi wa AI',
  'ask_ai': 'Uliza AI',
  'ai_thinking': 'AI inafikiria...',
  'type_message': 'Andika ujumbe wako...',

  'malaria': 'Malaria',
  'diabetes': 'Kisukari',
  'hypertension': 'Shinikizo la Damu',
  'fever': 'Homa',
  'cough': 'Kikohozi',
  'headache': 'Maumivu ya Kichwa',
  'body_pain': 'Maumivu ya Mwili',
  'nausea': 'Kichefuchefu',
  'vomiting': 'Kutapika',
  'diarrhea': 'Kuhara',

  'success': 'Mafanikio',
  'error': 'Hitilafu',
  'warning': 'Onyo',
  'loading': 'Inapakia...',
  'no_data': 'Hakuna data',
  'retry': 'Jaribu Tena',
  'confirm': 'Thibitisha',

  'today': 'Leo',
  'yesterday': 'Jana',
  'tomorrow': 'Kesho',
  'this_week': 'Wiki Hii',
  'this_month': 'Mwezi Huu',

  'view_details': 'Tazama Maelezo',
  'update': 'Sasisha',
  'submit': 'Wasilisha',
  'close': 'Funga',
  'back': 'Rudi',
  'next': 'Ifuatayo',
  'previous': 'Iliyotangulia',

  // Settings
  'preferences': 'Mapendeleo',
  'preferred_language': 'Lugha Unayopendelea',
  'dark_mode': 'Hali ya Giza',
  'enable_notifications': 'Wezesha Arifa',
  'push_notifications': 'Arifa za Kusukuma',
  'email_notifications': 'Arifa za Barua pepe',
  'sms_notifications': 'Arifa za SMS',
  'appearance': 'Muonekano',
  'account_actions': 'Vitendo vya Akaunti',
  'help_and_support': 'Msaada & Usaidizi',
  'service_agreement': 'Mkataba wa Huduma',
  'privacy_policy': 'Sera ya Faragha',
  'share_your_profile': 'Shiriki Wasifu Wako',
  'app_preferences': 'Mapendeleo ya Programu',
  'legal_and_support': 'Kisheria & Usaidizi',
  'selected': 'imechaguliwa',

  // Additional Settings
  'theme': 'Mandhari',
  'light': 'Mwanga',
  'dark': 'Giza',
  'system': 'Mfumo',
  'change_password': 'Badilisha Nywila',
  'sign_out': 'Toka',
  'delete_account': 'Futa Akaunti',
  'permanently_delete_account': 'Futa akaunti yako kabisa',
  'receive_notifications_via_email': 'Pokea arifa kwa barua pepe',
  'receive_notifications_via_sms': 'Pokea arifa kwa SMS',
  'choose_preferred_theme': 'Chagua mandhari unayopendelea',
  'view_terms_of_service': 'Tazama masharti ya huduma na makubaliano',
  'view_privacy_policy': 'Tazama sera yetu ya faragha',
  'get_help_and_support': 'Pata msaada na usaidizi',
  'update_account_password': 'Sasisha nywila ya akaunti',
  'need_help_with_lifecare': 'Unahitaji msaada na LifeCare Connect?',
  'phone': 'Simu',
  'hours': 'Masaa',
  'monday_to_friday': 'Jumatatu - Ijumaa, 8AM - 6PM',
  'common_issues': 'Matatizo ya Kawaida',
  'login_problems': 'Matatizo ya kuingia: Angalia muunganisho wa mtandao',
  'booking_issues': 'Matatizo ya kuhifadhi: Hakikisha sehemu zote zimejazwa',
  'emergency_services': 'Huduma za dharura: Piga 199 kwa msaada wa haraka',
  'change_password_coming_soon':
      'Kipengele cha kubadilisha nywila kinakuja hivi karibuni',
  'sign_out_coming_soon': 'Kipengele cha kutoka kinakuja hivi karibuni',
  'request_account_deletion': 'Omba Ufutaji wa Akaunti',
  'admin_will_review': 'Msimamizi atakagua ombi lako ndani ya masaa 48',
  'you_will_be_notified': 'Utaarifiwa mara tu ombi lako litakaposhughulikiwa',
  'pending_withdrawals': 'Uondoaji unasubiri utashughulikiwa kabla ya kufutwa',
  'action_cannot_be_undone':
      'Hatua hii haiwezi kutenduliwa baada ya kuidhinishwa',
  'submit_deletion_request': 'WASILISHA OMBI LA KUFUTA',
  'deletion_request_submitted':
      '✅ Ombi la kufuta limewasilishwa kwa mafanikio! Msimamizi atakagua hivi karibuni.',
  'failed_to_submit_request': 'Imeshindikana kuwasilisha ombi',
  'pending_deletion_request': 'Ombi la Kufuta Linalsubiri',
  'submitted_on': 'Limewasilishwa tarehe',
  'reason': 'Sababu',
  'cancel_request': 'Ghairi Ombi',
  'cancel_request_question': 'Ghairi Ombi?',
  'are_you_sure_cancel_request':
      'Je, una uhakika unataka kughairi ombi lako la kufuta?',
  'no': 'Hapana',
  'yes': 'Ndiyo',
  'yes_cancel_request': 'Ndiyo, Ghairi',
  'deletion_request_cancelled': 'Ombi la kufuta limeghairiwa',
  'failed_to_cancel_request': 'Imeshindikana kughairi ombi',
  'legal_and_privacy': 'Kisheria & Faragha',
  'admin_approval_required': 'IDHINI YA MSIMAMIZI INAHITAJIKA',
  'healthcare_provider_deletion_note':
      'Kama mtoa huduma za afya, ufutaji wa akaunti yako unahitaji idhini ya msimamizi ili kuhakikisha usimamizi sahihi wa rekodi za kimatibabu na data ya wagonjwa.',
  'what_will_be_deleted': 'Kinachofutwa:',
  'doctor_profile_and_credentials': 'Wasifu wako wa daktari na vyeti',
  'wallet_balance_and_history': 'Salio la mkoba na historia ya miamala',
  'appointment_history': 'Historia yote ya miadi na ratiba',
  'medical_consultation_records': 'Rekodi za ushauri wa kimatibabu',
  'patient_referrals_and_reports': 'Rufaa za wagonjwa na ripoti',
  'payment_and_withdrawal_history': 'Historia ya malipo na uondoaji',
  'notifications_and_messages': 'Arifa zote na ujumbe',
  'account_settings_and_preferences': 'Mipangilio ya akaunti na mapendeleo',
  'important_notes': 'Vidokezo Muhimu:',
  'reason_for_deletion': 'Sababu ya ufutaji (si lazima):',
  'provide_deletion_reason': 'Tafadhali toa sababu ya kufuta akaunti',
  'request_status': 'Hali ya Ombi',
  'pending': 'INASUBIRI',
  'request_being_reviewed':
      'Ombi lako la kufuta akaunti linakaguliwa na msimamizi. Utajulishwa linapokamilika.',
};

// French translations
const Map<String, String> _frTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Connexion',
  'logout': 'Déconnexion',
  'email': 'E-mail',
  'password': 'Mot de passe',
  'phone_number': 'Numéro de téléphone',
  'forgot_password': 'Mot de passe oublié?',
  'reset_password': 'Réinitialiser le mot de passe',
  'register': 'S\'inscrire',
  'full_name': 'Nom complet',
  'first_name': 'Prénom',
  'last_name': 'Nom de famille',
  'date_of_birth': 'Date de naissance',
  'gender': 'Genre',
  'male': 'Homme',
  'female': 'Femme',
  'address': 'Adresse',
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'delete': 'Supprimer',
  'edit': 'Modifier',
  'search': 'Rechercher',
  'settings': 'Paramètres',
  'profile': 'Profil',
  'notifications': 'Notifications',
  'language': 'Langue',
  'select_language': 'Sélectionner la langue',

  'dashboard': 'Tableau de bord',
  'patients': 'Patients',
  'appointments': 'Rendez-vous',
  'consultations': 'Consultations',
  'referrals': 'Références',
  'wallet': 'Portefeuille',
  'analytics': 'Analytique',
  'training': 'Formation',
  'education': 'Éducation',

  'patient_list': 'Liste des patients',
  'register_patient': 'Enregistrer un patient',
  'patient_details': 'Détails du patient',
  'medical_history': 'Antécédents médicaux',
  'vitals': 'Signes vitaux',
  'prescriptions': 'Ordonnances',
  'lab_tests': 'Tests de laboratoire',

  'book_appointment': 'Prendre rendez-vous',
  'appointment_date': 'Date du rendez-vous',
  'appointment_time': 'Heure du rendez-vous',
  'appointment_type': 'Type de rendez-vous',
  'upcoming_appointments': 'Rendez-vous à venir',
  'past_appointments': 'Rendez-vous passés',
  'cancel_appointment': 'Annuler le rendez-vous',

  'chief_complaint': 'Motif principal de consultation',
  'symptoms': 'Symptômes',
  'diagnosis': 'Diagnostic',
  'treatment': 'Traitement',
  'clinical_notes': 'Notes cliniques',
  'follow_up': 'Suivi',

  'ai_assistant': 'Assistant IA',
  'ask_ai': 'Demander à l\'IA',
  'ai_thinking': 'L\'IA réfléchit...',
  'type_message': 'Tapez votre message...',

  'malaria': 'Paludisme',
  'diabetes': 'Diabète',
  'hypertension': 'Hypertension',
  'fever': 'Fièvre',
  'cough': 'Toux',
  'headache': 'Mal de tête',
  'body_pain': 'Douleurs corporelles',
  'nausea': 'Nausée',
  'vomiting': 'Vomissements',
  'diarrhea': 'Diarrhée',

  'success': 'Succès',
  'error': 'Erreur',
  'warning': 'Avertissement',
  'loading': 'Chargement...',
  'no_data': 'Aucune donnée disponible',
  'retry': 'Réessayer',
  'confirm': 'Confirmer',

  'today': 'Aujourd\'hui',
  'yesterday': 'Hier',
  'tomorrow': 'Demain',
  'this_week': 'Cette semaine',
  'this_month': 'Ce mois-ci',

  'view_details': 'Voir les détails',
  'update': 'Mettre à jour',
  'submit': 'Soumettre',
  'close': 'Fermer',
  'back': 'Retour',
  'next': 'Suivant',
  'previous': 'Précédent',

  // Settings
  'preferences': 'Préférences',
  'preferred_language': 'Langue préférée',
  'dark_mode': 'Mode sombre',
  'enable_notifications': 'Activer les notifications',
  'push_notifications': 'Notifications push',
  'email_notifications': 'Notifications par e-mail',
  'sms_notifications': 'Notifications par SMS',
  'appearance': 'Apparence',
  'account_actions': 'Actions du compte',
  'help_and_support': 'Aide & Support',
  'service_agreement': 'Accord de service',
  'privacy_policy': 'Politique de confidentialité',
  'share_your_profile': 'Partager votre profil',
  'app_preferences': 'Préférences de l\'application',
  'legal_and_support': 'Juridique & Support',
  'selected': 'sélectionné',

  // Additional Settings
  'theme': 'Thème',
  'light': 'Clair',
  'dark': 'Sombre',
  'system': 'Système',
  'change_password': 'Changer le mot de passe',
  'sign_out': 'Se déconnecter',
  'delete_account': 'Supprimer le compte',
  'permanently_delete_account': 'Supprimer définitivement votre compte',
  'receive_notifications_via_email': 'Recevoir des notifications par e-mail',
  'receive_notifications_via_sms': 'Recevoir des notifications par SMS',
  'choose_preferred_theme': 'Choisissez votre thème préféré',
  'view_terms_of_service':
      'Voir les conditions de service et accord d\'utilisateur',
  'view_privacy_policy': 'Voir notre politique de confidentialité',
  'get_help_and_support': 'Obtenir de l\'aide et du support',
  'update_account_password': 'Mettre à jour le mot de passe du compte',
  'need_help_with_lifecare': 'Besoin d\'aide avec LifeCare Connect?',
  'phone': 'Téléphone',
  'hours': 'Heures',
  'monday_to_friday': 'Lundi - Vendredi, 8h - 18h',
  'common_issues': 'Problèmes courants',
  'login_problems': 'Problèmes de connexion: Vérifiez votre connexion Internet',
  'booking_issues':
      'Problèmes de réservation: Assurez-vous que tous les champs sont remplis',
  'emergency_services':
      'Services d\'urgence: Appelez le 199 pour une aide immédiate',
  'change_password_coming_soon':
      'Fonction de changement de mot de passe bientôt disponible',
  'sign_out_coming_soon': 'Fonction de déconnexion bientôt disponible',
  'request_account_deletion': 'Demander la suppression du compte',
  'admin_will_review':
      'L\'administrateur examinera votre demande dans les 48 heures',
  'you_will_be_notified': 'Vous serez notifié une fois votre demande traitée',
  'pending_withdrawals':
      'Les retraits en attente seront traités avant la suppression',
  'action_cannot_be_undone':
      'Cette action ne peut pas être annulée une fois approuvée',
  'submit_deletion_request': 'SOUMETTRE LA DEMANDE DE SUPPRESSION',
  'deletion_request_submitted':
      '✅ Demande de suppression soumise avec succès! L\'administrateur l\'examinera bientôt.',
  'failed_to_submit_request': 'Échec de la soumission de la demande',
  'pending_deletion_request': 'Demande de suppression en attente',
  'submitted_on': 'Soumis le',
  'reason': 'Raison',
  'cancel_request': 'Annuler la demande',
  'cancel_request_question': 'Annuler la demande?',
  'are_you_sure_cancel_request':
      'Êtes-vous sûr de vouloir annuler votre demande de suppression?',
  'no': 'Non',
  'yes': 'Oui',
  'yes_cancel_request': 'Oui, annuler',
  'deletion_request_cancelled': 'Demande de suppression annulée',
  'failed_to_cancel_request': 'Échec de l\'annulation de la demande',
  'legal_and_privacy': 'Juridique & Confidentialité',
  'admin_approval_required': 'APPROBATION ADMIN REQUISE',
  'healthcare_provider_deletion_note':
      'En tant que professionnel de santé, la suppression de votre compte nécessite l\'approbation de l\'administrateur pour assurer la gestion appropriée des dossiers médicaux et des données des patients.',
  'what_will_be_deleted': 'Ce qui sera supprimé :',
  'doctor_profile_and_credentials': 'Votre profil de médecin et vos diplômes',
  'wallet_balance_and_history':
      'Solde du portefeuille et historique des transactions',
  'appointment_history': 'Tout l\'historique et les horaires des rendez-vous',
  'medical_consultation_records': 'Dossiers de consultation médicale',
  'patient_referrals_and_reports': 'Références de patients et rapports',
  'payment_and_withdrawal_history': 'Historique des paiements et retraits',
  'notifications_and_messages': 'Toutes les notifications et messages',
  'account_settings_and_preferences': 'Paramètres et préférences du compte',
  'important_notes': 'Notes importantes :',
  'reason_for_deletion': 'Raison de la suppression (optionnel) :',
  'provide_deletion_reason':
      'Veuillez fournir une raison pour la suppression du compte',
  'request_status': 'Statut de la demande',
  'pending': 'EN ATTENTE',
  'request_being_reviewed':
      'Votre demande de suppression de compte est en cours d\'examen par un administrateur. Vous serez notifié une fois qu\'elle sera traitée.',
};

// Spanish translations
const Map<String, String> _esTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Iniciar sesión',
  'logout': 'Cerrar sesión',
  'email': 'Correo electrónico',
  'password': 'Contraseña',
  'phone_number': 'Número de teléfono',
  'forgot_password': '¿Olvidaste tu contraseña?',
  'reset_password': 'Restablecer contraseña',
  'register': 'Registrarse',
  'full_name': 'Nombre completo',
  'first_name': 'Nombre',
  'last_name': 'Apellido',
  'date_of_birth': 'Fecha de nacimiento',
  'gender': 'Género',
  'male': 'Masculino',
  'female': 'Femenino',
  'address': 'Dirección',
  'save': 'Guardar',
  'cancel': 'Cancelar',
  'delete': 'Eliminar',
  'edit': 'Editar',
  'search': 'Buscar',
  'settings': 'Configuración',
  'profile': 'Perfil',
  'notifications': 'Notificaciones',
  'language': 'Idioma',
  'select_language': 'Seleccionar idioma',

  'dashboard': 'Panel de control',
  'patients': 'Pacientes',
  'appointments': 'Citas',
  'consultations': 'Consultas',
  'referrals': 'Referencias',
  'wallet': 'Cartera',
  'analytics': 'Análisis',
  'training': 'Formación',
  'education': 'Educación',

  'patient_list': 'Lista de pacientes',
  'register_patient': 'Registrar paciente',
  'patient_details': 'Detalles del paciente',
  'medical_history': 'Historial médico',
  'vitals': 'Signos vitales',
  'prescriptions': 'Recetas',
  'lab_tests': 'Pruebas de laboratorio',

  'book_appointment': 'Reservar cita',
  'appointment_date': 'Fecha de la cita',
  'appointment_time': 'Hora de la cita',
  'appointment_type': 'Tipo de cita',
  'upcoming_appointments': 'Próximas citas',
  'past_appointments': 'Citas pasadas',
  'cancel_appointment': 'Cancelar cita',

  'chief_complaint': 'Motivo principal de consulta',
  'symptoms': 'Síntomas',
  'diagnosis': 'Diagnóstico',
  'treatment': 'Tratamiento',
  'clinical_notes': 'Notas clínicas',
  'follow_up': 'Seguimiento',

  'ai_assistant': 'Asistente de IA',
  'ask_ai': 'Preguntar a la IA',
  'ai_thinking': 'La IA está pensando...',
  'type_message': 'Escribe tu mensaje...',

  'malaria': 'Malaria',
  'diabetes': 'Diabetes',
  'hypertension': 'Hipertensión',
  'fever': 'Fiebre',
  'cough': 'Tos',
  'headache': 'Dolor de cabeza',
  'body_pain': 'Dolor corporal',
  'nausea': 'Náusea',
  'vomiting': 'Vómitos',
  'diarrhea': 'Diarrea',

  'success': 'Éxito',
  'error': 'Error',
  'warning': 'Advertencia',
  'loading': 'Cargando...',
  'no_data': 'No hay datos disponibles',
  'retry': 'Reintentar',
  'confirm': 'Confirmar',

  'today': 'Hoy',
  'yesterday': 'Ayer',
  'tomorrow': 'Mañana',
  'this_week': 'Esta semana',
  'this_month': 'Este mes',

  'view_details': 'Ver detalles',
  'update': 'Actualizar',
  'submit': 'Enviar',
  'close': 'Cerrar',
  'back': 'Atrás',
  'next': 'Siguiente',
  'previous': 'Anterior',

  // Settings
  'preferences': 'Preferencias',
  'preferred_language': 'Idioma preferido',
  'dark_mode': 'Modo oscuro',
  'enable_notifications': 'Habilitar notificaciones',
  'push_notifications': 'Notificaciones push',
  'email_notifications': 'Notificaciones por correo',
  'sms_notifications': 'Notificaciones por SMS',
  'appearance': 'Apariencia',
  'account_actions': 'Acciones de cuenta',
  'help_and_support': 'Ayuda y Soporte',
  'service_agreement': 'Acuerdo de servicio',
  'privacy_policy': 'Política de privacidad',
  'share_your_profile': 'Compartir tu perfil',
  'app_preferences': 'Preferencias de la aplicación',
  'legal_and_support': 'Legal y Soporte',
  'selected': 'seleccionado',

  // Additional Settings
  'theme': 'Tema',
  'light': 'Claro',
  'dark': 'Oscuro',
  'system': 'Sistema',
  'change_password': 'Cambiar contraseña',
  'sign_out': 'Cerrar sesión',
  'delete_account': 'Eliminar cuenta',
  'permanently_delete_account': 'Eliminar permanentemente tu cuenta',
  'receive_notifications_via_email':
      'Recibir notificaciones por correo electrónico',
  'receive_notifications_via_sms': 'Recibir notificaciones por SMS',
  'choose_preferred_theme': 'Elige tu tema preferido',
  'view_terms_of_service': 'Ver términos de servicio y acuerdo de usuario',
  'view_privacy_policy': 'Ver nuestra política de privacidad',
  'get_help_and_support': 'Obtener ayuda y soporte',
  'update_account_password': 'Actualizar contraseña de la cuenta',
  'need_help_with_lifecare': '¿Necesitas ayuda con LifeCare Connect?',
  'phone': 'Teléfono',
  'hours': 'Horario',
  'monday_to_friday': 'Lunes - Viernes, 8AM - 6PM',
  'common_issues': 'Problemas comunes',
  'login_problems':
      'Problemas de inicio de sesión: Verifica tu conexión a Internet',
  'booking_issues':
      'Problemas de reserva: Asegúrate de llenar todos los campos',
  'emergency_services':
      'Servicios de emergencia: Llama al 199 para ayuda inmediata',
  'change_password_coming_soon': 'Función de cambio de contraseña próximamente',
  'sign_out_coming_soon': 'Función de cierre de sesión próximamente',
  'request_account_deletion': 'Solicitar eliminación de cuenta',
  'admin_will_review': 'El administrador revisará tu solicitud en 48 horas',
  'you_will_be_notified':
      'Serás notificado una vez que se procese tu solicitud',
  'pending_withdrawals':
      'Los retiros pendientes se procesarán antes de la eliminación',
  'action_cannot_be_undone':
      'Esta acción no se puede deshacer una vez aprobada',
  'submit_deletion_request': 'ENVIAR SOLICITUD DE ELIMINACIÓN',
  'deletion_request_submitted':
      '✅ ¡Solicitud de eliminación enviada con éxito! El administrador la revisará pronto.',
  'failed_to_submit_request': 'Error al enviar la solicitud',
  'pending_deletion_request': 'Solicitud de eliminación pendiente',
  'submitted_on': 'Enviado el',
  'reason': 'Razón',
  'cancel_request': 'Cancelar solicitud',
  'cancel_request_question': '¿Cancelar solicitud?',
  'are_you_sure_cancel_request':
      '¿Estás seguro de que quieres cancelar tu solicitud de eliminación?',
  'no': 'No',
  'yes': 'Sí',
  'yes_cancel_request': 'Sí, cancelar',
  'deletion_request_cancelled': 'Solicitud de eliminación cancelada',
  'failed_to_cancel_request': 'Error al cancelar la solicitud',
  'legal_and_privacy': 'Legal y Privacidad',
  'admin_approval_required': 'APROBACIÓN DEL ADMINISTRADOR REQUERIDA',
  'healthcare_provider_deletion_note':
      'Como proveedor de atención médica, la eliminación de su cuenta requiere la aprobación del administrador para garantizar el manejo adecuado de los registros médicos y los datos del paciente.',
  'what_will_be_deleted': 'Lo que se eliminará:',
  'doctor_profile_and_credentials': 'Su perfil de médico y credenciales',
  'wallet_balance_and_history':
      'Saldo de billetera e historial de transacciones',
  'appointment_history': 'Todo el historial y horarios de citas',
  'medical_consultation_records': 'Registros de consultas médicas',
  'patient_referrals_and_reports': 'Referencias de pacientes e informes',
  'payment_and_withdrawal_history': 'Historial de pagos y retiros',
  'notifications_and_messages': 'Todas las notificaciones y mensajes',
  'account_settings_and_preferences':
      'Configuración y preferencias de la cuenta',
  'important_notes': 'Notas importantes:',
  'reason_for_deletion': 'Razón para la eliminación (opcional):',
  'provide_deletion_reason':
      'Por favor, proporcione una razón para la eliminación de la cuenta',
  'request_status': 'Estado de la solicitud',
  'pending': 'PENDIENTE',
  'request_being_reviewed':
      'Su solicitud de eliminación de cuenta está siendo revisada por un administrador. Se le notificará una vez que se procese.',
};

// Igbo translations
const Map<String, String> _igTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Banye',
  'logout': 'Pụọ',
  'email': 'Ozi-eletrọnik',
  'password': 'Okwuntughe',
  'phone_number': 'Nọmba ekwentị',
  'forgot_password': 'Ị chefuru okwuntughe?',
  'reset_password': 'Tọgharia okwuntughe',
  'register': 'Debanye aha',
  'full_name': 'Aha zuru ezu',
  'first_name': 'Aha mbụ',
  'last_name': 'Aha ikpeazụ',
  'date_of_birth': 'Ụbọchị amụrụ',
  'gender': 'Okike',
  'male': 'Nwoke',
  'female': 'Nwanyị',
  'address': 'Adreesị',
  'save': 'Chekwaa',
  'cancel': 'Kagbuo',
  'delete': 'Hichapụ',
  'edit': 'Dezie',
  'search': 'Chọọ',
  'settings': 'Ntọala',
  'profile': 'Profaịlụ',
  'notifications': 'Ọkwa',
  'language': 'Asụsụ',
  'select_language': 'Họrọ asụsụ',

  'dashboard': 'Dashibọọdụ',
  'patients': 'Ndị ọrịa',
  'appointments': 'Nleta',
  'consultations': 'Ndụmọdụ',
  'referrals': 'Ntụgharị',
  'wallet': 'Akpa ego',
  'analytics': 'Nyocha',
  'training': 'Ọzụzụ',
  'education': 'Agụmakwụkwọ',

  'patient_list': 'Ndepụta ndị ọrịa',
  'register_patient': 'Debanye onye ọrịa',
  'patient_details': 'Nkọwa onye ọrịa',
  'medical_history': 'Akụkọ ahụike',
  'vitals': 'Ihe ndị dị mkpa',
  'prescriptions': 'Ọgwụ e dere',
  'lab_tests': 'Nyocha ụlọ nyocha',

  'book_appointment': 'Debe nleta',
  'appointment_date': 'Ụbọchị nleta',
  'appointment_time': 'Oge nleta',
  'appointment_type': 'Ụdị nleta',
  'upcoming_appointments': 'Nleta na-abịa',
  'past_appointments': 'Nleta gara aga',
  'cancel_appointment': 'Kagbuo nleta',

  'chief_complaint': 'Mkpesa bụ isi',
  'symptoms': 'Ihe ịrịba ama',
  'diagnosis': 'Nchọpụta',
  'treatment': 'Ọgwụgwọ',
  'clinical_notes': 'Ndekọ ụlọ ọgwụ',
  'follow_up': 'Nleta ọzọ',

  'ai_assistant': 'Onye inyeaka AI',
  'ask_ai': 'Jụọ AI',
  'ai_thinking': 'AI na-eche...',
  'type_message': 'Dee ozi gị...',

  'malaria': 'Ịba',
  'diabetes': 'Ọrịa shuga',
  'hypertension': 'Ọbara mgbali elu',
  'fever': 'Ahụ ọkụ',
  'cough': 'Ụkwara',
  'headache': 'Isi ọwụwa',
  'body_pain': 'Ahụ mgbu',
  'nausea': 'Ọgbụgbọ',
  'vomiting': 'Agbọ ọkụ',
  'diarrhea': 'Afọ ọsịsa',

  'success': 'Ihe ịga nke ọma',
  'error': 'Njehie',
  'warning': 'Ịdọ aka ná ntị',
  'loading': 'Na-ebu...',
  'no_data': 'Enweghị data',
  'retry': 'Nwaa ọzọ',
  'confirm': 'Kwenye',

  'today': 'Taa',
  'yesterday': 'Ụnyaahụ',
  'tomorrow': 'Echi',
  'this_week': 'Izu a',
  'this_month': 'Ọnwa a',

  'view_details': 'Lee nkọwa',
  'update': 'Melite',
  'submit': 'Nyefee',
  'close': 'Mechie',
  'back': 'Laghachi azụ',
  'next': 'Ọzọ',
  'previous': 'Nke gara aga',

  // Settings
  'preferences': 'Mmasị',
  'preferred_language': 'Asụsụ ị masịrị',
  'dark_mode': 'Ọnọdụ ọchịchịrị',
  'enable_notifications': 'Mee ka ọkwa dị',
  'push_notifications': 'Ọkwa mkpali',
  'email_notifications': 'Ọkwa email',
  'sms_notifications': 'Ọkwa SMS',
  'appearance': 'Ọdịdị',
  'account_actions': 'Omume akaụntụ',
  'help_and_support': 'Enyemaka & Nkwado',
  'service_agreement': 'Nkwekọrịta ọrụ',
  'privacy_policy': 'Iwu nzuzo',
  'share_your_profile': 'Kesaa profaịlụ gị',
  'app_preferences': 'Mmasị ngwa',
  'legal_and_support': 'Iwu & Nkwado',
  'selected': 'ahọrọ',

  // Additional Settings
  'theme': 'Ọdịdị',
  'light': 'Ìhè',
  'dark': 'Ọchịchịrị',
  'system': 'Usoro',
  'change_password': 'Gbanwee okwuntughe',
  'sign_out': 'Pụọ',
  'delete_account': 'Hichapụ akaụntụ',
  'permanently_delete_account': 'Hichapụ akaụntụ gị kpamkpam',
  'receive_notifications_via_email': 'Nata ọkwa site na email',
  'receive_notifications_via_sms': 'Nata ọkwa site na SMS',
  'choose_preferred_theme': 'Họrọ ọdịdị ị masịrị',
  'view_terms_of_service': 'Lee usoro ọrụ na nkwekọrịta onye ọrụ',
  'view_privacy_policy': 'Lee iwu nzuzo anyị',
  'get_help_and_support': 'Nweta enyemaka na nkwado',
  'update_account_password': 'Melite okwuntughe akaụntụ',
  'need_help_with_lifecare': 'Ị chọrọ enyemaka na LifeCare Connect?',
  'phone': 'Ekwentị',
  'hours': 'Oge',
  'monday_to_friday': 'Mọnde - Fraịde, 8AM - 6PM',
  'common_issues': 'Nsogbu ndị a na-ahụkarị',
  'login_problems': 'Nsogbu ịbanye: Lelee njikọ ịntanetị',
  'booking_issues': 'Nsogbu ịdebe: Gbaa mbọ hụ na e dejupụtara mpaghara niile',
  'emergency_services': 'Ọrụ mberede: Kpọọ 199 maka enyemaka ozugbo',
  'change_password_coming_soon':
      'Njirimara ịgbanwe okwuntughe na-abịa n\'oge na-adịghị anya',
  'sign_out_coming_soon': 'Njirimara ịpụ na-abịa n\'oge na-adịghị anya',
  'request_account_deletion': 'Rịọ mhichapụ akaụntụ',
  'admin_will_review': 'Admin ga-enyocha arịrịọ gị n\'ime awa 48',
  'you_will_be_notified': 'A ga-eme ka ị mara ozugbo e mechara arịrịọ gị',
  'pending_withdrawals': 'A ga-edozi mwepu ndị na-echere tupu ihichapụ',
  'action_cannot_be_undone': 'Enweghị ike ịkagbu omume a ozugbo akwadoro ya',
  'submit_deletion_request': 'NYEFEE ARỊRỊỌ MHICHAPỤ',
  'deletion_request_submitted':
      '✅ Enyefere arịrịọ mhichapụ nke ọma! Admin ga-enyocha ya n\'oge na-adịghị anya.',
  'failed_to_submit_request': 'Ọ daghị ime ka arịrịọ gasaa',
  'pending_deletion_request': 'Arịrịọ mhichapụ na-echere',
  'submitted_on': 'Enyere na',
  'reason': 'Ihe kpatara ya',
  'cancel_request': 'Kagbuo arịrịọ',
  'cancel_request_question': 'Kagbuo arịrịọ?',
  'are_you_sure_cancel_request':
      'Ị ji n\'aka na ị chọrọ ịkagbu arịrịọ mhichapụ gị?',
  'no': 'Mba',
  'yes': 'Ee',
  'yes_cancel_request': 'Ee, kagbuo',
  'deletion_request_cancelled': 'Akagbuola arịrịọ mhichapụ',
  'failed_to_cancel_request': 'Ọ daghị ịkagbu arịrịọ',
  'legal_and_privacy': 'Iwu & Nzuzo',
  'admin_approval_required': 'NKWENYE ADMIN ACHỌRỌ',
  'healthcare_provider_deletion_note':
      'Dịka onye na-enye nlekọta ahụike, mhichapụ akaụntụ gị chọrọ nkwenye nchịkwa iji hụ na ejiri ụzọ kwesịrị ekwesị na-elekọta ndekọ ahụike na data ndị ọrịa.',
  'what_will_be_deleted': 'Ihe a ga-ehichapụ:',
  'doctor_profile_and_credentials': 'Profaịlụ dọkịta gị na akwụkwọ ikike',
  'wallet_balance_and_history': 'Nguzozi obere akpa na akụkọ azụmahịa',
  'appointment_history': 'Akụkọ oge niile na usoro ihe omume',
  'medical_consultation_records': 'Ndekọ ndụmọdụ ahụike',
  'patient_referrals_and_reports': 'Nzipụ ndị ọrịa na akụkọ',
  'payment_and_withdrawal_history': 'Akụkọ ịkwụ ụgwọ na iwepụ ego',
  'notifications_and_messages': 'Ozi niile na ozi',
  'account_settings_and_preferences': 'Ntọala akaụntụ na mmasị',
  'important_notes': 'Ndetu Dị Mkpa:',
  'reason_for_deletion': 'Ihe kpatara mhichapụ (nhọrọ):',
  'provide_deletion_reason': 'Biko nye ihe kpatara mhichapụ akaụntụ',
  'request_status': 'Ọnọdụ Arịrịọ',
  'pending': 'NA-ECHERE',
  'request_being_reviewed':
      'Arịrịọ gị maka mhichapụ akaụntụ ka onye nchịkwa na-enyocha. A ga-eme gị ka ị mara mgbe emechara ya.',
};

// Yoruba translations
const Map<String, String> _yoTranslations = {
  'app_name': 'LifeCare Connect',
  'login': 'Wọle',
  'logout': 'Jade',
  'email': 'Imeeli',
  'password': 'Ọrọ aṣina',
  'phone_number': 'Nọmba foonu',
  'forgot_password': 'Ṣe o gbagbe ọrọ aṣina?',
  'reset_password': 'Tun ọrọ aṣina ṣe',
  'register': 'Forukọsilẹ',
  'full_name': 'Orukọ ni kikun',
  'first_name': 'Orukọ akọkọ',
  'last_name': 'Orukọ idile',
  'date_of_birth': 'Ọjọ ibi',
  'gender': 'Akọ tabi abo',
  'male': 'Ọkunrin',
  'female': 'Obinrin',
  'address': 'Adirẹsi',
  'save': 'Fipamọ',
  'cancel': 'Fagilee',
  'delete': 'Pa rẹ',
  'edit': 'Ṣatunko',
  'search': 'Wa',
  'settings': 'Eto',
  'profile': 'Profaili',
  'notifications': 'Awọn ikede',
  'language': 'Ede',
  'select_language': 'Yan ede',

  'dashboard': 'Dashibọọdu',
  'patients': 'Awọn alaisan',
  'appointments': 'Awọn ipade',
  'consultations': 'Awọn imoran',
  'referrals': 'Awọn itọkasi',
  'wallet': 'Apo owo',
  'analytics': 'Itupalẹ',
  'training': 'Ikẹkọ',
  'education': 'Ẹkọ',

  'patient_list': 'Atokọ awọn alaisan',
  'register_patient': 'Forukọsilẹ alaisan',
  'patient_details': 'Alaye alaisan',
  'medical_history': 'Itan-akọọlẹ iṣoogun',
  'vitals': 'Awọn ami pataki',
  'prescriptions': 'Awọn ilana oogun',
  'lab_tests': 'Awọn idanwo yàrá ìwádìí',

  'book_appointment': 'Ṣe adehun',
  'appointment_date': 'Ọjọ ipade',
  'appointment_time': 'Akoko ipade',
  'appointment_type': 'Iru ipade',
  'upcoming_appointments': 'Awọn ipade to nbọ',
  'past_appointments': 'Awọn ipade ti o ti kọja',
  'cancel_appointment': 'Fagilee ipade',

  'chief_complaint': 'Aroye akọkọ',
  'symptoms': 'Awọn ami aiṣan',
  'diagnosis': 'Ayẹwo',
  'treatment': 'Itọju',
  'clinical_notes': 'Awọn akọsilẹ ile-iwosan',
  'follow_up': 'Atẹle',

  'ai_assistant': 'Oluranlọwọ AI',
  'ask_ai': 'Beere lọwọ AI',
  'ai_thinking': 'AI nronu...',
  'type_message': 'Tẹ ifiranṣẹ rẹ...',

  'malaria': 'Iba',
  'diabetes': 'Aisan suga',
  'hypertension': 'Titẹ ẹjẹ ga',
  'fever': 'Iba',
  'cough': 'Iko',
  'headache': 'Ori fọ',
  'body_pain': 'Irọra ara',
  'nausea': 'Riri',
  'vomiting': 'Pọ',
  'diarrhea': 'Igbẹ',

  'success': 'Aṣeyọri',
  'error': 'Aṣiṣe',
  'warning': 'Ikilọ',
  'loading': 'Ngberu...',
  'no_data': 'Ko si data',
  'retry': 'Gbiyanju lẹẹkansi',
  'confirm': 'Jẹrisi',

  'today': 'Loni',
  'yesterday': 'Ana',
  'tomorrow': 'Ọla',
  'this_week': 'Ọṣẹ yii',
  'this_month': 'Oṣu yii',

  'view_details': 'Wo alaye',
  'update': 'Ṣe imudojuiwọn',
  'submit': 'Firanṣẹ',
  'close': 'Ti',
  'back': 'Pada',
  'next': 'Itele',
  'previous': 'Iṣaaju',

  // Settings
  'preferences': 'Awọn ayanfẹ',
  'preferred_language': 'Ede ti o fẹran',
  'dark_mode': 'Ipo dudu',
  'enable_notifications': 'Mu awọn ikede ṣiṣẹ',
  'push_notifications': 'Awọn ikede titari',
  'email_notifications': 'Awọn ikede imeeli',
  'sms_notifications': 'Awọn ikede SMS',
  'appearance': 'Irisi',
  'account_actions': 'Awọn iṣe akọọlẹ',
  'help_and_support': 'Iranlọwọ & Atilẹyin',
  'service_agreement': 'Adehun iṣẹ',
  'privacy_policy': 'Ilana aṣiri',
  'share_your_profile': 'Pin profaili rẹ',
  'app_preferences': 'Awọn ayanfẹ app',
  'legal_and_support': 'Ofin & Atilẹyin',
  'selected': 'yan',

  // Additional Settings
  'theme': 'Akori',
  'light': 'Imọlẹ',
  'dark': 'Dudu',
  'system': 'Eto',
  'change_password': 'Yi ọrọ aṣina pada',
  'sign_out': 'Jade',
  'delete_account': 'Pa akọọlẹ rẹ',
  'permanently_delete_account': 'Pa akọọlẹ rẹ kuro titi lai',
  'receive_notifications_via_email': 'Gba awọn ikede nipasẹ imeeli',
  'receive_notifications_via_sms': 'Gba awọn ikede nipasẹ SMS',
  'choose_preferred_theme': 'Yan akori ti o fẹran',
  'view_terms_of_service': 'Wo awọn ofin iṣẹ ati adehun olumulo',
  'view_privacy_policy': 'Wo ilana aṣiri wa',
  'get_help_and_support': 'Gba iranlọwọ ati atilẹyin',
  'update_account_password': 'Ṣe imudojuiwọn ọrọ aṣina akọọlẹ',
  'need_help_with_lifecare': 'Ṣe o nilo iranlọwọ pẹlu LifeCare Connect?',
  'phone': 'Foonu',
  'hours': 'Awọn wakati',
  'monday_to_friday': 'Ọjọ Ajẹ - Ọjọ Eti, 8AM - 6PM',
  'common_issues': 'Awọn iṣoro ti o wọpọ',
  'login_problems': 'Awọn iṣoro wiwọle: Ṣayẹwo asopọ intanẹẹti',
  'booking_issues': 'Awọn iṣoro ifisilẹ: Rii daju pe gbogbo awọn aaye ti kun',
  'emergency_services': 'Awọn iṣẹ pajawiri: Pe 199 fun iranlọwọ lẹsẹkẹsẹ',
  'change_password_coming_soon': 'Ẹya iyipada ọrọ aṣina nbọ laipẹ',
  'sign_out_coming_soon': 'Ẹya ijade nbọ laipẹ',
  'request_account_deletion': 'Beere Pipe Akọọlẹ',
  'admin_will_review': 'Alakoso yoo ṣe ayẹwo ibeere rẹ laarin awọn wakati 48',
  'you_will_be_notified': 'A o sọ fun ọ ni kete ti a ba ti ṣe ibeere rẹ',
  'pending_withdrawals': 'Awọn yiyọ ti o duro yoo ṣiṣẹ ṣaaju pipe',
  'action_cannot_be_undone': 'Ko le ṣe iṣe yii pada ni kete ti a ba fọwọsi',
  'submit_deletion_request': 'FI IBEERE PIPE SILẸ',
  'deletion_request_submitted':
      '✅ Ibeere pipe ti fisilẹ ni aṣeyọri! Alakoso yoo ṣe ayẹwo laipẹ.',
  'failed_to_submit_request': 'Kuna lati fi ibeere silẹ',
  'pending_deletion_request': 'Ibeere Pipe Ti O Duro',
  'submitted_on': 'Ti fisilẹ ni',
  'reason': 'Idi',
  'cancel_request': 'Fagilee Ibeere',
  'cancel_request_question': 'Fagilee Ibeere?',
  'are_you_sure_cancel_request':
      'Ṣe o da ọ loju pe o fẹ fagilee ibeere pipe rẹ?',
  'no': 'Rara',
  'yes': 'Bẹẹni',
  'yes_cancel_request': 'Bẹẹni, Fagilee',
  'deletion_request_cancelled': 'Ti fagilee ibeere pipe',
  'failed_to_cancel_request': 'Kuna lati fagilee ibeere',
  'legal_and_privacy': 'Ofin & Aṣiri',
  'admin_approval_required': 'IFỌWỌSI ABOJUTO NILO',
  'healthcare_provider_deletion_note':
      'Gẹgẹbi olupese itọju ilera, pipaarẹ akọọlẹ rẹ nilo ifọwọsi alabojuto lati rii daju pe a ṣakoso awọn igbasilẹ iṣoogun ati data aisan ni ọna ti o tọ.',
  'what_will_be_deleted': 'Ohun ti a o paarẹ:',
  'doctor_profile_and_credentials': 'Profaili dokita rẹ ati awọn iwe ẹri',
  'wallet_balance_and_history': 'Iwọntunwọnsi apamọwọ ati itan iṣowo',
  'appointment_history': 'Gbogbo itan ipade ati eto',
  'medical_consultation_records': 'Awọn igbasilẹ imọran iṣoogun',
  'patient_referrals_and_reports': 'Awọn ifitọnileti aisan ati ijabọ',
  'payment_and_withdrawal_history': 'Itan isanwo ati yiyọ kuro',
  'notifications_and_messages': 'Gbogbo awọn ikede ati awọn ifiranṣẹ',
  'account_settings_and_preferences': 'Awọn eto akọọlẹ ati awọn ayanfẹ',
  'important_notes': 'Awọn Akọsilẹ Pataki:',
  'reason_for_deletion': 'Idi fun pipaarẹ (aṣayan):',
  'provide_deletion_reason': 'Jọwọ pese idi fun pipaarẹ akọọlẹ',
  'request_status': 'Ipo Ibeere',
  'pending': 'N DURO',
  'request_being_reviewed':
      'Ibeere pipaarẹ akọọlẹ rẹ ti wa labẹ atunyẹwo nipasẹ alabojuto. A o sọ fun ọ nigbati o ba ti ṣe.',
};
