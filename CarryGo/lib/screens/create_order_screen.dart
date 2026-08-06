import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/nigerian_cities.dart';
import '../constants/order_status.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/pricing_service.dart';
import '../widgets/carrygo_brand.dart';
import 'settings_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _pickupAddressController = TextEditingController();
  final _dropoffAddressController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupLatController = TextEditingController();
  final _pickupLngController = TextEditingController();
  final _dropoffLatController = TextEditingController();
  final _dropoffLngController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _city = 'Lagos';
  String _paymentMethod = 'card';
  String _itemType = 'Documents';
  String _parcelSize = 'Small';
  String _parcelWeight = 'Light';
  String _fragility = 'Not fragile';
  String _urgency = 'Normal';
  final String _condition = 'Clear';
  String? _selectedRiderId;
  String _selectedRiderPhone = '';
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  double _distance = 0;
  int _estimatedDurationMinutes = 0;
  double _cost = 0;
  PricingResult? _pricing;
  DateTime? _desiredPickupTime;
  XFile? _parcelPhoto;
  Uint8List? _parcelPhotoBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _dropoffAddressController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _descriptionController.dispose();
    _pickupLatController.dispose();
    _pickupLngController.dispose();
    _dropoffLatController.dispose();
    _dropoffLngController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentGps({required bool isPickup}) async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final location = LatLng(position.latitude, position.longitude);
    if (isPickup) {
      _setPickupLocation(location);
    } else {
      _setDropoffLocation(location);
    }
  }

  void _setPickupLocation(LatLng location) {
    setState(() {
      _pickupLocation = location;
      _selectedRiderId = null;
      _selectedRiderPhone = '';
      _pickupLatController.text = location.latitude.toStringAsFixed(6);
      _pickupLngController.text = location.longitude.toStringAsFixed(6);
    });
    _calculateCost();
  }

  void _setDropoffLocation(LatLng location) {
    setState(() {
      _dropoffLocation = location;
      _dropoffLatController.text = location.latitude.toStringAsFixed(6);
      _dropoffLngController.text = location.longitude.toStringAsFixed(6);
    });
    _calculateCost();
  }

  void _syncCoordinates() {
    final pickupLat = double.tryParse(_pickupLatController.text);
    final pickupLng = double.tryParse(_pickupLngController.text);
    final dropoffLat = double.tryParse(_dropoffLatController.text);
    final dropoffLng = double.tryParse(_dropoffLngController.text);

    setState(() {
      _pickupLocation = pickupLat != null && pickupLng != null
          ? LatLng(pickupLat, pickupLng)
          : _pickupLocation;
      _dropoffLocation = dropoffLat != null && dropoffLng != null
          ? LatLng(dropoffLat, dropoffLng)
          : _dropoffLocation;
    });
    _calculateCost();
  }

  void _calculateCost() {
    final pickup = _pickupLocation;
    final dropoff = _dropoffLocation;
    if (pickup == null || dropoff == null) {
      _estimateAddressOnlyCost();
      return;
    }

    final distance = Geolocator.distanceBetween(
          pickup.latitude,
          pickup.longitude,
          dropoff.latitude,
          dropoff.longitude,
        ) /
        1000;
    final durationMinutes = _estimateDurationMinutes(distance);

    final pricing = PricingService.estimate(
      rule: PricingService.fallbackRule(_city),
      distanceKm: distance,
      parcelSize: _parcelSize,
      parcelWeight: _parcelWeight,
      urgency: _urgency,
      condition: _condition,
    );

    setState(() {
      _distance = distance;
      _estimatedDurationMinutes = durationMinutes;
      _cost = pricing.total;
      _pricing = pricing;
    });
  }

  void _estimateAddressOnlyCost() {
    final pricing = PricingService.estimate(
      rule: PricingService.fallbackRule(_city),
      distanceKm: 0,
      parcelSize: _parcelSize,
      parcelWeight: _parcelWeight,
      urgency: _urgency,
      condition: _condition,
    );

    setState(() {
      _distance = 0;
      _estimatedDurationMinutes = 0;
      _cost = pricing.total;
      _pricing = pricing;
    });
  }

  Future<void> _captureParcelPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1400,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _parcelPhoto = picked;
      _parcelPhotoBytes = bytes;
    });
  }

  Future<String> _uploadParcelPhoto(String orderId) async {
    final photo = _parcelPhoto;
    final bytes = _parcelPhotoBytes;
    if (photo == null || bytes == null) return '';
    final safeName = photo.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance.ref(
        'orders/$orderId/parcel_${DateTime.now().millisecondsSinceEpoch}_$safeName');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: photo.mimeType ?? 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  int _estimateDurationMinutes(double distanceKm) {
    const averageBikeSpeedKmh = 22;
    const pickupBufferMinutes = 5;
    final travelMinutes = (distanceKm / averageBikeSpeedKmh) * 60;
    return max(1, (travelMinutes + pickupBufferMinutes).ceil());
  }

  String _generateOtp() {
    final random = Random.secure();
    return List.generate(4, (_) => random.nextInt(10)).join();
  }

  Future<void> _selectPickupTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      initialDate: _desiredPickupTime ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _desiredPickupTime ?? now.add(const Duration(minutes: 30)),
      ),
    );
    if (time == null) return;
    setState(() {
      _desiredPickupTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatPickupTime(DateTime? value) {
    if (value == null) return 'Choose desired pick-up time';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} at $hour:$minute';
  }

  Future<void> _placeOrder() async {
    _syncCoordinates();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final photoUploadFailed = context
        .trRead('Order created, but the item photo could not be uploaded.');
    if (_pickupAddressController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context
              .trRead('Describe the pick-up address or landmark clearly.')),
        ),
      );
      return;
    }
    if (_dropoffAddressController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context
              .trRead('Describe the drop-off address or landmark clearly.')),
        ),
      );
      return;
    }
    if (_desiredPickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.trRead('Choose your desired pick-up time.'))),
      );
      return;
    }
    if (_selectedRiderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.trRead('Select an online rider before booking.')),
        ),
      );
      return;
    }
    if (_cost <= 0) {
      _calculateCost();
    }
    final confirmed = await _confirmBooking();
    if (!confirmed) return;

    setState(() => _isSubmitting = true);
    final user = auth.user;
    if (user == null) return;
    final paymentStatus = switch (_paymentMethod) {
      'cash' => 'cash_on_pickup',
      'wallet' => 'wallet_authorized',
      _ => 'unpaid',
    };
    final escrowStatus = switch (_paymentMethod) {
      'cash' => 'cash_to_collect',
      'wallet' => 'held_in_escrow',
      _ => 'awaiting_card_payment',
    };
    final initialStatus = _paymentMethod == 'card'
        ? OrderStatus.pendingPayment
        : OrderStatus.searchingRider;

    final order = Order(
      id: '',
      customerId: user.uid,
      city: _city,
      pickupLocation: _pickupLocation ?? const LatLng(0, 0),
      dropoffLocation: _dropoffLocation ?? const LatLng(0, 0),
      pickupAddress: _pickupAddressController.text.trim(),
      dropoffAddress: _dropoffAddressController.text.trim(),
      senderName: _senderNameController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
      receiverName: _receiverNameController.text.trim(),
      receiverPhone: _receiverPhoneController.text.trim(),
      parcelDescription: _descriptionController.text.trim(),
      itemType: _itemType,
      parcelSize: _parcelSize,
      parcelWeight: _parcelWeight,
      fragility: _fragility,
      urgency: _urgency,
      condition: _condition,
      distance: _distance,
      estimatedDurationMinutes: _estimatedDurationMinutes,
      cost: _cost,
      platformCommission: _pricing?.platformCommission ?? 0,
      riderPayout: _pricing?.riderPayout ?? 0,
      paymentMethod: _paymentMethod,
      paymentStatus: paymentStatus,
      escrowStatus: escrowStatus,
      status: initialStatus,
      riderId: _selectedRiderId,
      riderPhone: _selectedRiderPhone,
      desiredPickupTime: _desiredPickupTime,
      otp: _generateOtp(),
      pickupOtp: _generateOtp(),
    );

    await orderProvider.createOrder(order);
    try {
      final photoUrl = await _uploadParcelPhoto(order.id);
      if (photoUrl.isNotEmpty) {
        await orderProvider.attachParcelPhoto(
          orderId: order.id,
          photoUrl: photoUrl,
        );
        order.parcelPhotoUrl = photoUrl;
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(photoUploadFailed),
        ),
      );
    }
    var message = 'Order created. Searching for nearby riders.';

    if (_paymentMethod == 'card') {
      final paymentReference = await orderProvider.initializePaystackPayment(
        order,
        user.email ?? auth.profile?.email ?? '',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final paid = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(context.tr('Card payment')),
              icon: const Icon(Icons.credit_card),
              content: Text(
                '${context.tr('Reference')}: $paymentReference\n'
                '${context.tr('Amount')}: NGN ${order.cost.toStringAsFixed(0)}\n\n'
                '${context.tr('Card payment is verified before matching you with a rider.')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Pay later')),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.verified),
                  label: Text(context.tr('Verify payment')),
                ),
              ],
            ),
          ) ??
          false;

      if (paid) {
        await orderProvider.confirmPaystackPayment(order.id, paymentReference);
      }
      message = paid
          ? 'Card payment confirmed. Searching for nearby riders.'
          : 'Order created. Complete card payment from your dashboard.';
    } else if (_paymentMethod == 'wallet') {
      await orderProvider.authorizeWalletOrder(order.id);
      message = 'Wallet payment authorized. Searching for nearby riders.';
    } else {
      await orderProvider.activateCashOrder(order.id);
      message =
          'Cash booking created. Rider will collect cash at pick-up after accepting.';
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
    navigator.pop();
  }

  Future<bool> _confirmBooking() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Confirm booking')),
            content: Text(context.tr(
                'Please confirm that the pickup, drop-off, parcel and payment details are correct before booking a rider.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: Text(context.tr('Confirm booking')),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CarryGoAppBarTitle(label: 'New request'),
        actions: const [SettingsIconButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, context.tr('Route')),
            DropdownButtonFormField<String>(
              value: _city,
              decoration: InputDecoration(labelText: context.tr('City')),
              items: nigerianStateCapitalCities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _city = value ?? 'Lagos';
                  _selectedRiderId = null;
                  _selectedRiderPhone = '';
                });
                _calculateCost();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pickupAddressController,
              decoration: InputDecoration(
                labelText: context.tr('Pick-up address or landmark'),
                prefixIcon: const Icon(Icons.store_mall_directory),
                helperText: context.tr(
                    'Include street, gate, floor, nearby shop, or estate landmark.'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _useCurrentGps(isPickup: true),
              icon: const Icon(Icons.my_location),
              label: Text(context.tr('Use current GPS for pick-up')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dropoffAddressController,
              decoration: InputDecoration(
                  labelText: context.tr('Drop-off address or landmark')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _useCurrentGps(isPickup: false),
              icon: const Icon(Icons.my_location),
              label: Text(context.tr('Use current GPS for drop-off')),
            ),
            const SizedBox(height: 12),
            _LocationMapPicker(
              pickup: _pickupLocation,
              dropoff: _dropoffLocation,
              onPickupChanged: _setPickupLocation,
              onDropoffChanged: _setDropoffLocation,
            ),
            const SizedBox(height: 12),
            _NearbyRidersPanel(
              city: _city,
              pickupLocation: _pickupLocation,
              selectedRiderId: _selectedRiderId,
              onSelected: (rider) {
                setState(() {
                  _selectedRiderId = rider.id;
                  _selectedRiderPhone = rider.phone;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectPickupTime,
              icon: const Icon(Icons.schedule),
              label: Text(_formatPickupTime(_desiredPickupTime)),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, context.tr('Contacts')),
            TextField(
              controller: _senderNameController,
              decoration: InputDecoration(labelText: context.tr('Sender name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senderPhoneController,
              decoration:
                  InputDecoration(labelText: context.tr('Sender phone')),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiverNameController,
              decoration:
                  InputDecoration(labelText: context.tr('Receiver name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiverPhoneController,
              decoration:
                  InputDecoration(labelText: context.tr('Receiver phone')),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, context.tr('Parcel')),
            DropdownButtonFormField<String>(
              value: _itemType,
              decoration: InputDecoration(labelText: context.tr('Item type')),
              items: const [
                DropdownMenuItem(value: 'Documents', child: Text('Documents')),
                DropdownMenuItem(value: 'Food', child: Text('Food')),
                DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                DropdownMenuItem(value: 'Clothes', child: Text('Clothes')),
                DropdownMenuItem(value: 'Medicine', child: Text('Medicine')),
                DropdownMenuItem(
                    value: 'Electronics', child: Text('Electronics')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() => _itemType = value ?? 'Other');
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration:
                  InputDecoration(labelText: context.tr('Parcel description')),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            _ParcelPhotoField(
              photoBytes: _parcelPhotoBytes,
              photoName: _parcelPhoto?.name ?? '',
              onCapture: _captureParcelPhoto,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _parcelSize,
              decoration: InputDecoration(labelText: context.tr('Parcel size')),
              items: const [
                DropdownMenuItem(value: 'Small', child: Text('Small')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'Large', child: Text('Large')),
                DropdownMenuItem(
                    value: 'Extra Large', child: Text('Extra Large')),
              ],
              onChanged: (value) {
                setState(() => _parcelSize = value ?? 'Small');
                _calculateCost();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                PricingService.parcelSizeExamples[_parcelSize] ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _parcelWeight,
              decoration: InputDecoration(labelText: context.tr('Weight feel')),
              items: const [
                DropdownMenuItem(
                  value: 'Light',
                  child: Text('Light: can be carried with one hand'),
                ),
                DropdownMenuItem(
                  value: 'Medium',
                  child: Text('Medium: needs two hands but easy to carry'),
                ),
                DropdownMenuItem(
                  value: 'Heavy',
                  child: Text('Heavy: difficult or needs extra care'),
                ),
              ],
              onChanged: (value) {
                setState(() => _parcelWeight = value ?? 'Light');
                _calculateCost();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                PricingService.weightFeelExamples[_parcelWeight] ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _fragility,
              decoration: InputDecoration(labelText: context.tr('Fragility')),
              items: const [
                DropdownMenuItem(
                    value: 'Not fragile', child: Text('Not fragile')),
                DropdownMenuItem(value: 'Fragile', child: Text('Fragile')),
                DropdownMenuItem(
                    value: 'Very fragile', child: Text('Very fragile')),
              ],
              onChanged: (value) {
                setState(() => _fragility = value ?? 'Not fragile');
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(context.tr('Describe the item correctly')),
                subtitle: Text(
                  context.tr(
                      'Riders may reject wrongly described items or request admin review.'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _urgency,
              decoration: InputDecoration(labelText: context.tr('Urgency')),
              items: const [
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'Express', child: Text('Express')),
              ],
              onChanged: (value) {
                setState(() => _urgency = value ?? 'Normal');
                _calculateCost();
              },
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, context.tr('Payment')),
            _PaymentMethodSelector(
              value: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _syncCoordinates,
              icon: const Icon(Icons.calculate),
              label: Text(context.tr('Estimate delivery cost')),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _PricingBreakdown(
                  distance: _distance,
                  durationMinutes: _estimatedDurationMinutes,
                  pricing: _pricing,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _placeOrder,
              icon: Icon(_paymentMethod == 'cash'
                  ? Icons.delivery_dining
                  : _paymentMethod == 'wallet'
                      ? Icons.account_balance_wallet
                      : Icons.lock),
              label: Text(_isSubmitting
                  ? context.tr('Creating...')
                  : context.tr('Book')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PricingBreakdown extends StatelessWidget {
  final double distance;
  final int durationMinutes;
  final PricingResult? pricing;

  const _PricingBreakdown({
    required this.distance,
    required this.durationMinutes,
    required this.pricing,
  });

  @override
  Widget build(BuildContext context) {
    final pricing = this.pricing;
    if (pricing == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.payments),
        title: Text(context.tr('Estimate delivery cost')),
        subtitle:
            Text(context.tr('Enter pickup and drop-off coordinates first.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments),
          title: Text('NGN ${pricing.total.toStringAsFixed(0)}'),
          subtitle: Text(
            '${distance.toStringAsFixed(2)} km • $durationMinutes min estimated',
          ),
        ),
        _line(context, 'Base fare', pricing.baseFare),
        _line(context, 'Distance fee', pricing.distanceFee),
        _line(context, 'Size fee', pricing.sizeFee),
        _line(context, 'Weight fee', pricing.weightFee),
        Text(
          '${context.tr('Formula')}: (base + distance + size + weight) x ${context.tr('urgency')} ${pricing.urgencyMultiplier.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(),
        _line(context, 'Platform commission', pricing.platformCommission),
        _line(context, 'Rider payout', pricing.riderPayout),
      ],
    );
  }

  Widget _line(BuildContext context, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr(label)),
          Text('NGN ${value.toStringAsFixed(0)}'),
        ],
      ),
    );
  }
}

class _ParcelPhotoField extends StatelessWidget {
  final Uint8List? photoBytes;
  final String photoName;
  final VoidCallback onCapture;

  const _ParcelPhotoField({
    required this.photoBytes,
    required this.photoName,
    required this.onCapture,
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
              leading: const Icon(Icons.photo_camera),
              title: Text(context.tr('Item photo')),
              subtitle: Text(context.tr('Snap the item for the rider to see.')),
              trailing: OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt),
                label: Text(context.tr('Camera')),
              ),
            ),
            if (photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  photoBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                photoName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationMapPicker extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? dropoff;
  final ValueChanged<LatLng> onPickupChanged;
  final ValueChanged<LatLng> onDropoffChanged;

  const _LocationMapPicker({
    required this.pickup,
    required this.dropoff,
    required this.onPickupChanged,
    required this.onDropoffChanged,
  });

  static const _lagosCenter = LatLng(6.5244, 3.3792);

  @override
  Widget build(BuildContext context) {
    final initialTarget = pickup ?? dropoff ?? _lagosCenter;
    final markers = <Marker>{
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: context.tr('Pick-up')),
          onDragEnd: onPickupChanged,
        ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: context.tr('Drop-off')),
          onDragEnd: onDropoffChanged,
        ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.map),
            title: Text(context.tr('Google Map location')),
            subtitle: Text(context.tr(
              'Tap once for pick-up, tap again for drop-off. Drag pins to adjust.',
            )),
          ),
          SizedBox(
            height: 260,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: pickup == null && dropoff == null ? 11 : 14,
              ),
              myLocationButtonEnabled: true,
              myLocationEnabled: false,
              zoomControlsEnabled: true,
              markers: markers,
              onTap: (position) {
                if (pickup == null) {
                  onPickupChanged(position);
                } else {
                  onDropoffChanged(position);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableRider {
  final String id;
  final String name;
  final String phone;
  final String bike;
  final double? distanceKm;

  const _SelectableRider({
    required this.id,
    required this.name,
    required this.phone,
    required this.bike,
    required this.distanceKm,
  });
}

class _NearbyRidersPanel extends StatelessWidget {
  final String city;
  final LatLng? pickupLocation;
  final String? selectedRiderId;
  final ValueChanged<_SelectableRider> onSelected;

  const _NearbyRidersPanel({
    required this.city,
    required this.pickupLocation,
    required this.selectedRiderId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (pickupLocation == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.location_searching),
          title: Text(context.tr('Select pick-up location first')),
          subtitle: Text(context.tr(
              'Use GPS or tap the Google Map so nearby online riders can load.')),
        ),
      );
    }
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder(
      stream: orderProvider.watchAvailableRiders(city),
      builder: (context, snapshot) {
        final riderDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['city'] == city &&
              data['isOnline'] == true &&
              data['isVerified'] == true &&
              (data['status'] == null || data['status'] == 'available');
        }).toList();
        final riders = riderDocs.map((doc) {
          final data = doc.data();
          final riderLat = (data['currentLatitude'] as num?)?.toDouble();
          final riderLng = (data['currentLongitude'] as num?)?.toDouble();
          final distanceKm = riderLat == null || riderLng == null
              ? null
              : Geolocator.distanceBetween(
                    pickupLocation!.latitude,
                    pickupLocation!.longitude,
                    riderLat,
                    riderLng,
                  ) /
                  1000;
          final bike = [
            data['bikeModel'] as String? ?? '',
            data['bikeColor'] as String? ?? '',
            data['bikePlateNumber'] as String? ?? '',
          ].where((part) => part.trim().isNotEmpty).join(' ');
          return _SelectableRider(
            id: data['riderId'] as String? ?? doc.id,
            name: data['name'] as String? ?? 'Verified rider',
            phone: data['phone'] as String? ?? '',
            bike: bike.isEmpty ? 'Bike rider' : bike,
            distanceKm: distanceKm,
          );
        }).toList()
          ..sort((a, b) {
            final left = a.distanceKm ?? double.maxFinite;
            final right = b.distanceKm ?? double.maxFinite;
            return left.compareTo(right);
          });
        final count = riders.length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radar),
                  title: Text(count == 1
                      ? context.tr('1 nearby rider')
                      : '$count ${context.tr('nearby riders')}'),
                  subtitle: Text(
                    count == 0
                        ? '${context.tr('No verified online rider is visible in')} $city ${context.tr('right now.')}'
                        : context
                            .tr('Select one online rider for this booking.'),
                  ),
                ),
                if (count > 0)
                  for (final rider in riders)
                    RadioListTile<String>(
                      value: rider.id,
                      groupValue: selectedRiderId,
                      onChanged: (_) => onSelected(rider),
                      title: Text(rider.name),
                      subtitle: Text([
                        rider.bike,
                        if (rider.distanceKm != null)
                          '${rider.distanceKm!.toStringAsFixed(1)} km away',
                      ].join(' • ')),
                      secondary: const Icon(Icons.delivery_dining),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PaymentMethodSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'card',
          icon: const Icon(Icons.credit_card),
          label: Text(context.tr('Card')),
        ),
        ButtonSegment(
          value: 'wallet',
          icon: const Icon(Icons.account_balance_wallet),
          label: Text(context.tr('Wallet')),
        ),
        ButtonSegment(
          value: 'cash',
          icon: const Icon(Icons.payments),
          label: Text(context.tr('Cash')),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
