import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Text(
                      'LifeCare Connect – Privacy Policy',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Effective Date: August 5, 2025',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                    Text(
                      'Developed by: Rural Health Mission Nigeria',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Introduction'),
              _sectionBody(
                'Welcome to LifeCare Connect. We are committed to protecting your personal information and maintaining transparency in how we collect, use, and safeguard your data. This Privacy Policy explains how we handle your information in accordance with Google Play requirements, applicable health privacy regulations, and international best practices.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Data We Collect'),
              _sectionBody(
                'We collect only the data necessary to deliver healthcare services and support health workers:',
              ),
              _subSectionTitle('1. Personal Information'),
              _sectionBody(
                'Name, email address, phone number, user ID, and address.',
              ),
              _subSectionTitle('2. Health Information (Sensitive Data)'),
              _sectionBody(
                'Patient health conditions and medical history.\nAntenatal and postnatal visit records.\nReferrals, prescriptions, and treatment plans.\nLaboratory, radiology, physiotherapy, and other service records.\nReproductive and sexual health service details (e.g., maternal health, family planning).\nPublic health program participation (e.g., vaccination, disease prevention activities).',
              ),
              _subSectionTitle('3. Appointment and Service Information'),
              _sectionBody(
                'Booking details for healthcare services, including consultations, physiotherapy, laboratory, emergency care, and pharmacy services.',
              ),
              _subSectionTitle('4. Messages and Communication Data'),
              _sectionBody(
                'In-app chats, consultation messages, and support requests.',
              ),
              _subSectionTitle('5. Technical and Usage Data'),
              _sectionBody(
                'Device information, app performance logs, and feature usage statistics.',
              ),
              _subSectionTitle('6. Location Data'),
              _sectionBody(
                'Approximate location to assist in service delivery and referrals.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Why We Collect This Data'),
              _sectionBody('We use your information to:'),
              _bulletList([
                'Deliver healthcare services, consultations, and follow-up care.',
                'Facilitate referrals between facilities and healthcare providers.',
                'Manage prescriptions, treatments, and patient records.',
                'Provide reproductive and maternal health services.',
                'Support disease prevention and public health programs.',
                'Provide clinical resources and decision support to health workers.',
                'Manage service bookings, schedules, and notifications.',
                'Monitor and improve app performance and service quality.',
                'Ensure security, fraud prevention, and legal compliance.',
              ]),
              const SizedBox(height: 18),
              _sectionTitle('How We Handle and Share Your Data'),
              _bulletList([
                'All data is encrypted in transit and at rest using industry standards (HTTPS, AES).',
                'Data is stored securely on Google Cloud and Firebase with strict access controls.',
                'Access is restricted to authorized healthcare workers, supervisors, and facility administrators involved in your care.',
                'We do not sell or share your personal data with advertisers or unrelated third parties.',
                'Data may be shared with relevant health facilities, referral centers, or government health programs only for the purposes of delivering healthcare or meeting legal requirements.',
              ]),
              const SizedBox(height: 18),
              _sectionTitle('Offline Usage'),
              _sectionBody(
                'LifeCare Connect works offline. Health data is stored securely on your device and automatically encrypted before syncing to our secure servers when you reconnect to the internet.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Your Rights & Controls'),
              _bulletList([
                'View, update, or correct your personal and health information.',
                'Opt out of providing optional information.',
                'Request a copy of your data.',
                'Permanently delete your account and all associated data at any time.',
              ]),
              _sectionBody('How to Delete Your Account:'),
              _bulletList([
                'Open the app.',
                'Go to Settings > Account > Delete Account.',
                'Confirm deletion.',
                'All personal and health data will be permanently removed from our servers within 30 days.',
              ]),
              const SizedBox(height: 18),
              _sectionTitle('Data Retention'),
              _sectionBody(
                'We retain your data only for as long as necessary to provide services or comply with legal obligations. Health records may be retained for the minimum period required under applicable health regulations.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Compliance'),
              _sectionBody(
                'LifeCare Connect complies with the Nigeria Data Protection Regulation (NDPR), relevant health data privacy laws, and Google Play’s Health Content and Services Policy.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Changes to This Policy'),
              _sectionBody(
                'We may update this Privacy Policy from time to time. You will be notified within the app whenever significant changes are made.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Contact Us'),
              _sectionBody(
                'If you have any questions, feedback, or complaints, please contact:',
              ),
              const Row(
                children: [
                  Icon(Icons.email, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'contat_lifecare@rhemn.org.ng',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.language, color: Colors.teal),
                  const SizedBox(width: 8),
                  InkWell(
                    child: const Text(
                      'https://lifecare-connect.web.app',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.teal,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onTap: () {
                      // You can use url_launcher to open the link
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.teal,
      ),
    );
  }

  Widget _subSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _sectionBody(String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(body, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 16, color: Colors.teal),
                  ),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ...existing code...
