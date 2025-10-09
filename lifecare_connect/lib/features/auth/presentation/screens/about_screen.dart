import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 18),
              Text(
                'Connecting you with top healthcare professionals. LifeCare Connect leverages digital health soluttions to provide rural communities with access to quality healthcare. Through virtual consultations, remote monitoring, health worker training, and essential pharmaceutical services, we bridge healthcare gaps, ensuring better health outcomes, education, and timely care, empowering individuals and healthcare workers in underserved communities.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text('Our Mission:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 6),
              Text('To provide accessible, quality healthcare to underserved communities through innovative digital health solutions.', style: TextStyle(fontSize: 16)),
              SizedBox(height: 18),
              Text('Our Vision:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 6),
              Text('To be a leading digital health platform that transforms healthcare delivery in rural areas, ensuring every individual has access to quality medical care.', style: TextStyle(fontSize: 16)),
              SizedBox(height: 18),
              Text('Our Values:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: Colors.teal, size: 22),
                  SizedBox(width: 8),
                  Expanded(child: Text('Compassion: We care deeply about the health and well-being of our patients.', style: TextStyle(fontSize: 16))),
                ],
              ),
              SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: Colors.teal, size: 22),
                  SizedBox(width: 8),
                  Expanded(child: Text('Innovation: We embrace technology to improve healthcare delivery.', style: TextStyle(fontSize: 16))),
                ],
              ),
              SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: Colors.teal, size: 22),
                  SizedBox(width: 8),
                  Expanded(child: Text('Integrity: We uphold the highest standards of professionalism and ethics.', style: TextStyle(fontSize: 16))),
                ],
              ),
              SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: Colors.teal, size: 22),
                  SizedBox(width: 8),
                  Expanded(child: Text('Collaboration: We work together with healthcare professionals and communities to achieve better health outcomes.', style: TextStyle(fontSize: 16))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
