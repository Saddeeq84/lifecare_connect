// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';

class ReferralsScreen extends StatelessWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Referrals'),
        backgroundColor: Colors.teal,
      ),
      body: SharedReferralWidget(role: 'admin'),
    );
  }
}
