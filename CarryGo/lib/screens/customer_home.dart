import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/order_status.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/carrygo_brand.dart';
import '../widgets/confirmation_dialogs.dart';
import 'create_order_screen.dart';
import 'route_map_screen.dart';
import 'settings_screen.dart';

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} $hour:$minute';
}

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final title = auth.profile?.fullName.trim().isNotEmpty == true
        ? auth.profile!.fullName.trim()
        : context.tr('Dashboard');
    return Scaffold(
      appBar: AppBar(
        title: CarryGoAppBarTitle(label: title),
        actions: [
          const _WalletIconButton(),
          const _CustomerProfileButton(),
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
          : StreamBuilder<List<Order>>(
              stream: Provider.of<OrderProvider>(context, listen: false)
                  .watchOrders(user.uid, 'customer'),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length + 2,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _CustomerDashboardHeader(
                        activeOrders: orders
                            .where((order) =>
                                order.status != OrderStatus.delivered &&
                                order.status != OrderStatus.cancelled)
                            .length,
                        completedOrders: orders
                            .where((order) =>
                                order.status == OrderStatus.delivered)
                            .length,
                      );
                    }
                    if (index == 1 && orders.isEmpty) {
                      return const _EmptyCustomerState();
                    }
                    if (index == 1) {
                      return Text(
                        context.tr('Recent requests'),
                        style: Theme.of(context).textTheme.titleMedium,
                      );
                    }
                    return _CustomerOrderCard(order: orders[index - 2]);
                  },
                );
              },
            ),
    );
  }
}

class _WalletIconButton extends StatelessWidget {
  const _WalletIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Wallet'),
      icon: const Icon(Icons.account_balance_wallet),
      onPressed: () => _showWallet(context),
    );
  }

  void _showWallet(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
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
        return StreamBuilder(
          stream: orderProvider.watchWalletTransactions(user.uid),
          builder: (context, walletSnapshot) {
            final transactions = walletSnapshot.data?.docs ?? [];
            final balance = transactions.fold<double>(0, (total, doc) {
              final data = doc.data();
              if ((data['status'] as String? ?? '') == 'available' ||
                  (data['status'] as String? ?? '') == 'paid') {
                return total + ((data['amount'] as num?)?.toDouble() ?? 0);
              }
              return total;
            });
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(context.tr('Wallet')),
                  subtitle: Text(context.tr('Available balance')),
                  trailing: Text('NGN ${balance.toStringAsFixed(0)}'),
                ),
                FilledButton.icon(
                  onPressed: () => _topUpWallet(context, user.uid),
                  icon: const Icon(Icons.add_card),
                  label: Text(context.tr('Add funds')),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('Transaction history'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (transactions.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(context.tr('No wallet activity yet')),
                    ),
                  )
                else
                  for (final transaction in transactions.take(10))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(transaction.data()['type'] as String? ??
                            context.tr('Wallet')),
                        subtitle: Text(
                            '${context.tr('Status')}: ${transaction.data()['status'] ?? 'pending'}'),
                        trailing: Text(
                          'NGN ${((transaction.data()['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                        ),
                      ),
                    ),
              ],
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
      role: 'customer',
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
}

Future<double?> _askAmount(
  BuildContext context, {
  required String title,
}) async {
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
          onPressed: () => Navigator.pop(
            context,
            double.tryParse(controller.text.trim()) ?? 0,
          ),
          child: Text(context.tr('Continue')),
        ),
      ],
    ),
  );
  controller.dispose();
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

class _CustomerProfileButton extends StatelessWidget {
  const _CustomerProfileButton();

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = auth.profile;
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
            title: Text(context.tr('Role')),
            subtitle: Text(context.tr(profile?.role ?? 'customer')),
          ),
        ],
      ),
    );
  }
}

class _CustomerOrderCard extends StatelessWidget {
  final Order order;

