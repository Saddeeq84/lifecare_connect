import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/nigerian_cities.dart';
import '../constants/order_status.dart';
import '../l10n/app_localizations.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/payment_record.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/pricing_service.dart';
import '../widgets/carrygo_brand.dart';
import '../widgets/confirmation_dialogs.dart';
import 'route_map_screen.dart';
import 'settings_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final title = auth.profile?.fullName.trim().isNotEmpty == true
        ? auth.profile!.fullName.trim()
        : context.tr('Dashboard');
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: CarryGoAppBarTitle(label: title),
          actions: [
            const SettingsIconButton(),
            IconButton(
              tooltip: context.tr('Log out'),
              icon: const Icon(Icons.logout),
              onPressed: () => confirmAndSignOut(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('Orders')),
              Tab(text: context.tr('Customers')),
              Tab(text: context.tr('Riders')),
              Tab(text: context.tr('Payments')),
              Tab(text: context.tr('Disputes')),
              Tab(text: context.tr('Notify')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminOrders(),
            _CustomersTab(),
            _RidersTab(),
            _PaymentsTab(),
            _DisputesTab(),
            _NotificationsTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminOrders extends StatelessWidget {
  const _AdminOrders();

  static const _activeStatuses = {
    OrderStatus.pendingPayment,
    OrderStatus.paid,
    OrderStatus.searchingRider,
    OrderStatus.accepted,
    OrderStatus.pickedUp,
    OrderStatus.inTransit,
    OrderStatus.disputed,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: Provider.of<OrderProvider>(context, listen: false)
          .watchOrders('', 'admin'),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final live = orders
            .where((order) => _activeStatuses.contains(order.status))
            .toList();
        final completed = orders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryGrid(
              items: [
                _SummaryItem('Live orders', live.length.toString()),
                _SummaryItem('Completed', completed.length.toString()),
                _SummaryItem(
                    'Disputed',
                    orders
                        .where((o) => o.status == OrderStatus.disputed)
                        .length
                        .toString()),
              ],
            ),
            const SizedBox(height: 12),
            _ExportButton(
              label: 'Export order report',
              csv: _ordersCsv(orders),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Live orders'),
            if (live.isEmpty) const _EmptyState('No live orders right now.'),
            for (final order in live) _OrderCard(order: order),
            const SizedBox(height: 16),
            const _SectionTitle('Completed orders'),
            if (completed.isEmpty)
              const _EmptyState('No completed deliveries yet.'),
            for (final order in completed) _OrderCard(order: order),
          ],
        );
      },
    );
  }
}

