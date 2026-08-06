// Facility Dashboard Screen
// Main dashboard for facility users, provides navigation to facility features.

// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'facility_profile_screen.dart';
import 'facility_settings_screen.dart';
import 'facility_remote_consultations_screen.dart';
import 'facility_messages_screen.dart';
import 'facility_patient_list_screen.dart';
import 'facility_analytics_screen.dart';
import 'facility_services_screen.dart';
import 'facility_departments_screen.dart';
import 'facility_staff_list.dart';
import 'facility_wallet_screen.dart';
import 'facility_household_screen.dart';
import 'facility_remote_patients_screen.dart';
import 'inpatient_dashboard_screen.dart';
import 'billing_dashboard_screen.dart';
import 'patient_management_screen.dart';
import 'service_management_screen.dart';
import 'pharmacy_inventory_screen.dart';
import 'pharmacy_dispensary_screen.dart';
import 'pharmacy_sales_reports_screen.dart';
import 'facility_subscription_screen.dart';
import 'package:go_router/go_router.dart';

Future<void> _handleLogout(BuildContext context) async {
  _showLogoutDialog(context);
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Logout'),
        ],
      ),
      content: Text('Are you sure you want to logout from your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Close the dialog before logging out
            await _performLogout(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Logout'),
        ),
      ],
    ),
  );
}

