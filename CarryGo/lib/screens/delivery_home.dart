import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/nigerian_banks.dart';
import '../constants/order_status.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/carrygo_brand.dart';
import '../widgets/confirmation_dialogs.dart';
import 'route_map_screen.dart';
import 'settings_screen.dart';

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} $hour:$minute';
}

class DeliveryHome extends StatelessWidget {
  const DeliveryHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.profile;
    final user = auth.user;
    final title = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : context.tr('Dashboard');
    return Scaffold(
      appBar: AppBar(
        title: CarryGoAppBarTitle(label: title),
        actions: [
          const _RiderWalletIconButton(),
          const _RiderProfileButton(),
          const SettingsIconButton(),
          IconButton(
            tooltip: context.tr('Log out'),
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context),
          ),
        ],
      ),
      body: user == null
          ? Center(child: Text(context.tr('Sign in to continue.')))
          : !auth.isApprovedRider
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${context.tr('Your rider account is')} ${profile?.riderStatus ?? 'pending'}. '
                      '${context.tr('An admin must verify your documents before you can accept requests.')}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: auth.watchRiderProfile(user.uid),
                  builder: (context, riderSnapshot) {
                    final riderData = riderSnapshot.data?.data() ?? {};
                    final isOnline = riderData['isOnline'] == true ||
                        riderData['status'] == 'available';
                    final profileComplete = _riderProfileComplete(riderData);
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _RiderStatusCard(
                          riderData: riderData,
                          isOnline: isOnline,
                          profileComplete: profileComplete,
                          onChanged: (value) async {
                            try {
                              await auth.setRiderOnline(user.uid, value);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (!profileComplete) ...[
                          _RiderVerificationCard(
                            riderId: user.uid,
                            riderData: riderData,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _RiderMetrics(riderId: user.uid),
                        const SizedBox(height: 12),
                        if (profileComplete)
                          _ActiveJobs(riderId: user.uid, isOnline: isOnline)
                        else
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.verified_user),
                              title: Text(context.tr('Complete rider profile')),
                              subtitle: Text(context.tr(
                                  'Upload your NIN and verification document before going online.')),
                            ),
                          ),
                        const SizedBox(height: 12),
                        _CompletedJobs(riderId: user.uid),
                        const SizedBox(height: 12),
                        _RiderRatings(riderId: user.uid),
                      ],
                    );
                  },
                ),
    );
  }

  bool _riderProfileComplete(Map<String, dynamic> riderData) {
    return riderData['profileCompleted'] == true &&
        (riderData['idCardUrl'] as String? ?? '').isNotEmpty &&
        (riderData['riderLicenseUrl'] as String? ?? '').isNotEmpty;
  }
}

