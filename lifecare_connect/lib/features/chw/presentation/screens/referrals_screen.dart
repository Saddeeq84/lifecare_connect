// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';
import '../../../shared/presentation/widgets/make_referral_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referrals'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MakeReferralForm(role: 'chw'),
                ),
              );
            },
          ),
        ],
      ),
      body: const SharedReferralWidget(role: 'chw'),
    );
  }
}