  const _CustomerOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusText = _statusLabel(order.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(order.parcelDescription.isEmpty
                  ? '${order.parcelSize} parcel'
                  : order.parcelDescription),
              subtitle:
                  Text('${order.pickupAddress} → ${order.dropoffAddress}'),
              trailing: Chip(label: Text(statusText)),
            ),
            if (order.parcelPhotoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  order.parcelPhotoUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            _FlowProgress(status: order.status),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.location_city, order.city),
                _infoChip(Icons.category, order.itemType),
                _infoChip(Icons.inventory_2, order.parcelSize),
                _infoChip(Icons.scale, order.parcelWeight),
                _infoChip(Icons.health_and_safety, order.fragility),
                _infoChip(
                    Icons.route, '${order.distance.toStringAsFixed(2)} km'),
                _infoChip(
                    Icons.schedule, '${order.estimatedDurationMinutes} min'),
                _infoChip(
                    Icons.payments, 'NGN ${order.cost.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 8),
            _OrderTimingPanel(order: order),
            const SizedBox(height: 8),
            Text(
              'Rider payout: NGN ${order.riderPayout.toStringAsFixed(0)} • '
              'Platform: NGN ${order.platformCommission.toStringAsFixed(0)}',
            ),
            Text('${context.tr('Pick-up OTP')}: ${order.pickupOtp}'),
            Text('${context.tr('Delivery OTP')}: ${order.otp}'),
            Text('${context.tr('Payment')}: ${_paymentLabel(context, order)}'),
            if (order.paymentStatus == 'failed')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    context.tr('Payment failed. Try Paystack payment again.')),
              ),
            if (order.status == OrderStatus.searchingRider)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.tr(
                    'Searching for a verified rider near your pick-up location. Riders receive in-app alert, text-message placeholder, and beep.')),
              ),
            if (order.status == OrderStatus.accepted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    context.tr('Your rider is heading to pick up the item.')),
              ),
            if (order.status == OrderStatus.pickedUp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context
                    .tr('Pick-up confirmed. Rider is preparing to move.')),
              ),
            if (order.status == OrderStatus.inTransit)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.tr('Item is in transit to the receiver.')),
              ),
            if (order.paymentStatus != 'paid' &&
                order.paymentReference.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _showPaystackDialog(context, order),
                  icon: const Icon(Icons.payments),
                  label: Text(context.tr('Pay with Paystack')),
                ),
              ),
            if (order.paymentStatus == 'paid' &&
                order.status != OrderStatus.delivered &&
                order.paymentReference.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showRefundDialog(context, order),
                  icon: const Icon(Icons.report_problem),
                  label: Text(context.tr('Dispute/refund')),
                ),
              ),
            if (order.riderPhone?.isNotEmpty ?? false)
              OverflowBar(
                alignment: MainAxisAlignment.start,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showContact(context, order.riderPhone!),
                    icon: const Icon(Icons.call),
                    label: Text(context.tr('Call rider')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showContact(context, order.riderPhone!),
                    icon: const Icon(Icons.chat),
                    label: Text(context.tr('WhatsApp')),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteMapScreen(order: order),
                  ),
                ),
                icon: const Icon(Icons.route),
                label: Text(context.tr('View route')),
              ),
            ),
            if (order.status == OrderStatus.delivered)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReviewDialog(context, order),
                  icon: const Icon(Icons.star),
                  label: Text(context.tr('Rate delivery')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _paymentLabel(BuildContext context, Order order) {
    final method = switch (order.paymentMethod) {
      'cash' => context.tr('Cash'),
      'wallet' => context.tr('Wallet'),
      _ => context.tr('Card'),
    };
    if (order.paymentStatus == 'cash_on_pickup') {
      return '$method • ${context.tr('rider collects at pick-up')}';
    }
    if (order.paymentStatus == 'wallet_authorized') {
      return '$method • ${context.tr('authorized')}';
    }
    if (order.paymentStatus == 'paid') return context.tr('Paid');
    if (order.paymentReference.isNotEmpty) {
      return '$method • ${order.paymentStatus} • ${order.paymentReference}';
    }
    return '$method • ${order.paymentStatus}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case OrderStatus.pendingPayment:
        return 'Awaiting payment';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.searchingRider:
        return 'Matching rider';
      case OrderStatus.accepted:
        return 'Rider accepted';
      case OrderStatus.pickedUp:
        return 'Picked up';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.disputed:
        return 'Disputed';
      case OrderStatus.refunded:
        return 'Refunded';
      default:
        return status;
    }
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  void _showPaystackDialog(BuildContext context, Order order) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Paystack payment')),
        content: Text(
          '${context.tr('Reference')}: ${order.paymentReference}\n'
          '${context.tr('Amount')}: NGN ${order.cost.toStringAsFixed(0)}\n\n'
          '${context.tr('The app asks the backend to verify the Paystack transaction before riders can receive this job.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Provider.of<OrderProvider>(context, listen: false)
                    .confirmPaystackPayment(order.id, order.paymentReference);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.tr('Verify payment')),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context, Order order) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Dispute or refund')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: context.tr('Reason')),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await Provider.of<OrderProvider>(context, listen: false)
                  .requestRefund(
                order: order,
                reason: reasonController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.tr('Submit')),
          ),
        ],
      ),
    );
  }

  void _showContact(BuildContext context, String phone) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Contact rider')),
        content: Text('${context.tr('Use phone or WhatsApp with')} $phone'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Close'))),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, Order order) {
    final reviewController = TextEditingController(text: order.review ?? '');
    double rating = order.rating ?? 5;
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('Rate rider')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: rating,
                min: 1,
                max: 5,
                divisions: 4,
                label: rating.toStringAsFixed(0),
                onChanged: (value) => setState(() => rating = value),
              ),
              TextField(
                controller: reviewController,
                decoration: InputDecoration(labelText: context.tr('Review')),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel'))),
            FilledButton(
              onPressed: () async {
                await Provider.of<OrderProvider>(context, listen: false)
                    .addReview(order.id, rating, reviewController.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.tr('Submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDashboardHeader extends StatelessWidget {
  final int activeOrders;
  final int completedOrders;

  const _CustomerDashboardHeader({
    required this.activeOrders,
    required this.completedOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dashboard),
              title: Text(context.tr('Dashboard')),
              subtitle: Text(context
                  .tr('Book errands, track riders, and manage payments.')),
              trailing: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateOrderScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_location_alt),
                label: Text(context.tr('Book')),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric(context, Icons.delivery_dining, 'Active', activeOrders),
                _metric(context, Icons.task_alt, 'Completed', completedOrders),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, IconData icon, String label, int value) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('${context.tr(label)} $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyCustomerState extends StatelessWidget {
  const _EmptyCustomerState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.add_road),
        title: Text(context.tr('No deliveries yet')),
        subtitle: Text(context.tr(
            'Create a request to see nearby riders and choose card, wallet, or cash payment.')),
      ),
    );
  }
}