class _RiderWalletIconButton extends StatelessWidget {
  const _RiderWalletIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Rider wallet'),
      icon: const Icon(Icons.account_balance_wallet),
      onPressed: () => _showWallet(context),
    );
  }

  void _showWallet(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.tr('Sign in to continue.')),
          );
        }
        final orderProvider =
            Provider.of<OrderProvider>(context, listen: false);
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: orderProvider.watchRiderPayouts(user.uid),
          builder: (context, payoutSnapshot) {
            final payouts = payoutSnapshot.data?.docs ?? [];
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: orderProvider.watchWalletTransactions(user.uid),
              builder: (context, walletSnapshot) {
                final walletEntries = walletSnapshot.data?.docs ?? [];
                final earnings = payouts.fold<double>(
                  0,
                  (total, doc) =>
                      total + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
                );
                final walletBalance =
                    walletEntries.fold<double>(0, (total, doc) {
                  final data = doc.data();
                  final status = data['status'] as String? ?? '';
                  if (status == 'available' || status == 'paid') {
                    return total + ((data['amount'] as num?)?.toDouble() ?? 0);
                  }
                  return total;
                });
                final commissionDue =
                    walletEntries.fold<double>(0, (total, doc) {
                  final data = doc.data();
                  if ((data['status'] as String? ?? '') == 'due') {
                    return total +
                        (((data['amount'] as num?)?.toDouble() ?? 0).abs());
                  }
                  return total;
                });
                final balance = earnings + walletBalance - commissionDue;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(context.tr('Rider wallet')),
                      subtitle: Text(context.tr('Available for withdrawal')),
                      trailing: Text('NGN ${balance.toStringAsFixed(0)}'),
                    ),
                    if (commissionDue > 0)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber),
                          title: Text(context.tr('Cash commission due')),
                          subtitle: Text(context.tr(
                              'Add funds to clear commission collected from cash rides.')),
                          trailing:
                              Text('NGN ${commissionDue.toStringAsFixed(0)}'),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () => _topUpWallet(context, user.uid),
                      icon: const Icon(Icons.add_card),
                      label: Text(context.tr('Add funds')),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: balance <= 0
                          ? null
                          : () =>
                              _requestWithdrawal(context, user.uid, balance),
                      icon: const Icon(Icons.payments),
                      label: Text(context.tr('Withdraw')),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('Earnings history'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (payouts.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(context.tr('No rider earnings yet')),
                        ),
                      )
                    else
                      for (final payout in payouts.take(10))
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long),
                            title: Text(
                                '${context.tr('Order')} ${payout.data()['orderId'] ?? ''}'),
                            subtitle: Text(
                                '${context.tr('Status')}: ${payout.data()['status'] ?? 'available_in_wallet'}'),
                            trailing: Text(
                              'NGN ${((payout.data()['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                            ),
                          ),
                        ),
                    for (final entry in walletEntries.take(10))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet),
                          title:
                              Text(entry.data()['type'] as String? ?? 'wallet'),
                          subtitle: Text(
                              '${context.tr('Status')}: ${entry.data()['status'] ?? ''}'),
                          trailing: Text(
                            'NGN ${((entry.data()['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _topUpWallet(BuildContext context, String userId) async {
    final amount = await _askAmount(context, title: context.tr('Add funds'));
    if (amount == null || amount <= 0 || !context.mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final topup = await orderProvider.initializeWalletTopup(
      userId: userId,
      role: 'rider',
      email: auth.user?.email ?? auth.profile?.email ?? '',
      amount: amount,
    );
    if (!context.mounted) return;
    final paid = await _showPaystackDialog(
      context,
      reference: topup.reference,
      authorizationUrl: topup.authorizationUrl,
    );
    if (paid == true) {
      final ok = await orderProvider.confirmWalletTopup(topup.reference);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? context.tr('Wallet funded successfully.')
              : context.tr('Wallet funding failed.')),
        ),
      );
    }
  }

  Future<void> _requestWithdrawal(
    BuildContext context,
    String userId,
    double balance,
  ) async {
    final request = await _askWithdrawal(context, maxAmount: balance);
    if (request == null || !context.mounted) return;
    await Provider.of<OrderProvider>(context, listen: false).requestWithdrawal(
      userId: userId,
      role: 'rider',
      amount: request.amount,
      bankName: request.bankName,
      accountNumber: request.accountNumber,
      accountName: request.accountName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Withdrawal request submitted.'))),
    );
  }
}

class _WithdrawalFormValue {
  final double amount;
  final String bankName;
  final String accountNumber;
  final String accountName;

  const _WithdrawalFormValue({
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });
}

Future<double?> _askAmount(BuildContext context,
    {required String title}) async {
  final controller = TextEditingController();
  final value = await showDialog<double>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(prefixText: 'NGN '),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(controller.text) ?? 0),
          child: Text(context.tr('Continue')),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<_WithdrawalFormValue?> _askWithdrawal(
  BuildContext context, {
  required double maxAmount,
}) async {
  final amount = TextEditingController(text: maxAmount.toStringAsFixed(0));
  final accountNumber = TextEditingController();
  final accountName = TextEditingController();
  var bank = nigerianBanks.first;
  final value = await showDialog<_WithdrawalFormValue>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.tr('Withdraw')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: 'NGN '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: bank,
                decoration: InputDecoration(labelText: context.tr('Bank')),
                items: nigerianBanks
                    .map((bank) => DropdownMenuItem(
                          value: bank,
                          child: Text(bank),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => bank = value ?? bank),
              ),
              TextField(
                controller: accountNumber,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: context.tr('Account number')),
              ),
              TextField(
                controller: accountName,
                decoration:
                    InputDecoration(labelText: context.tr('Account name')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _WithdrawalFormValue(
                amount: double.tryParse(amount.text) ?? 0,
                bankName: bank,
                accountNumber: accountNumber.text.trim(),
                accountName: accountName.text.trim(),
              ),
            ),
            child: Text(context.tr('Submit')),
          ),
        ],
      ),
    ),
  );
  amount.dispose();
  accountNumber.dispose();
  accountName.dispose();
  return value;
}