class _CustomersTab extends StatelessWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return StreamBuilder<List<AppUser>>(
      stream: auth.usersByRole('customer'),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyState(
            'Could not load customers. ${snapshot.error}',
          );
        }
        if (customers.isEmpty) {
          return const _EmptyState('No registered customers yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: customers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final user = customers[index];
            return _UserCard(
              user: user,
              action: user.accountStatus == 'suspended'
                  ? const Chip(label: Text('suspended'))
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.block),
                      label: const Text('Suspend'),
                      onPressed: () async {
                        final reason = await _askForText(
                          context,
                          title: 'Suspend customer',
                          hint: 'Reason for suspension',
                        );
                        if (reason == null || reason.trim().isEmpty) return;
                        await auth.suspendUser(user.id, reason.trim());
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

class _RidersTab extends StatelessWidget {
  const _RidersTab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return StreamBuilder<List<AppUser>>(
      stream: auth.usersByRole('rider'),
      builder: (context, snapshot) {
        final riders = snapshot.data ?? [];
        final pending =
            riders.where((rider) => rider.riderStatus == 'pending').length;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyState(
            'Could not load riders. ${snapshot.error}',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryGrid(
              items: [
                _SummaryItem('All riders', riders.length.toString()),
                _SummaryItem('Pending', pending.toString()),
                _SummaryItem(
                  'Approved',
                  riders
                      .where((rider) => rider.riderStatus == 'approved')
                      .length
                      .toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (riders.isEmpty) const _EmptyState('No registered riders yet.'),
            for (final rider in riders) _RiderAdminCard(rider: rider),
          ],
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRecord>>(
      stream:
          Provider.of<OrderProvider>(context, listen: false).watchPayments(),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        final paid = payments.where((payment) => payment.status == 'paid');
        final failed = payments.where((payment) => payment.status == 'failed');
        final refunds =
            payments.where((payment) => payment.status.contains('refund'));
        final totalPaid = paid.fold<int>(
          0,
          (total, payment) => total + payment.amountKobo,
        );
        final totalCommission = paid.fold<double>(
          0,
          (total, payment) => total + payment.platformCommission,
        );
        final totalRiderPayout = paid.fold<double>(
          0,
          (total, payment) => total + payment.riderPayout,
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryGrid(
              items: [
                _SummaryItem('Paid volume',
                    'NGN ${(totalPaid / 100).toStringAsFixed(0)}'),
                _SummaryItem('Failed', failed.length.toString()),
                _SummaryItem('Refunds', refunds.length.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Payment report'),
                subtitle: Text(
                  'Platform NGN ${totalCommission.toStringAsFixed(0)} • '
                  'Rider payouts NGN ${totalRiderPayout.toStringAsFixed(0)}',
                ),
              ),
            ),
            _ExportButton(
              label: 'Export payment report',
              csv: _paymentsCsv(payments),
            ),
            const SizedBox(height: 12),
            const _PricingSettings(),
            const SizedBox(height: 12),
            for (final payment in payments)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text('${payment.reference} • ${payment.status}'),
                  subtitle: Text(
                    'Order ${payment.orderId}\n'
                    'Amount NGN ${(payment.amountKobo / 100).toStringAsFixed(0)} • '
                    'Platform NGN ${payment.platformCommission.toStringAsFixed(0)} • '
                    'Rider NGN ${payment.riderPayout.toStringAsFixed(0)}'
                    '${payment.failureReason.isEmpty ? '' : '\n${payment.failureReason}'}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context) {
    final orders = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: orders.watchComplaints(),
      builder: (context, snapshot) {
        final complaints = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (complaints.isEmpty) {
          return const _EmptyState('No disputes or refund requests yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: complaints.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final complaint = complaints[index];
            final data = complaint.data();
            final status = data['status'] as String? ?? 'open';
            final paymentReference = data['paymentReference'] as String? ?? '';
            final orderId = data['orderId'] as String? ?? '';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order $orderId',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$status • NGN ${((data['amountKobo'] as num? ?? 0) / 100).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 6),
                    Text(data['reason'] as String? ?? 'No reason supplied'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Under review'),
                          onPressed: () => orders.updateComplaintStatus(
                            complaintId: complaint.id,
                            status: 'under_review',
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Resolve'),
                          onPressed: () async {
                            final note = await _askForText(
                              context,
                              title: 'Resolve dispute',
                              hint: 'Resolution note',
                            );
                            if (note == null) return;
                            await orders.updateComplaintStatus(
                              complaintId: complaint.id,
                              status: 'resolved',
                              adminNote: note,
                            );
                          },
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.undo),
                          label: const Text('Mark refunded'),
                          onPressed: paymentReference.isEmpty || orderId.isEmpty
                              ? null
                              : () async {
                                  final note = await _askForText(
                                    context,
                                    title: 'Mark refunded',
                                    hint: 'Refund/admin note',
                                  );
                                  if (note == null) return;
                                  await orders.markRefunded(
                                    complaintId: complaint.id,
                                    orderId: orderId,
                                    paymentReference: paymentReference,
                                    adminNote: note,
                                  );
                                },
                        ),
                      ],
                    ),
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

class _PricingSettings extends StatefulWidget {
  const _PricingSettings();

  @override
  State<_PricingSettings> createState() => _PricingSettingsState();
}

class _PricingSettingsState extends State<_PricingSettings> {
  String _city = 'Lagos';
  final _baseFare = TextEditingController(text: '900');
  final _perKmRate = TextEditingController(text: '180');
  final _commissionRate = TextEditingController(text: '15');

  @override
  void dispose() {
    _baseFare.dispose();
    _perKmRate.dispose();
    _commissionRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pricing rule',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                  items: nigerianStateCapitalCities
                      .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _city = value;
                      _baseFare.text = baseFeeForCity(value).toStringAsFixed(0);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseFare,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Base fare',
                    prefixText: 'NGN ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _perKmRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Distance rate per km',
                    prefixText: 'NGN ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commissionRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Platform commission',
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save pricing rule'),
                  onPressed: () async {
                    await orderProvider.savePricingRule(
                      city: _city,
                      baseFare: double.tryParse(_baseFare.text) ?? 0,
                      perKmRate: double.tryParse(_perKmRate.text) ?? 0,
                      commissionRate:
                          (double.tryParse(_commissionRate.text) ?? 0) / 100,
                      minimumBillableDistanceKm: 1,
                      roundingStep: 50,
                      sizeFees: PricingService.fallbackRule(_city).sizeFees,
                      weightFees: PricingService.fallbackRule(_city).weightFees,
                      urgencyMultipliers:
                          PricingService.fallbackRule(_city).urgencyMultipliers,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pricing rule saved')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.scale),
            title: Text('Parcel and urgency modifiers'),
            subtitle: Text(
              'Small, Medium, Large, Extra Large plus Light, Medium, Heavy are priced with Normal or Express urgency. Weather and traffic multipliers can be added before commission split.',
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  String _audience = 'customer';
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _orderId = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _orderId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _audience,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(
                        value: 'customer', child: Text('Customers')),
                    DropdownMenuItem(value: 'rider', child: Text('Riders')),
                    DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _audience = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _orderId,
                  decoration: const InputDecoration(
                    labelText: 'Order ID',
                    hintText: 'Optional',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Send notification'),
                  onPressed: () async {
                    if (_title.text.trim().isEmpty ||
                        _body.text.trim().isEmpty) {
                      return;
                    }
                    await orderProvider.sendAdminNotification(
                      audienceRole: _audience,
                      title: _title.text.trim(),
                      body: _body.text.trim(),
                      orderId: _orderId.text.trim(),
                    );
                    _title.clear();
                    _body.clear();
                    _orderId.clear();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification sent')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RiderAdminCard extends StatelessWidget {
  const _RiderAdminCard({required this.rider});

  final AppUser rider;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final status =
        rider.accountStatus == 'suspended' ? 'suspended' : rider.riderStatus;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: auth.watchRiderProfile(rider.id),
      builder: (context, snapshot) {
        final riderData = snapshot.data?.data() ?? {};
        final documentStatus =
            riderData['documentReviewStatus'] as String? ?? 'not_submitted';
        final ninNumber = riderData['ninNumber'] as String? ?? '';
        final ninUrl = riderData['idCardUrl'] as String? ?? rider.idCardUrl;
        final licenseUrl =
            riderData['riderLicenseUrl'] as String? ?? rider.riderLicenseUrl;
        final rejectionReason =
            riderData['documentRejectionReason'] as String? ?? '';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.two_wheeler),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rider.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${rider.city} • ${rider.phone} • ${rider.email}'),
                const SizedBox(height: 4),
                Text(
                  'Bike: ${rider.bikePlateNumber} ${rider.bikeModel} ${rider.bikeColor}',
                ),
                const SizedBox(height: 6),
                Text('NIN: ${ninNumber.isEmpty ? 'Not submitted' : ninNumber}'),
                Text('Documents: $documentStatus'),
                if (rejectionReason.isNotEmpty)
                  Text('Reason: $rejectionReason'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('Approve account'),
                      onPressed: rider.riderStatus == 'approved'
                          ? null
                          : () async {
                              final confirm = await showConfirmationDialog(
                                context,
                                title: 'Approve rider account',
                                message:
                                    'Approve this rider account request? The rider will be allowed to complete document verification.',
                                confirmLabel: 'Approve',
                              );
                              if (confirm != true) return;
                              await auth.approveRider(rider.id);
                            },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject account'),
                      onPressed: () async {
                        final reason = await _askForText(
                          context,
                          title: 'Reject rider',
                          hint: 'Reason for rejection',
                        );
                        if (reason == null || reason.trim().isEmpty) return;
                        await auth.rejectRider(rider.id, reason.trim());
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.block),
                      label: const Text('Suspend'),
                      onPressed: rider.accountStatus == 'suspended'
                          ? null
                          : () async {
                              final reason = await _askForText(
                                context,
                                title: 'Suspend rider',
                                hint: 'Reason for suspension',
                              );
                              if (reason == null || reason.trim().isEmpty) {
                                return;
                              }
                              await auth.suspendRider(rider.id, reason.trim());
                            },
                    ),
                    if (rider.accountStatus == 'suspended')
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Reinstate'),
                        onPressed: () => auth.reinstateUser(rider.id, 'rider'),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.badge),
                      label: const Text('View NIN'),
                      onPressed: ninUrl.isEmpty ? null : () => _openUrl(ninUrl),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text('View Licence'),
                      onPressed: licenseUrl.isEmpty
                          ? null
                          : () => _openUrl(licenseUrl),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.fact_check),
                      label: const Text('Approve documents'),
                      onPressed: documentStatus == 'approved' ||
                              ninUrl.isEmpty ||
                              licenseUrl.isEmpty ||
                              ninNumber.isEmpty
                          ? null
                          : () async {
                              final confirm = await showConfirmationDialog(
                                context,
                                title: 'Approve rider documents',
                                message:
                                    'Confirm that the NIN and licence documents have been reviewed and accepted.',
                                confirmLabel: 'Approve',
                              );
                              if (confirm != true) return;
                              await auth.approveRiderDocuments(rider.id);
                            },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.report),
                      label: const Text('Reject documents'),
                      onPressed: ninUrl.isEmpty && licenseUrl.isEmpty
                          ? null
                          : () async {
                              final reason = await _askForText(
                                context,
                                title: 'Reject rider documents',
                                hint: 'Reason rider should correct',
                              );
                              if (reason == null || reason.trim().isEmpty) {
                                return;
                              }
                              await auth.rejectRiderDocuments(
                                rider.id,
                                reason.trim(),
                              );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.action});

  final AppUser user;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(user.fullName),
        subtitle: Text(
          '${user.email.isEmpty ? user.phone : user.email} • ${user.city}\n'
          'Status: ${user.accountStatus}'
          '${user.suspensionReason.isEmpty ? '' : ' • ${user.suspensionReason}'}',
        ),
        isThreeLine: true,
        trailing: action,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
            '${order.city}: ${order.pickupAddress} to ${order.dropoffAddress}'),
        subtitle: Text(
          '${order.status} • ${order.paymentStatus} • '
          '${order.itemType} • ${order.parcelSize} • ${order.parcelWeight} • ${order.fragility}\n'
          '${order.distance.toStringAsFixed(2)} km • ${order.estimatedDurationMinutes} min • '
          'Fee NGN ${order.cost.toStringAsFixed(0)} • '
          'Rider NGN ${order.riderPayout.toStringAsFixed(0)} • '
          'Platform NGN ${order.platformCommission.toStringAsFixed(0)}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'View route',
          icon: const Icon(Icons.route),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RouteMapScreen(order: order)),
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 170,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);

  final String label;
  final String value;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.csv});

  final String label;
  final String csv;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.download),
      label: Text(label),
      onPressed: () => _showCsv(context, label, csv),
    );
  }
}

Future<String?> _askForText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void _showCsv(BuildContext context, String title, String csv) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: SelectableText(csv.isEmpty ? 'No records to export.' : csv),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy CSV'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: csv));
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report copied')),
            );
          },
        ),
      ],
    ),
  );
}

String _ordersCsv(List<Order> orders) {
  final rows = [
    'id,city,status,payment_status,customer_id,rider_id,distance_km,cost,platform_commission,rider_payout,pickup,dropoff',
    ...orders.map(
      (order) => [
        order.id,
        order.city,
        order.status,
        order.paymentStatus,
        order.customerId,
        order.riderId ?? '',
        order.distance.toStringAsFixed(2),
        order.cost.toStringAsFixed(0),
        order.platformCommission.toStringAsFixed(0),
        order.riderPayout.toStringAsFixed(0),
        order.pickupAddress,
        order.dropoffAddress,
      ].map(_csv).join(','),
    ),
  ];
  return rows.join('\n');
}

String _paymentsCsv(List<PaymentRecord> payments) {
  final rows = [
    'reference,order_id,customer_id,status,amount_ngn,platform_commission,rider_payout,provider',
    ...payments.map(
      (payment) => [
        payment.reference,
        payment.orderId,
        payment.customerId,
        payment.status,
        (payment.amountKobo / 100).toStringAsFixed(0),
        payment.platformCommission.toStringAsFixed(0),
        payment.riderPayout.toStringAsFixed(0),
        payment.provider,
      ].map(_csv).join(','),
    ),
  ];
  return rows.join('\n');
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
