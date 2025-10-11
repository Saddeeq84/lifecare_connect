import 'package:flutter/material.dart';
import 'package:lifecare_connect/features/chw/presentation/screens/chw_create_referral_screen.dart';

class DoctorCreateReferralScreen extends StatelessWidget {
  const DoctorCreateReferralScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Referral'),
      ),
  body: CHWCreateReferralScreen(),
    );
  }
}