Future<bool?> _showPaystackDialog(
  BuildContext context, {
  required String reference,
  required String authorizationUrl,
}) {
  final url = Uri.parse(authorizationUrl);
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(context.tr('Paystack payment')),
      icon: const Icon(Icons.credit_card),
      content: Text('${context.tr('Reference')}: $reference'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('Cancel')),
        ),
        OutlinedButton.icon(
          onPressed: authorizationUrl.isEmpty
              ? null
              : () => launchUrl(url, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new),
          label: Text(context.tr('Open Paystack')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.verified),
          label: Text(context.tr('Verify payment')),
        ),
      ],
    ),
  );
}

class _RiderProfileButton extends StatelessWidget {
  const _RiderProfileButton();

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context).profile;
    final photoUrl = profile?.profilePhotoUrl ?? '';
    return IconButton(
      tooltip: context.tr('Account'),
      icon: CircleAvatar(
        radius: 14,
        backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
        child: photoUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
      ),
      onPressed: () => _showProfile(context),
    );
  }

  void _showProfile(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context, listen: false).profile;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundImage: (profile?.profilePhotoUrl ?? '').isEmpty
                  ? null
                  : NetworkImage(profile!.profilePhotoUrl),
              child: (profile?.profilePhotoUrl ?? '').isEmpty
                  ? const Icon(Icons.person, size: 42)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.badge),
            title: Text(context.tr('Full name')),
            subtitle: Text(profile?.fullName.isEmpty ?? true
                ? context.tr('Not set')
                : profile!.fullName),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(context.tr('Email')),
            subtitle: Text(profile?.email.isEmpty ?? true
                ? context.tr('Not set')
                : profile!.email),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(context.tr('Contact phone number')),
            subtitle: Text(profile?.phone.isEmpty ?? true
                ? context.tr('Not set')
                : profile!.phone),
          ),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: Text(context.tr('City')),
            subtitle: Text(profile?.city ?? 'Lagos'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: Text(context.tr('Verification')),
            subtitle: Text(context.tr(profile?.riderStatus ?? 'pending')),
          ),
          ListTile(
            leading: const Icon(Icons.two_wheeler),
            title: Text(context.tr('Bike details')),
            subtitle: Text(
              '${profile?.bikeModel ?? ''} ${profile?.bikeColor ?? ''} ${profile?.bikePlateNumber ?? ''}'
                      .trim()
                      .isEmpty
                  ? context.tr('Not set')
                  : '${profile?.bikeModel ?? ''} ${profile?.bikeColor ?? ''} ${profile?.bikePlateNumber ?? ''}'
                      .trim(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderVerificationCard extends StatefulWidget {
  final String riderId;
  final Map<String, dynamic> riderData;

  const _RiderVerificationCard({
    required this.riderId,
    required this.riderData,
  });

  @override
  State<_RiderVerificationCard> createState() => _RiderVerificationCardState();
}

class _RiderVerificationCardState extends State<_RiderVerificationCard> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _ninUrl = '';
  String _verificationUrl = '';

  @override
  void initState() {
    super.initState();
    _ninUrl = widget.riderData['idCardUrl'] as String? ?? '';
    _verificationUrl = widget.riderData['riderLicenseUrl'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final complete = _ninUrl.isNotEmpty && _verificationUrl.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_ind),
              title: Text(context.tr('Complete rider profile')),
              subtitle: Text(context.tr(
                  'Upload your NIN and rider licence or verification document.')),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickAndUpload('nin'),
                  icon: Icon(
                      _ninUrl.isEmpty ? Icons.upload_file : Icons.check_circle),
                  label: Text(context
                      .tr(_ninUrl.isEmpty ? 'Upload NIN' : 'NIN uploaded')),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickAndUpload('verification'),
                  icon: Icon(_verificationUrl.isEmpty
                      ? Icons.upload_file
                      : Icons.check_circle),
                  label: Text(context.tr(_verificationUrl.isEmpty
                      ? 'Upload verification document'
                      : 'Verification document uploaded')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  complete && !_isUploading ? _saveVerificationProfile : null,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified),
              label: Text(context.tr('Submit verification profile')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String type) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1800,
    );
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await _uploadDocument(type, bytes, file.name);
      setState(() {
        if (type == 'nin') {
          _ninUrl = url;
        } else {
          _verificationUrl = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Upload failed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String> _uploadDocument(
    String type,
    Uint8List bytes,
    String fileName,
  ) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance.ref(
      'riders/${widget.riderId}/$type-${DateTime.now().millisecondsSinceEpoch}-$safeName',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _saveVerificationProfile() async {
    setState(() => _isUploading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .completeRiderVerificationProfile(
        riderId: widget.riderId,
        ninDocumentUrl: _ninUrl,
        verificationDocumentUrl: _verificationUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Rider profile completed.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _RiderStatusCard extends StatelessWidget {
  final Map<String, dynamic> riderData;
  final bool isOnline;
  final bool profileComplete;
  final ValueChanged<bool> onChanged;

  const _RiderStatusCard({
    required this.riderData,
    required this.isOnline,
    required this.profileComplete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isOnline,
              onChanged: profileComplete ? onChanged : null,
              title: Text(context.tr(isOnline ? 'Online' : 'Offline')),
              subtitle: Text(context.tr(profileComplete
                  ? 'Go online to receive nearby paid requests.'
                  : 'Complete verification uploads before going online.')),
            ),
            Text(
                'Bike: ${riderData['bikeModel'] ?? ''} ${riderData['bikeColor'] ?? ''}'),
            Text('Plate: ${riderData['bikePlateNumber'] ?? ''}'),
          ],
        ),
      ),
    );
  }
}

class _RiderMetrics extends StatelessWidget {
  final String riderId;

  const _RiderMetrics({required this.riderId});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: orderProvider.watchRiderPayouts(riderId),
      builder: (context, payoutSnapshot) {
        final payouts = payoutSnapshot.data?.docs ?? [];
        final total = payouts.fold<double>(
          0,
          (runningTotal, doc) =>
              runningTotal + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
        );
        return StreamBuilder<List<Order>>(
          stream: orderProvider.watchCompletedRiderOrders(riderId),
          builder: (context, ordersSnapshot) {
            final completed = ordersSnapshot.data ?? [];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                        label: Text(
                            '${context.tr('Earnings')} NGN ${total.toStringAsFixed(0)}')),
                    Chip(
                        label: Text(
                            '${context.tr('Completed')} ${completed.length}')),
                    Chip(
                        label:
                            Text('${context.tr('Payouts')} ${payouts.length}')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActiveJobs extends StatelessWidget {
  final String riderId;
  final bool isOnline;

  const _ActiveJobs({
    required this.riderId,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.power_settings_new),
          title: Text(context.tr('You are offline')),
          subtitle: Text(
              context.tr('Turn on availability to receive nearby requests.')),
        ),
      );
    }

    return StreamBuilder<List<Order>>(
      stream: Provider.of<OrderProvider>(context, listen: false)
          .watchOrders(riderId, 'rider'),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? [])
            .where((order) =>
                order.riderId == riderId ||
                _isAvailableCustomerBooking(order, riderId))
            .toList();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (orders.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.delivery_dining),
              title: Text(context.tr('No active CarryGo requests')),
              subtitle:
                  Text(context.tr('Nearby paid requests will appear here.')),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Active requests'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              context.tr(
                  'Customer bookings appear here when payment is ready or cash collection is selected.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final order in orders) _RiderOrderCard(order: order),
          ],
        );
      },
    );
  }

  bool _isAvailableCustomerBooking(Order order, String riderId) {
    final canBePaidToRider = const {
      'paid',
      'cash_on_pickup',
      'wallet_authorized',
    }.contains(order.paymentStatus);
    return order.status == OrderStatus.searchingRider &&
        canBePaidToRider &&
        ((order.riderId ?? '').isEmpty || order.riderId == riderId) &&
        !order.rejectedRiderIds.contains(riderId);
  }
}

class _CompletedJobs extends StatelessWidget {
  final String riderId;

  const _CompletedJobs({required this.riderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: Provider.of<OrderProvider>(context, listen: false)
          .watchCompletedRiderOrders(riderId),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        if (jobs.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.task_alt),
              title: Text(context.tr('Completed jobs')),
              subtitle:
                  Text(context.tr('Completed deliveries will appear here.')),
            ),
          );
        }
        return ExpansionTile(
          leading: const Icon(Icons.task_alt),
          title: Text('${context.tr('Completed jobs')} (${jobs.length})'),
          children: [
            for (final job in jobs.take(5))
              ListTile(
                title: Text('${job.pickupAddress} → ${job.dropoffAddress}'),
                subtitle: Text(
                    '${context.tr('Payout')} NGN ${job.riderPayout.toStringAsFixed(0)}'),
              ),
          ],
        );
      },
    );
  }
}