Future<void> _performLogout(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');

    // Check if this is a service provider staff
    if (userRole == 'service_provider_staff') {
      // Staff logout - clear SharedPreferences only (no Firebase Auth)
      await prefs.clear();
      if (context.mounted) {
        context.go('/service_provider_login');
      }
    } else {
      // Regular facility owner/admin logout - Firebase Auth signout
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class FacilityDashboard extends StatefulWidget {
  const FacilityDashboard({super.key});

  @override
  State<FacilityDashboard> createState() => _FacilityDashboardState();
}

class _FacilityDashboardState extends State<FacilityDashboard> {
  int _unreadCount = 0;
  String? _facilityType;
  String? _facilityName;
  bool _isLoadingFacilityType = true;
  String? _userRole; // Track if user is staff or owner
  String?
  _staffDepartment; // Track staff department (e.g., inventory, dispensary)

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserRole(); // Load user role FIRST
    _listenForUnreadMessages();
    _loadFacilityType(); // Then load facility type (which checks _isStaff())
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      final department = prefs.getString('staff_department');
      if (mounted) {
        setState(() {
          _userRole = role;
          _staffDepartment = department?.toLowerCase().trim();
        });
      }
    } catch (e) {
      // If error, assume owner for safety
      if (mounted) {
        setState(() {
          _userRole = 'service_provider';
          _staffDepartment = null;
        });
      }
    }
  }

  // Check if current user is staff (not owner)
  bool _isStaff() {
    return _userRole == 'service_provider_staff';
  }

  // Check if current user is inventory management staff
  bool _isInventoryStaff() {
    return _isStaff() && _staffDepartment == 'inventory management';
  }

  Future<void> _loadFacilityType() async {
    try {
      // Check if user is staff (no Firebase Auth)
      if (_isStaff()) {
        // Load from SharedPreferences for staff
        final prefs = await SharedPreferences.getInstance();
        final facilityType = prefs.getString('facility_type');
        final facilityName = prefs.getString('facility_name');

        if (mounted) {
          setState(() {
            _facilityType = facilityType;
            _facilityName = facilityName;
            _isLoadingFacilityType = false;
          });
        }
        return;
      }

      // For facility owner, load from Firebase Auth + Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityType = data?['type'] as String?;
            _facilityName = data?['name'] as String?;
            _isLoadingFacilityType = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFacilityType = false);
      }
    }
  }

  void _listenForUnreadMessages() async {
    // For staff, check department conversations
    if (_isStaff()) {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('staff_id') ?? '';
      final facilityName = prefs.getString('facility_name') ?? '';

      if (staffId.isEmpty || facilityName.isEmpty) return;

      // Listen for unread messages in department conversations
      FirebaseFirestore.instance
          .collection('conversations')
          .where('type', isEqualTo: 'department')
          .where('facilityName', isEqualTo: facilityName)
          .where('participants', arrayContains: staffId)
          .snapshots()
          .listen((snapshot) {
            int totalUnread = 0;
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final unreadCounts =
                  data['unreadCounts'] as Map<String, dynamic>?;
              if (unreadCounts != null && unreadCounts[staffId] != null) {
                totalUnread += unreadCounts[staffId] is int
                    ? unreadCounts[staffId] as int
                    : 0;
              }
            }
            if (mounted) {
              setState(() {
                _unreadCount = totalUnread;
              });
            }
          });
      return;
    }

    // For owners, check unread messages where they are the receiver or in participants
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;

    // First, mark all old messages without isRead field as read (one-time cleanup)
    _markOldMessagesAsRead(userId);

    FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _unreadCount = snapshot.docs.length;
            });
          }
        });
  }

  // One-time cleanup to mark old messages as read
  Future<void> _markOldMessagesAsRead(String userId) async {
    try {
      final oldMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (final doc in oldMessages.docs) {
        final data = doc.data();
        // If isRead field doesn't exist, mark as read
        if (!data.containsKey('isRead')) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('Marked $updateCount old messages as read');
      }
    } catch (e) {
      print('Error marking old messages as read: $e');
    }
  }

  List<Map<String, dynamic>> get dashboardItems {
    // Check if this is a Pharmacy
    final bool isPharmacy =
        _facilityType != null &&
        _facilityType!.toLowerCase().trim() == 'pharmacy';

    // Pharmacy-specific dashboard
    if (isPharmacy) {
      // Inventory Management staff see ONLY inventory
      if (_isInventoryStaff()) {
        return [
          {
            "icon": Icons.inventory_2,
            "label": "Inventory Management",
            "action": "inventory",
          },
        ];
      }

      // Other staff see dispensary and reports
      if (_isStaff()) {
        return [
          {
            "icon": Icons.point_of_sale,
            "label": "Dispensary",
            "action": "dispensary",
          },
          {
            "icon": Icons.analytics,
            "label": "Sales & Reports",
            "action": "analytics",
          },
        ];
      }

      // Owner sees all features
      return [
        {
          "icon": Icons.point_of_sale,
          "label": "Dispensary",
          "action": "dispensary",
        },
        {
          "icon": Icons.inventory_2,
          "label": "Inventory Management",
          "action": "inventory",
        },
        {
          "icon": Icons.medical_services,
          "label": "Online Pharmacy",
          "action": "services",
        },
        {"icon": Icons.group, "label": "Staff Management", "action": "staff"},
        {
          "icon": Icons.analytics,
          "label": "Sales & Reports",
          "action": "analytics",
        },
      ];
    }

    // Check if this is a Laboratory
    final bool isLaboratory =
        _facilityType != null &&
        _facilityType!.toLowerCase().trim() == 'laboratory';

    // Laboratory-specific dashboard
    if (isLaboratory) {
      // Staff see limited features only
      if (_isStaff()) {
        return [
          {
            "icon": Icons.assignment,
            "label": "Test Requests",
            "action": "bookings",
          },
          {
            "icon": Icons.science,
            "label": "Test Services",
            "action": "services",
          },
          {
            "icon": Icons.description,
            "label": "Lab Reports & Analytics",
            "action": "analytics",
          },
        ];
      }

      // Owner sees all features
      return [
        {
          "icon": Icons.assignment,
          "label": "Test Requests",
          "action": "bookings",
        },
        {"icon": Icons.group, "label": "Staff Management", "action": "staff"},
        {"icon": Icons.people_alt, "label": "Clients", "action": "patients"},
        {
          "icon": Icons.biotech,
          "label": "Sample Management",
          "action": "samples",
        },
        {"icon": Icons.science, "label": "Test Services", "action": "services"},
        {
          "icon": Icons.description,
          "label": "Lab Reports & Analytics",
          "action": "analytics",
        },
      ];
    }

    // Check if this is a Scan Center
    final bool isScanCenter =
        _facilityType != null &&
        _facilityType!.toLowerCase().trim() == 'scan center';

    // Scan Center-specific dashboard
    if (isScanCenter) {
      // Staff see limited features only
      if (_isStaff()) {
        return [
          {
            "icon": Icons.medical_information,
            "label": "Scan Requests",
            "action": "bookings",
          },
          {
            "icon": Icons.camera_alt,
            "label": "Imaging Services",
            "action": "services",
          },
          {
            "icon": Icons.analytics,
            "label": "Reports & Analytics",
            "action": "analytics",
          },
        ];
      }

      // Owner sees all features
      return [
        {
          "icon": Icons.medical_information,
          "label": "Scan Requests",
          "action": "bookings",
        },
        {"icon": Icons.group, "label": "Staff Management", "action": "staff"},
        {"icon": Icons.people, "label": "Patients", "action": "patients"},
        {
          "icon": Icons.camera_alt,
          "label": "Imaging Services",
          "action": "services",
        },
        {
          "icon": Icons.analytics,
          "label": "Reports & Analytics",
          "action": "analytics",
        },
      ];
    }

    // Non-pharmacy facilities - reorganized dashboard
    List<Map<String, dynamic>> items = [];

    // 1. Departments or Services (based on facility type)
    // For Laboratory, Scan Center, Dental Clinic, Eye Clinic, Physiotherapy Center, and Mental Health Center - show Services
    // For others (Hospital, Clinic) - show Departments
    final servicesOnlyTypes = [
      'laboratory',
      'scan center',
      'dental clinic',
      'eye clinic',
      'physiotherapy center',
      'mental health center',
    ];
    final bool showServices =
        _facilityType != null &&
        servicesOnlyTypes.any(
          (type) => _facilityType!.toLowerCase().trim() == type.toLowerCase(),
        );

    if (showServices) {
      items.add({
        "icon": Icons.medical_services,
        "label": "Services",
        "action": "services",
      });
    } else {
      items.add({
        "icon": Icons.business,
        "label": "Departments",
        "action": "departments",
      });
    }

    // 2. Service Management
    items.add({
      "icon": Icons.price_change,
      "label": "Service Management",
      "action": "service_management",
    });

    // 3. Patient Management
    items.add({
      "icon": Icons.people,
      "label": "Patient Management",
      "action": "patient_management",
    });

    // 4. Lifecare Insurance
    items.add({
      "icon": Icons.home_work,
      "label": "Lifecare Insurance",
      "action": "households",
    });

    // 5. Inventory Management
    items.add({
      "icon": Icons.inventory_2,
      "label": "Inventory Management",
      "action": "inventory",
    });

    // 6. Order Supplies (Procurement from Providers)
    // Only for consumer facilities (Hospital, Clinic, PHC)
    final consumerFacilityTypes = [
      'hospital',
      'clinic',
      'phc',
      'primary health care',
    ];
    final bool isConsumerFacility =
        _facilityType != null &&
        consumerFacilityTypes.any(
          (type) =>
              _facilityType!.toLowerCase().trim().contains(type.toLowerCase()),
        );

    if (isConsumerFacility) {
      items.add({
        "icon": Icons.shopping_cart,
        "label": "Order Supplies",
        "action": "order_supplies",
      });
    }

    // 7. Staff Management
    items.add({
      "icon": Icons.group,
      "label": "Staff Management",
      "action": "staff",
    });

    // 8. Reports and Analytics
    items.add({
      "icon": Icons.analytics,
      "label": "Reports & Analytics",
      "action": "analytics",
    });

    return items;
  }

  void _navigateToProfile(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityProfileScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSettings(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilitySettingsScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToBookings(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityRemoteConsultationsScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening remote consultations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToDispensary(BuildContext context) async {
    try {
      String facilityId;
      String staffId;
      String staffName;

      if (_isStaff()) {
        // For staff, get data from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        facilityId = prefs.getString('facility_id') ?? '';
        staffId = prefs.getString('staff_id') ?? '';
        staffName = prefs.getString('staff_name') ?? 'Staff';

        if (facilityId.isEmpty || staffId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff information not found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        // For facility owner, get data from Firebase Auth
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Get user data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data() ?? {};
        facilityId = user.uid;
        staffId = user.uid;
        staffName = userData['fullName'] ?? userData['name'] ?? 'Owner';
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PharmacyDispensaryScreen(
            facilityId: facilityId,
            staffId: staffId,
            staffName: staffName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening dispensary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToMessages(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FacilityMessagesScreen(
            isStaff: _isStaff(), // Pass true if service provider staff
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening messages: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSubscription(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilitySubscriptionScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToPatients(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityPatientListScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening patient list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToRemotePatients(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityRemotePatientsScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening remote patients: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAnalytics(BuildContext context) async {
    try {
      // Check if it's a standalone pharmacy
      final isPharmacy =
          _facilityType != null &&
          _facilityType!.toLowerCase().trim() == 'pharmacy';

      if (isPharmacy) {
        // Use pharmacy-specific sales & reports screen
        String facilityId;

        if (_isStaff()) {
          // For staff, get facility ID from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          facilityId = prefs.getString('facility_id') ?? '';

          if (facilityId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Facility information not found. Please login again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else {
          // For facility owner, use Firebase Auth user ID
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          facilityId = user.uid;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PharmacySalesReportsScreen(facilityId: facilityId),
          ),
        );
      } else {
        // Use general facility analytics screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FacilityAnalyticsScreen(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToServices(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FacilityServicesScreen(facilityType: _facilityType),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToDepartments(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityDepartmentsScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening departments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToWallet(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityWalletScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening wallet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToBilling(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get facility data for facility admin
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!facilityDoc.exists) {
        throw Exception('Facility data not found');
      }

      final facilityData = facilityDoc.data()!;
      final facilityName = facilityData['fullName'] ?? 'Facility Admin';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BillingDashboardScreen(
            facilityId: user.uid,
            staffId: 'admin', // Facility admin acts as special staff
            staffName: facilityName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening billing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToServiceManagement(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_facilityName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load facility information. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceManagementScreen(
            facilityId: user.uid,
            facilityName: _facilityName!,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening service management: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToInventory(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get facility data
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!facilityDoc.exists) {
        throw Exception('Facility data not found');
      }

      final facilityData = facilityDoc.data()!;
      final facilityName = facilityData['fullName'] ?? 'Facility Admin';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PharmacyInventoryScreen(
            facilityId: user.uid,
            staffId: 'admin', // Facility admin acts as special staff
            staffName: facilityName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSamples(BuildContext context) {
    try {
      // For now, show coming soon - Sample Management can be implemented later
      _showComingSoonDialog(context, 'Sample Management');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening sample management: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDashboardItemTap(BuildContext context, String action) {
    switch (action) {
      case 'patient_management':
        _navigateToPatientManagement(context);
        break;
      case 'bookings':
        _navigateToBookings(context);
        break;
      case 'dispensary':
        _navigateToDispensary(context);
        break;
      case 'messages':
        _navigateToMessages(context);
        break;
      case 'patients':
        _navigateToPatients(context);
        break;
      case 'remote_patients':
        _navigateToRemotePatients(context);
        break;
      case 'in_patients':
        _navigateToInPatients(context);
        break;
      case 'analytics':
        _navigateToAnalytics(context);
        break;
      case 'services':
        _navigateToServices(context);
        break;
      case 'departments':
        _navigateToDepartments(context);
        break;
      case 'inventory':
        _navigateToInventory(context);
        break;
      case 'samples':
        _navigateToSamples(context);
        break;
      case 'staff':
        if (_facilityName == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to load facility information. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FacilityStaffListScreen(facilityName: _facilityName!),
          ),
        );
        break;
      case 'wallet':
        _navigateToWallet(context);
        break;
      case 'billing':
        _navigateToBilling(context);
        break;
      case 'service_management':
        _navigateToServiceManagement(context);
        break;
      case 'households':
        _navigateToHouseholds(context);
        break;
      case 'order_supplies':
        _navigateToOrderSupplies(context);
        break;
      default:
        _showComingSoonDialog(context, 'Feature');
    }
  }

  void _navigateToPatientManagement(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PatientManagementScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening patient management: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToHouseholds(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityHouseholdScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening households: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToOrderSupplies(BuildContext context) {
    try {
      debugPrint('🛒 Navigating to /facility_procurement');
      context.go('/facility_procurement');
      debugPrint('✅ Navigation call completed');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening order supplies: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToInPatients(BuildContext context) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_facilityName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load facility information. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InpatientDashboardScreen(
            facilityId: user.uid,
            facilityName: _facilityName!,
            staffId:
                user.uid, // Using facility admin ID as staff ID for viewing
            staffName:
                _facilityName!, // Using facility name as staff name for viewing
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening in-patients: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upcoming, color: Colors.teal),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$feature feature is under development and will be available in a future update.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Stay tuned for updates!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Facility Dashboard"),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Subscription IconButton (Owner only, hidden for inventory staff)
          if (!_isStaff() && !_isInventoryStaff())
            IconButton(
              onPressed: () => _navigateToSubscription(context),
              icon: const Icon(Icons.subscriptions),
              tooltip: "Subscription",
            ),
          // Messages IconButton with unread badge (hidden for inventory staff)
          if (!_isInventoryStaff())
            Stack(
              children: [
                IconButton(
                  onPressed: () => _navigateToMessages(context),
                  icon: const Icon(Icons.chat),
                  tooltip: "Messages",
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          // Wallet navigation button (Owner only, hidden for inventory staff)
          if (!_isStaff() && !_isInventoryStaff())
            IconButton(
              onPressed: () => _navigateToWallet(context),
              icon: const Icon(Icons.account_balance_wallet),
              tooltip: "Wallet",
            ),
          // Profile navigation button
          IconButton(
            onPressed: () => _navigateToProfile(context),
            icon: const Icon(Icons.person),
            tooltip: "Profile",
          ),
          // Settings navigation button
          IconButton(
            onPressed: () => _navigateToSettings(context),
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
          ),
          // Logout button
          IconButton(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: _isLoadingFacilityType
          ? Center(
              child: CircularProgressIndicator(color: Colors.teal.shade800),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: dashboardItems.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final item = dashboardItems[index];
                return ListTile(
                  leading: Icon(
                    item["icon"],
                    color: Colors.teal.shade800,
                    size: 28,
                  ),
                  title: Text(
                    item["label"],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () => _handleDashboardItemTap(context, item['action']),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
    );
  }
}
