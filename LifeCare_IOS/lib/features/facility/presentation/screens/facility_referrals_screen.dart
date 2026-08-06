import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';

class FacilityReferralsScreen extends StatelessWidget {
  const FacilityReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Referrals'),
        backgroundColor: Colors.teal,
      ),
      body: const SharedReferralWidget(role: 'facility'),
    );
  }
}
