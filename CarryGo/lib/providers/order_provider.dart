import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../constants/order_status.dart';
import '../models/payment_record.dart';
import '../models/order.dart';
import '../services/carrygo_backend_service.dart';
import '../services/paystack_service.dart';
import '../constants/payment_config.dart';
import '../services/pricing_service.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaystackService _paystackService = PaystackService();
  final CarryGoBackendService _backendService = CarryGoBackendService();
  List<Order> _orders = [];

  List<Order> get orders => _orders;

  Stream<List<PaymentRecord>> watchPayments() {
    return _firestore
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromFirestore(doc))
            .toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAdminWalletEntries() {
    return _firestore
        .collection('admin_wallet')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWalletTransactions(
    String userId,
  ) {
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWithdrawalRequests({
    String userId = '',
  }) {
    var query = _firestore.collection('withdrawal_requests');
    if (userId.isNotEmpty) {
      return query.where('userId', isEqualTo: userId).snapshots();
    }
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<PricingRule?> watchPricingRule(String city) {
    return _firestore.collection('pricing_rules').doc(city).snapshots().map(
          (doc) => doc.exists
              ? PricingRule.fromMap(city, doc.data() ?? const {})
              : null,
        );
  }

  Future<PricingRule?> getPricingRule(String city) async {
    final doc = await _firestore.collection('pricing_rules').doc(city).get();
    if (!doc.exists) return null;
    return PricingRule.fromMap(city, doc.data() ?? const {});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<List<Order>> watchCompletedRiderOrders(String riderId) {
    return _firestore
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('status', isEqualTo: OrderStatus.delivered)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRiderPayouts(
    String riderId,
  ) {
    return _firestore
        .collection('payouts')
        .where('riderId', isEqualTo: riderId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRiderRatings(
    String riderId,
  ) {
    return _firestore
        .collection('ratings')
        .where('riderId', isEqualTo: riderId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAvailableRiders(
    String city,
  ) {
    return _firestore
        .collection('public_riders')
        .where('isOnline', isEqualTo: true)
        .snapshots();
  }

  Future<void> loadOrders(String userId, String role) async {
    Query query;
    if (role == 'customer') {
      query = _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId);
    } else if (role == 'admin') {
      query = _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true);
    } else {
      query = _firestore.collection('orders').where('status', whereIn: [
        OrderStatus.searchingRider,
        OrderStatus.accepted,
        OrderStatus.pickedUp,
        OrderStatus.inTransit
      ]);
    }
    QuerySnapshot snapshot = await query.get();
    _orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Stream<List<Order>> watchOrders(String userId, String role) {
    Query query;
    if (role == 'customer') {
      query = _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId);
    } else if (role == 'admin') {
      query = _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true);
    } else {
      query = _firestore.collection('orders').where('status', whereIn: [
        OrderStatus.searchingRider,
        OrderStatus.accepted,
        OrderStatus.pickedUp,
        OrderStatus.inTransit
      ]);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList());
  }

  Future<void> createOrder(Order order) async {
    DocumentReference doc =
        await _firestore.collection('orders').add(order.toFirestore());
    order.id = doc.id;
    _orders.add(order);
    notifyListeners();
  }

  Future<void> attachParcelPhoto({
    required String orderId,
    required String photoUrl,
  }) async {
    await _firestore.collection('orders').doc(orderId).set({
      'parcelPhotoUrl': photoUrl,
      'parcel_photo_url': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> activateCashOrder(String orderId) async {
    await _notifyRiders(
      orderId,
      'New cash request',
      'A CarryGo customer wants cash collected at pick-up.',
    );
  }

  Future<void> authorizeWalletOrder(String orderId) async {
    await _notifyRiders(
      orderId,
      'New wallet-paid request',
      'A wallet-funded CarryGo request is ready for a rider.',
    );
  }

  Future<PaystackInitResult> initializeWalletTopup({
    required String userId,
    required String role,
    required String email,
    required double amount,
  }) async {
    final result = await _paystackService.initializeWalletTopup(
      amount: amount,
      email: email,
      walletRole: role,
    );
    if (result.demoMode) {
      await _firestore
          .collection('wallet_transactions')
          .doc(result.reference)
          .set({
        'userId': userId,
        'role': role,
        'amount': amount,
        'amountKobo': (amount * 100).round(),
        'currency': 'NGN',
        'type': 'topup',
        'direction': 'credit',
        'status': 'initialized',
        'provider': 'paystack',
        'reference': result.reference,
        'authorizationUrl': result.authorizationUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return result;
  }

  Future<bool> confirmWalletTopup(String reference) async {
    final verification = await _paystackService.verifyWalletTopup(reference);
    if (!verification.success) {
      await _firestore.collection('wallet_transactions').doc(reference).set({
        'status': 'failed',
        'verificationStatus': verification.status,
        'verificationMessage': verification.message,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }
    await _firestore.collection('wallet_transactions').doc(reference).set({
      'status': 'available',
      'verificationStatus': verification.status,
      'verificationMessage': verification.message,
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<void> requestWithdrawal({
    required String userId,
    required String role,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    await _firestore.collection('withdrawal_requests').add({
      'userId': userId,
      'role': role,
      'amount': amount,
      'amountKobo': (amount * 100).round(),
      'currency': 'NGN',
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWithdrawalStatus({
    required String requestId,
    required String status,
    String note = '',
  }) async {
    await _firestore.collection('withdrawal_requests').doc(requestId).set({
      'status': status,
      'adminNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptOrder({
    required String orderId,
    required String riderId,
    required String riderPhone,
    DateTime? acceptedPickupTime,
  }) async {
    final pickupTimestamp = acceptedPickupTime == null
        ? null
        : Timestamp.fromDate(acceptedPickupTime);
    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.accepted,
      'order_status': OrderStatus.accepted,
      'riderId': riderId,
      'rider_id': riderId,
      'riderPhone': riderPhone,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedPickupTime': pickupTimestamp,
      'accepted_pickup_time': pickupTimestamp,
      'pickupTimeStatus': 'accepted',
      'pickup_time_status': 'accepted',
      'isLocked': true,
    });
    await _firestore.collection('notifications').add({
      'userId': null,
      'role': 'customer',
      'title': 'Rider accepted',
      'body': 'A verified rider accepted your CarryGo request.',
      'type': 'order_status',
      'orderId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    int index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = OrderStatus.accepted;
      _orders[index].riderId = riderId;
      _orders[index].riderPhone = riderPhone;
      _orders[index].acceptedPickupTime = acceptedPickupTime;
      _orders[index].pickupTimeStatus = 'accepted';
      _orders[index].isLocked = true;
      notifyListeners();
    }
  }

  Future<void> rejectOrder(String orderId, String riderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'rejectedRiderIds': FieldValue.arrayUnion([riderId]),
    });
    _orders.removeWhere((order) => order.id == orderId);
    notifyListeners();
  }

  Future<void> updateStatus(String orderId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'order_status': status,
    };
    if (status == OrderStatus.pickedUp) {
      updates['pickupConfirmedAt'] = FieldValue.serverTimestamp();
    }
    if (status == OrderStatus.inTransit) {
      updates['inTransitAt'] = FieldValue.serverTimestamp();
    }
    if (status == OrderStatus.delivered) {
      updates['deliveredAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection('orders').doc(orderId).update(updates);
    int index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].status = status;
      notifyListeners();
    }
  }

  Future<bool> confirmPickup(String orderId, String otp) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    final order = Order.fromFirestore(doc);
    if (order.pickupOtp != otp) return false;
    await updateStatus(orderId, OrderStatus.pickedUp);
    return true;
  }

  Future<bool> confirmDelivery(String orderId, String otp) async {
    if (PaymentConfig.hasBackend) {
      return _backendService.confirmDeliveryOtp(orderId: orderId, otp: otp);
    }
    final doc = await _firestore.collection('orders').doc(orderId).get();
    final order = Order.fromFirestore(doc);
    if (order.otp != otp) return false;
    await updateStatus(orderId, OrderStatus.delivered);
    await recordRiderPayout(order);
    return true;
  }

  Future<void> addReview(String orderId, double rating, String review) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    final order = Order.fromFirestore(orderDoc);
    await _firestore.collection('orders').doc(orderId).update({
      'rating': rating,
      'review': review,
    });
    await _firestore.collection('ratings').add({
      'orderId': orderId,
      'customerId': order.customerId,
      'riderId': order.riderId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> initializePaystackPayment(Order order, String email) async {
    final result = await _paystackService.initializeTransaction(
      order: order,
      email: email,
    );

    if (result.demoMode) {
      await _firestore.collection('payments').doc(result.reference).set({
        'orderId': order.id,
        'customerId': order.customerId,
        'email': email,
        'amountKobo': (order.cost * 100).round(),
        'currency': 'NGN',
        'provider': 'paystack',
        'status': 'initialized',
        'authorizationUrl': result.authorizationUrl,
        'accessCode': result.accessCode,
        'demoMode': result.demoMode,
        'platformCommission': order.platformCommission,
        'riderPayout': order.riderPayout,
        'split': {
          'enabled': false,
          'platformCommissionKobo': (order.platformCommission * 100).round(),
          'riderPayoutKobo': (order.riderPayout * 100).round(),
          'riderSubaccount': null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('orders').doc(order.id).update({
        'paymentReference': result.reference,
        'paymentStatus': 'initialized',
        'payment_status': 'initialized',
        'escrowStatus': 'awaiting_card_payment',
        'escrow_status': 'awaiting_card_payment',
        'status': OrderStatus.pendingPayment,
        'order_status': OrderStatus.pendingPayment,
      });
    }
    return result.reference;
  }

  Future<void> confirmPaystackPayment(String orderId, String reference) async {
    final verification = await _paystackService.verifyTransaction(reference);
    if (!verification.success) {
      if (!PaymentConfig.hasBackend) {
        await markPaystackPaymentFailed(
          orderId: orderId,
          reference: reference,
          reason: verification.message,
        );
      }
      throw StateError('Payment verification failed: ${verification.message}');
    }

    if (!PaymentConfig.hasBackend) {
      await _firestore.collection('payments').doc(reference).set({
        'status': 'paid',
        'verificationStatus': verification.status,
        'verificationMessage': verification.message,
        'paidAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _recordAdminCommissionFromPayment(reference);
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'paid',
        'payment_status': 'paid',
        'escrowStatus': 'held_in_escrow',
        'escrow_status': 'held_in_escrow',
        'status': OrderStatus.searchingRider,
        'order_status': OrderStatus.searchingRider,
        'matchingStartedAt': FieldValue.serverTimestamp(),
      });
      await _notifyRiders(
        orderId,
        'New card-paid request',
        'A card-funded CarryGo request is held in escrow and ready for a rider.',
      );
    }
  }

  Future<void> markPaystackPaymentFailed({
    required String orderId,
    required String reference,
    required String reason,
  }) async {
    await _firestore.collection('payments').doc(reference).set({
      'status': 'failed',
      'failureReason': reason,
      'failedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('orders').doc(orderId).update({
      'paymentStatus': 'failed',
      'payment_status': 'failed',
      'status': OrderStatus.pendingPayment,
      'order_status': OrderStatus.pendingPayment,
    });
  }

  Future<void> requestRefund({
    required Order order,
    required String reason,
  }) async {
    final complaint = await _firestore.collection('complaints').add({
      'orderId': order.id,
      'paymentReference': order.paymentReference,
      'customerId': order.customerId,
      'amountKobo': (order.cost * 100).round(),
      'reason': reason,
      'status': 'refund_requested',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('payments').doc(order.paymentReference).set({
      'status': 'refund_requested',
      'complaintId': complaint.id,
      'refundRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('orders').doc(order.id).update({
      'paymentStatus': 'refund_requested',
      'payment_status': 'refund_requested',
      'status': OrderStatus.disputed,
      'order_status': OrderStatus.disputed,
    });
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    String adminNote = '',
  }) async {
    await _firestore.collection('complaints').doc(complaintId).set({
      'status': status,
      'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markRefunded({
    required String complaintId,
    required String orderId,
    required String paymentReference,
    String adminNote = '',
  }) async {
    await _firestore.collection('complaints').doc(complaintId).set({
      'status': 'refunded',
      'adminNote': adminNote,
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('payments').doc(paymentReference).set({
      'status': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('orders').doc(orderId).set({
      'status': OrderStatus.refunded,
      'order_status': OrderStatus.refunded,
      'paymentStatus': 'refunded',
      'payment_status': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> savePricingRule({
    required String city,
    required double baseFare,
    required double perKmRate,
    required double commissionRate,
    required double minimumBillableDistanceKm,
    required double roundingStep,
    required Map<String, double> sizeFees,
    required Map<String, double> weightFees,
    required Map<String, double> urgencyMultipliers,
  }) async {
    await _firestore.collection('pricing_rules').doc(city).set({
      'city': city,
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'commissionRate': commissionRate,
      'minimumBillableDistanceKm': minimumBillableDistanceKm,
      'roundingStep': roundingStep,
      'sizeFees': sizeFees,
      'weightFees': weightFees,
      'urgencyMultipliers': urgencyMultipliers,
      'currency': 'NGN',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('cities').doc(city).set({
      'name': city,
      'baseFare': baseFare,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendAdminNotification({
    required String audienceRole,
    required String title,
    required String body,
    String orderId = '',
  }) async {
    await _firestore.collection('notifications').add({
      'userId': null,
      'role': audienceRole,
      'title': title,
      'body': body,
      'type': 'admin_broadcast',
      'orderId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> initializeFirestoreStructure() async {
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    void schemaDoc(String collection, Map<String, dynamic> fields) {
      batch.set(
        _firestore.collection(collection).doc('_schema'),
        {
          'is_schema_placeholder': true,
          'collection': collection,
          'fields': fields,
          'created_at': now,
          'updated_at': now,
        },
        SetOptions(merge: true),
      );
    }

    schemaDoc('users', {
      'name': 'string',
      'fullName': 'string',
      'email': 'string',
      'phone': 'string',
      'role': 'customer | rider | admin',
      'isApproved': 'boolean',
      'city': 'string',
      'accountStatus': 'active | suspended',
      'createdAt': 'timestamp',
    });
    schemaDoc('riders', {
      'userId': 'string',
      'bikeNumber': 'string',
      'city': 'string',
      'isVerified': 'boolean',
      'isOnline': 'boolean',
      'currentLatitude': 'number | null',
      'currentLongitude': 'number | null',
      'verificationStatus': 'pending | approved | rejected',
      'status': 'offline | available | busy | suspended',
      'bikePlateNumber': 'string',
      'bankAccountNumber': 'string',
      'createdAt': 'timestamp',
    });
    schemaDoc('orders', {
      'customer_id': 'string',
      'rider_id': 'string | null',
      'pickup_address': 'string',
      'pickup_latitude': 'number',
      'pickup_longitude': 'number',
      'dropoff_address': 'string',
      'dropoff_latitude': 'number',
      'dropoff_longitude': 'number',
      'parcel_size': 'Small | Medium | Large | Extra Large',
      'parcel_weight': 'Light | Medium | Heavy',
      'distance_km': 'number',
      'delivery_fee': 'number',
      'payment_status': 'unpaid | initialized | paid | failed | refunded',
      'order_status': OrderStatus.all.join(' | '),
      'created_at': 'timestamp',
    });
    schemaDoc('payments', {
      'orderId': 'string',
      'customerId': 'string',
      'amountKobo': 'number',
      'status': 'initialized | paid | failed | refunded',
      'provider': 'paystack',
      'createdAt': 'timestamp',
    });
    schemaDoc('pricing_rules', {
      'city': 'string',
      'baseFare': 'number',
      'perKmRate': 'number',
      'commissionRate': 'number',
      'updatedAt': 'timestamp',
    });
    schemaDoc('cities', {
      'name': 'string',
      'baseFare': 'number',
      'isActive': 'boolean',
      'updatedAt': 'timestamp',
    });
    schemaDoc('ratings', {
      'orderId': 'string',
      'customerId': 'string',
      'riderId': 'string',
      'rating': 'number',
      'review': 'string',
      'createdAt': 'timestamp',
    });
    schemaDoc('complaints', {
      'orderId': 'string',
      'paymentReference': 'string',
      'customerId': 'string',
      'reason': 'string',
      'status': 'open | under_review | resolved | refunded',
      'createdAt': 'timestamp',
    });
    schemaDoc('notifications', {
      'userId': 'string | null',
      'role': 'customer | rider | all',
      'title': 'string',
      'body': 'string',
      'isRead': 'boolean',
      'createdAt': 'timestamp',
    });
    schemaDoc('admin_logs', {
      'adminId': 'string',
      'action': 'string',
      'entityType': 'string',
      'entityId': 'string',
      'createdAt': 'timestamp',
    });
    schemaDoc('admin_wallet', {
      'orderId': 'string',
      'paymentReference': 'string',
      'customerId': 'string',
      'amount': 'number',
      'amountKobo': 'number',
      'currency': 'NGN',
      'paymentMethod': 'card | wallet | cash',
      'status': 'available | cash_due',
      'type': 'platform_commission',
      'createdAt': 'timestamp',
    });
    schemaDoc('wallet_transactions', {
      'userId': 'string',
      'role': 'customer | rider | admin',
      'amount': 'number',
      'currency': 'NGN',
      'type': 'topup | cash_commission',
      'direction': 'credit | debit',
      'status': 'initialized | available | due | paid | failed',
      'reference': 'string',
      'createdAt': 'timestamp',
    });
    schemaDoc('withdrawal_requests', {
      'userId': 'string',
      'role': 'rider | admin',
      'amount': 'number',
      'bankName': 'string',
      'accountNumber': 'string',
      'accountName': 'string',
      'status': 'pending | paid | rejected',
      'createdAt': 'timestamp',
    });

    await batch.commit();
  }

  Future<void> recordRiderPayout(Order order) async {
    if ((order.riderId ?? '').isEmpty) return;
    final payableStatuses = {
      'paid',
      'wallet_authorized',
      'cash_collected',
      'cash_on_pickup',
    };
    if (!payableStatuses.contains(order.paymentStatus)) return;
    await _firestore.collection('payouts').doc(order.id).set({
      'orderId': order.id,
      'riderId': order.riderId,
      'paymentReference': order.paymentReference,
      'amount': order.riderPayout,
      'amountKobo': (order.riderPayout * 100).round(),
      'platformCommission': order.platformCommission,
      'currency': 'NGN',
      'paymentMethod': order.paymentMethod,
      'status': 'available_in_wallet',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (order.paymentMethod == 'cash' && (order.riderId ?? '').isNotEmpty) {
      await _firestore
          .collection('wallet_transactions')
          .doc('${order.id}_commission')
          .set({
        'userId': order.riderId,
        'role': 'rider',
        'orderId': order.id,
        'amount': -order.platformCommission,
        'amountKobo': (-order.platformCommission * 100).round(),
        'currency': 'NGN',
        'type': 'cash_commission',
        'direction': 'debit',
        'status': 'due',
        'description': 'Commission due on cash ride',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _firestore.collection('admin_wallet').doc(order.id).set({
      'orderId': order.id,
      'paymentReference': order.paymentReference,
      'amount': order.platformCommission,
      'amountKobo': (order.platformCommission * 100).round(),
      'currency': 'NGN',
      'paymentMethod': order.paymentMethod,
      'status': order.paymentMethod == 'cash' ? 'cash_due' : 'available',
      'type': 'platform_commission',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('orders').doc(order.id).set({
      'escrowStatus': 'released_to_rider_wallet',
      'escrow_status': 'released_to_rider_wallet',
      'riderWalletCreditedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _recordAdminCommissionFromPayment(String reference) async {
    final payment =
        await _firestore.collection('payments').doc(reference).get();
    final data = payment.data();
    if (data == null) return;
    final commission = (data['platformCommission'] as num?)?.toDouble() ?? 0;
    if (commission <= 0) return;
    await _firestore.collection('admin_wallet').doc(reference).set({
      'paymentReference': reference,
      'orderId': data['orderId'] as String? ?? '',
      'customerId': data['customerId'] as String? ?? '',
      'amount': commission,
      'amountKobo': (commission * 100).round(),
      'currency': data['currency'] as String? ?? 'NGN',
      'paymentMethod': 'card',
      'status': 'available',
      'type': 'platform_commission',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> proposePickupTime({
    required String orderId,
    required String riderId,
    required String riderPhone,
    required DateTime proposedTime,
  }) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.accepted,
      'order_status': OrderStatus.accepted,
      'riderId': riderId,
      'rider_id': riderId,
      'riderPhone': riderPhone,
      'proposedPickupTime': Timestamp.fromDate(proposedTime),
      'proposed_pickup_time': Timestamp.fromDate(proposedTime),
      'pickupTimeStatus': 'rider_proposed_change',
      'pickup_time_status': 'rider_proposed_change',
      'isLocked': false,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectProposedPickupTime(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderStatus.cancelled,
      'order_status': OrderStatus.cancelled,
      'pickupTimeStatus': 'customer_rejected_change',
      'pickup_time_status': 'customer_rejected_change',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptProposedPickupTime({
    required String orderId,
    required DateTime proposedTime,
  }) async {
    await _firestore.collection('orders').doc(orderId).update({
      'acceptedPickupTime': Timestamp.fromDate(proposedTime),
      'accepted_pickup_time': Timestamp.fromDate(proposedTime),
      'pickupTimeStatus': 'accepted',
      'pickup_time_status': 'accepted',
      'isLocked': true,
      'status': OrderStatus.accepted,
      'order_status': OrderStatus.accepted,
    });
  }

  Future<void> _notifyRiders(
    String orderId,
    String title,
    String body,
  ) async {
    await _firestore.collection('notifications').add({
      'userId': null,
      'role': 'rider',
      'title': title,
      'body':
          '$body Riders receive in-app alert, text-message placeholder, and beep.',
      'type': 'order_request',
      'orderId': orderId,
      'sound': 'booking_beep',
      'smsQueued': true,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