class _RiderRatings extends StatelessWidget {
  final String riderId;

  const _RiderRatings({required this.riderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Provider.of<OrderProvider>(context, listen: false)
          .watchRiderRatings(riderId),
      builder: (context, snapshot) {
        final ratings = snapshot.data?.docs ?? [];
        final average = ratings.isEmpty
            ? 0.0
            : ratings.fold<double>(
                  0,
                  (runningTotal, doc) =>
                      runningTotal +
                      ((doc.data()['rating'] as num?)?.toDouble() ?? 0),
                ) /
                ratings.length;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.star),
            title:
                Text('${context.tr('Rating')} ${average.toStringAsFixed(1)}'),
            subtitle: Text(
                '${ratings.length} ${context.tr('customer reviews received')}'),
          ),
        );
      },
    );
  }
}

class _RiderOrderCard extends StatelessWidget {
  final Order order;

  const _RiderOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.user;
    final assignedToMe = order.riderId == user?.uid;
    final canSeeOpenJob = order.status == OrderStatus.searchingRider &&
        const {'paid', 'cash_on_pickup', 'wallet_authorized'}
            .contains(order.paymentStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${order.pickupAddress} → ${order.dropoffAddress}'),
              subtitle: Text(
                  '${order.distance.toStringAsFixed(2)} km • ${order.estimatedDurationMinutes} min • ${order.urgency}'),
              trailing: Chip(label: Text(_statusLabel(context, order.status))),
            ),
            Text(
                '${order.itemType} • ${order.parcelSize} • ${order.parcelWeight} • ${order.fragility}: ${order.parcelDescription}'),
            if (order.parcelPhotoUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  order.parcelPhotoUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (order.fragility != 'Not fragile')
              Text(context.tr('Handle carefully. Fragile item declared.')),
            Text(
                '${context.tr('Pick-up')}: ${order.senderName} ${order.senderPhone}'),
            Text(
                '${context.tr('Receiver')}: ${order.receiverName} ${order.receiverPhone}'),
            Text(
                '${context.tr('Customer fee')}: NGN ${order.cost.toStringAsFixed(0)} • ${order.city}'),
            Text(
                '${context.tr('Rider payout')}: NGN ${order.riderPayout.toStringAsFixed(0)}'),
            Text('${context.tr('Payment')}: ${_paymentLabel(context, order)}'),
            Text(
                '${context.tr('Pick-up time')}: ${_formatDate(order.desiredPickupTime)}'),
            if (order.pickupTimeStatus == 'rider_proposed_change' &&
                order.proposedPickupTime != null)
              Text(
                  '${context.tr('Time proposed')}: ${_formatDate(order.proposedPickupTime)}'),
            if (order.isLocked)
              Text(context.tr(
                  'Accepted and locked. This booking cannot be cancelled.')),
            OverflowBar(
              alignment: MainAxisAlignment.start,
              spacing: 8,
              children: [
                if (canSeeOpenJob) ...[
                  FilledButton.icon(
                    onPressed: user == null
                        ? null
                        : () => orderProvider.acceptOrder(
                              orderId: order.id,
                              riderId: user.uid,
                              riderPhone: auth.profile?.phone ?? '',
                              acceptedPickupTime: order.desiredPickupTime,
                            ),
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('Accept time')),
                  ),
                  OutlinedButton.icon(
                    onPressed: user == null
                        ? null
                        : () => _showProposeTimeDialog(context, order),
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(context.tr('Propose time')),
                  ),
                  OutlinedButton.icon(
                    onPressed: user == null
                        ? null
                        : () => orderProvider.rejectOrder(order.id, user.uid),
                    icon: const Icon(Icons.close),
                    label: Text(context.tr('Reject')),
                  ),
                ],
                if (assignedToMe && order.status == OrderStatus.accepted)
                  FilledButton.tonalIcon(
                    onPressed: () => _showPickupOtpDialog(context, order),
                    icon: const Icon(Icons.inventory_2),
                    label: Text(context.tr('Confirm pick-up')),
                  ),
                if (assignedToMe && order.status == OrderStatus.pickedUp)
                  FilledButton.tonalIcon(
                    onPressed: () => orderProvider.updateStatus(
                        order.id, OrderStatus.inTransit),
                    icon: const Icon(Icons.delivery_dining),
                    label: Text(context.tr('Navigate to drop-off')),
                  ),
                if (assignedToMe && order.status == OrderStatus.inTransit)
                  FilledButton.icon(
                    onPressed: () => _showDeliveryOtpDialog(context, order),
                    icon: const Icon(Icons.verified),
                    label: Text(context.tr('Confirm delivery OTP')),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RouteMapScreen(order: order),
                    ),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: Text(
                    order.status == OrderStatus.accepted
                        ? context.tr('Navigate to pick-up')
                        : context.tr('Route'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showContact(context, order.receiverPhone),
                  icon: const Icon(Icons.chat),
                  label: Text(context.tr('Contact')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case OrderStatus.searchingRider:
        return context.tr('Available');
      case OrderStatus.accepted:
        return context.tr('Accepted');
      case OrderStatus.pickedUp:
        return context.tr('Picked up');
      case OrderStatus.inTransit:
        return context.tr('In transit');
      default:
        return status;
    }
  }

  String _paymentLabel(BuildContext context, Order order) {
    switch (order.paymentStatus) {
      case 'cash_on_pickup':
        return context.tr('Cash collected at pick-up');
      case 'wallet_authorized':
        return context
            .tr('Wallet escrow, released to rider wallet after delivery');
      case 'paid':
        return context
            .tr('Card escrow, released to rider wallet after delivery');
      default:
        return order.paymentStatus;
    }
  }

  Future<void> _showProposeTimeDialog(
    BuildContext context,
    Order order,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      initialDate: order.desiredPickupTime ?? now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        order.desiredPickupTime ?? now.add(const Duration(minutes: 30)),
      ),
    );
    if (time == null || !context.mounted) return;
    final proposed = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await Provider.of<OrderProvider>(context, listen: false).proposePickupTime(
      orderId: order.id,
      riderId: Provider.of<AuthProvider>(context, listen: false).user!.uid,
      riderPhone:
          Provider.of<AuthProvider>(context, listen: false).profile?.phone ??
              '',
      proposedTime: proposed,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(context.trRead('New pick-up time sent to customer.'))),
    );
  }

  void _showContact(BuildContext context, String phone) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Contact receiver')),
        content: Text('${context.tr('Use phone or WhatsApp with')} $phone'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Close'))),
        ],
      ),
    );
  }

  void _showPickupOtpDialog(BuildContext context, Order order) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Pick-up OTP')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: context.tr('Sender code')),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel'))),
          FilledButton(
            onPressed: () async {
              final success =
                  await Provider.of<OrderProvider>(context, listen: false)
                      .confirmPickup(order.id, controller.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(success
                        ? context.trRead('Pick-up confirmed.')
                        : context.trRead('Invalid OTP.'))),
              );
            },
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
  }

  void _showDeliveryOtpDialog(BuildContext context, Order order) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Delivery OTP')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: context.tr('Receiver code')),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel'))),
          FilledButton(
            onPressed: () async {
              final success =
                  await Provider.of<OrderProvider>(context, listen: false)
                      .confirmDelivery(order.id, controller.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(success
                        ? context.trRead('Delivery confirmed.')
                        : context.trRead('Invalid OTP.'))),
              );
            },
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
  }
}
