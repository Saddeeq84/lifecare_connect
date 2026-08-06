import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String? returnTo;

  const PublicProfileScreen({super.key, required this.userId, this.returnTo});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;
  String? errorMessage;
  String facilityType = '';

  @override
  void initState() {
    super.initState();
    _loadPublicProfile();
  }

  Future<void> _loadPublicProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          userData = data;
        });

        // Determine facility type
        final role = data?['role'] ?? '';
        final profession = data?['profession'] ?? '';
        final facilityTypeField = data?['facilityType'] ?? '';

        setState(() {
          facilityType = facilityTypeField.toString().toLowerCase();
        });

        // Load products if pharmacy
        if (facilityType.contains('pharmacy') ||
            profession.toLowerCase().contains('pharmac')) {
          await _loadProducts();
        }
        // Load services for other facility types
        else if (role == 'facility' || facilityType.isNotEmpty) {
          await _loadServices();
        }

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Profile not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load profile: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.userId)
          .collection('pharmacy_inventory')
          .where('stock', isGreaterThan: 0)
          .limit(20)
          .get();

      setState(() {
        products = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _loadServices() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.userId)
          .collection('services')
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      setState(() {
        services = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error loading services: $e');
    }
  }

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(errorMessage!, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final name = userData?['name'] ?? 'Unknown';
    final email = userData?['email'] ?? '';
    final phone = userData?['phone'] ?? '';
    final profession = userData?['profession'] ?? userData?['role'] ?? '';
    final photoUrl = userData?['photoUrl'];
    final specialization = userData?['specialization'] ?? '';
    final bio = userData?['bio'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal, Colors.teal.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (profession.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      profession,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (specialization.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      specialization,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Public Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show Products for Pharmacies
                  if (products.isNotEmpty) ...[
                    const Text(
                      'Available Products',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...products.map((product) => _buildProductCard(product)),
                    const SizedBox(height: 24),
                  ],

                  // Show Services for Facilities
                  if (services.isNotEmpty) ...[
                    const Text(
                      'Available Services',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...services.map((service) => _buildServiceCard(service)),
                    const SizedBox(height: 24),
                  ],

                  // About section
                  if (bio.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Contact Information (public)
                  const Text(
                    'Contact',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (email.isNotEmpty) _buildInfoRow(Icons.email, email),
                  if (phone.isNotEmpty) _buildInfoRow(Icons.phone, phone),

                  const SizedBox(height: 32),

                  // Login/Register prompt for non-logged-in users
                  if (!isLoggedIn) ...[
                    Card(
                      color: Colors.teal.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: Colors.teal,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Create an account to:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Book appointments\n'
                              '• View services and prices\n'
                              '• Access online pharmacy\n'
                              '• Chat with healthcare providers',
                              style: TextStyle(fontSize: 16, height: 1.6),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Redirect to signup with return path
                                  context.go(
                                    '/signup?returnTo=${Uri.encodeComponent('/profile/${widget.userId}')}',
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Create Account'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                context.go(
                                  '/login?returnTo=${Uri.encodeComponent('/profile/${widget.userId}')}',
                                );
                              },
                              child: const Text(
                                'Already have an account? Login',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Logged-in users can book appointments
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to booking screen
                          context.go(
                            '/patient_dashboard/appointments?providerId=${widget.userId}',
                          );
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Book Appointment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (userData?['hasPharmacy'] == true)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.go(
                              '/patient_dashboard/pharmacy?providerId=${widget.userId}',
                            );
                          },
                          icon: const Icon(Icons.medication),
                          label: const Text('View Pharmacy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unknown Product';
    final price = product['price'] ?? 0.0;
    final stock = product['stock'] ?? 0;
    final description = product['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: Colors.teal,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          fontSize: 13,
                          color: stock > 10 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleOrder(product),
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Order Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final name = service['name'] ?? 'Unknown Service';
    final price = service['price'] ?? 0.0;
    final description = service['description'] ?? '';
    final duration = service['duration'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (duration.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Duration: $duration',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleServiceRequest(service),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Request Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOrder(Map<String, dynamic> product) {
    if (!isLoggedIn) {
      _showLoginPrompt('order this product');
    } else {
      // Navigate to order screen
      context.push(
        '/order',
        extra: {'product': product, 'facilityId': widget.userId},
      );
    }
  }

  void _handleServiceRequest(Map<String, dynamic> service) {
    if (!isLoggedIn) {
      _showLoginPrompt('request this service');
    } else {
      // Navigate to booking screen
      context.push(
        '/book_appointment',
        extra: {'service': service, 'facilityId': widget.userId},
      );
    }
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Required'),
        content: Text('Please create an account or login to $action.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(
                '/login?returnTo=${Uri.encodeComponent('/profile/${widget.userId}')}',
              );
            },
            child: const Text('Login'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(
                '/signup?returnTo=${Uri.encodeComponent('/profile/${widget.userId}')}',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
