import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/order_status.dart';

class Order {
  String id;
  String customerId;
  String city;
  LatLng pickupLocation;
  LatLng dropoffLocation;
  String pickupAddress;
  String dropoffAddress;
  String senderName;
  String senderPhone;
  String receiverName;
  String receiverPhone;
  String parcelDescription;
  String parcelPhotoUrl;
  String itemType;
  String parcelSize;
  String parcelWeight;
  String fragility;
  String urgency;
  String condition;
  double distance;
  int estimatedDurationMinutes;
  double cost;
  double platformCommission;
  double riderPayout;
  String paymentStatus;
  String paymentMethod;
  String escrowStatus;
  String paymentReference;
  String status;
  String otp;
  String pickupOtp;
  DateTime? desiredPickupTime;
  DateTime? acceptedPickupTime;
  DateTime? proposedPickupTime;
  String pickupTimeStatus;
  bool isLocked;
  int nearbyRiderCount;
  List<String> rejectedRiderIds;
  String? riderId;
  String? riderPhone;
  double? rating;
  String? review;

  Order({
    required this.id,
    required this.customerId,
    required this.city,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.parcelDescription,
    this.parcelPhotoUrl = '',
    this.itemType = 'Other',
    required this.parcelSize,
    required this.parcelWeight,
    this.fragility = 'Not fragile',
    required this.urgency,
    this.condition = 'Clear',
    required this.distance,
    this.estimatedDurationMinutes = 0,
    required this.cost,
    this.platformCommission = 0,
    this.riderPayout = 0,
    required this.otp,
    required this.pickupOtp,
    this.paymentStatus = 'unpaid',
    this.paymentMethod = 'card',
    this.escrowStatus = 'not_applicable',
    this.paymentReference = '',
    this.status = OrderStatus.draft,
    this.desiredPickupTime,
    this.acceptedPickupTime,
    this.proposedPickupTime,
    this.pickupTimeStatus = 'pending',
    this.isLocked = false,
    this.nearbyRiderCount = 0,
    this.rejectedRiderIds = const [],
    this.riderId,
    this.riderPhone,
    this.rating,
    this.review,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      customerId:
          data['customer_id'] as String? ?? data['customerId'] as String? ?? '',
      city: data['city'] as String? ?? 'Lagos',
      pickupLocation: LatLng(
        (data['pickup_latitude'] as num?)?.toDouble() ??
            (data['pickupLat'] as num?)?.toDouble() ??
            0,
        (data['pickup_longitude'] as num?)?.toDouble() ??
            (data['pickupLng'] as num?)?.toDouble() ??
            0,
      ),
      dropoffLocation: LatLng(
        (data['dropoff_latitude'] as num?)?.toDouble() ??
            (data['dropoffLat'] as num?)?.toDouble() ??
            (data['deliveryLat'] as num?)?.toDouble() ??
            0,
        (data['dropoff_longitude'] as num?)?.toDouble() ??
            (data['dropoffLng'] as num?)?.toDouble() ??
            (data['deliveryLng'] as num?)?.toDouble() ??
            0,
      ),
      pickupAddress: data['pickup_address'] as String? ??
          data['pickupAddress'] as String? ??
          '',
      dropoffAddress: data['dropoff_address'] as String? ??
          data['dropoffAddress'] as String? ??
          '',
      senderName: data['senderName'] as String? ?? '',
      senderPhone: data['senderPhone'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? '',
      receiverPhone: data['receiverPhone'] as String? ?? '',
      parcelDescription: data['parcelDescription'] as String? ?? '',
      parcelPhotoUrl: data['parcelPhotoUrl'] as String? ??
          data['parcel_photo_url'] as String? ??
          '',
      itemType: data['itemType'] as String? ?? 'Other',
      parcelSize: data['parcel_size'] as String? ??
          data['parcelSize'] as String? ??
          'Small',
      parcelWeight: data['parcel_weight'] as String? ??
          data['parcelWeight'] as String? ??
          'Light',
      fragility: data['fragility'] as String? ?? 'Not fragile',
      urgency: data['urgency'] as String? ?? 'Normal',
      condition: data['condition'] as String? ?? 'Clear',
      distance: (data['distance_km'] as num?)?.toDouble() ??
          (data['distance'] as num?)?.toDouble() ??
          0,
      estimatedDurationMinutes:
          (data['estimated_duration_minutes'] as num?)?.toInt() ??
              (data['estimatedDurationMinutes'] as num?)?.toInt() ??
              0,
      cost: (data['delivery_fee'] as num?)?.toDouble() ??
          (data['cost'] as num?)?.toDouble() ??
          0,
      platformCommission: (data['platformCommission'] as num?)?.toDouble() ?? 0,
      riderPayout: (data['riderPayout'] as num?)?.toDouble() ?? 0,
      paymentStatus: data['payment_status'] as String? ??
          data['paymentStatus'] as String? ??
          'unpaid',
      paymentMethod: data['payment_method'] as String? ??
          data['paymentMethod'] as String? ??
          'card',
      escrowStatus: data['escrow_status'] as String? ??
          data['escrowStatus'] as String? ??
          'not_applicable',
      paymentReference: data['paymentReference'] as String? ?? '',
      status: data['order_status'] as String? ??
          data['status'] as String? ??
          OrderStatus.draft,
      otp: data['delivery_otp'] as String? ?? data['otp'] as String? ?? '',
      pickupOtp: data['pickupOtp'] as String? ?? '',
      desiredPickupTime: (data['desiredPickupTime'] as Timestamp?)?.toDate() ??
          (data['desired_pickup_time'] as Timestamp?)?.toDate(),
      acceptedPickupTime:
          (data['acceptedPickupTime'] as Timestamp?)?.toDate() ??
              (data['accepted_pickup_time'] as Timestamp?)?.toDate(),
      proposedPickupTime:
          (data['proposedPickupTime'] as Timestamp?)?.toDate() ??
              (data['proposed_pickup_time'] as Timestamp?)?.toDate(),
      pickupTimeStatus: data['pickupTimeStatus'] as String? ??
          data['pickup_time_status'] as String? ??
          'pending',
      isLocked: data['isLocked'] as bool? ?? false,
      nearbyRiderCount: (data['nearbyRiderCount'] as num?)?.toInt() ??
          (data['nearby_rider_count'] as num?)?.toInt() ??
          0,
      rejectedRiderIds:
          List<String>.from(data['rejectedRiderIds'] as List? ?? const []),
      riderId: data['rider_id'] as String? ??
          data['riderId'] as String? ??
          data['deliveryPersonId'] as String?,
      riderPhone: data['riderPhone'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      review: data['review'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customer_id': customerId,
      'city': city,
      'pickupLat': pickupLocation.latitude,
      'pickupLng': pickupLocation.longitude,
      'dropoffLat': dropoffLocation.latitude,
      'dropoffLng': dropoffLocation.longitude,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLocation.latitude,
      'pickup_longitude': pickupLocation.longitude,
      'dropoff_address': dropoffAddress,
      'dropoff_latitude': dropoffLocation.latitude,
      'dropoff_longitude': dropoffLocation.longitude,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'parcelDescription': parcelDescription,
      'parcelPhotoUrl': parcelPhotoUrl,
      'parcel_photo_url': parcelPhotoUrl,
      'itemType': itemType,
      'parcelSize': parcelSize,
      'parcel_size': parcelSize,
      'parcelWeight': parcelWeight,
      'parcel_weight': parcelWeight,
      'fragility': fragility,
      'urgency': urgency,
      'condition': condition,
      'distance': distance,
      'distance_km': distance,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'cost': cost,
      'delivery_fee': cost,
      'platformCommission': platformCommission,
      'riderPayout': riderPayout,
      'paymentStatus': paymentStatus,
      'payment_status': paymentStatus,
      'paymentMethod': paymentMethod,
      'payment_method': paymentMethod,
      'escrowStatus': escrowStatus,
      'escrow_status': escrowStatus,
      'paymentReference': paymentReference,
      'status': status,
      'order_status': status,
      'otp': otp,
      'delivery_otp': otp,
      'pickupOtp': pickupOtp,
      'desiredPickupTime': desiredPickupTime == null
          ? null
          : Timestamp.fromDate(desiredPickupTime!),
      'desired_pickup_time': desiredPickupTime == null
          ? null
          : Timestamp.fromDate(desiredPickupTime!),
      'acceptedPickupTime': acceptedPickupTime == null
          ? null
          : Timestamp.fromDate(acceptedPickupTime!),
      'accepted_pickup_time': acceptedPickupTime == null
          ? null
          : Timestamp.fromDate(acceptedPickupTime!),
      'proposedPickupTime': proposedPickupTime == null
          ? null
          : Timestamp.fromDate(proposedPickupTime!),
      'proposed_pickup_time': proposedPickupTime == null
          ? null
          : Timestamp.fromDate(proposedPickupTime!),
      'pickupTimeStatus': pickupTimeStatus,
      'pickup_time_status': pickupTimeStatus,
      'isLocked': isLocked,
      'nearbyRiderCount': nearbyRiderCount,
      'nearby_rider_count': nearbyRiderCount,
      'rejectedRiderIds': rejectedRiderIds,
      'riderId': riderId,
      'rider_id': riderId,
      'riderPhone': riderPhone,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