class _OrderTimingPanel extends StatelessWidget {
  final Order order;

  const _OrderTimingPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasProposal = order.pickupTimeStatus == 'rider_proposed_change' &&
        order.proposedPickupTime != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.tr('Pick-up time')}: ${_formatDate(order.acceptedPickupTime ?? order.desiredPickupTime)}',
                  ),
                ),
              ],
            ),
            if (order.isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.tr(
                    'Accepted and locked. This pick-up can no longer be cancelled by either party.')),
              ),
            if (hasProposal) ...[
              const SizedBox(height: 8),
              Text(
                '${context.tr('Rider proposed')}: ${_formatDate(order.proposedPickupTime)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              OverflowBar(
                alignment: MainAxisAlignment.start,
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await Provider.of<OrderProvider>(context, listen: false)
                          .acceptProposedPickupTime(
                        orderId: order.id,
                        proposedTime: order.proposedPickupTime!,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                context.trRead('New pick-up time accepted.'))),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('Accept time')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Provider.of<OrderProvider>(context, listen: false)
                          .rejectProposedPickupTime(order.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                context.trRead('Pick-up request cancelled.'))),
                      );
                    },
                    icon: const Icon(Icons.close),
                    label: Text(context.tr('Reject and cancel')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlowProgress extends StatelessWidget {
  final String status;

  const _FlowProgress({required this.status});

  static const _steps = [
    (OrderStatus.pendingPayment, 'Pay'),
    (OrderStatus.searchingRider, 'Match'),
    (OrderStatus.accepted, 'Accept'),
    (OrderStatus.pickedUp, 'Pick-up'),
    (OrderStatus.inTransit, 'Transit'),
    (OrderStatus.delivered, 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((step) => step.$1 == status);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Chip(
            avatar: Icon(
              i <= currentIndex
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 18,
            ),
            label: Text(context.tr(_steps[i].$2)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
