class OrderStatus {
  static const draft = 'draft';
  static const pendingPayment = 'pending_payment';
  static const paid = 'paid';
  static const searchingRider = 'searching_rider';
  static const accepted = 'accepted';
  static const pickedUp = 'picked_up';
  static const inTransit = 'in_transit';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';
  static const disputed = 'disputed';
  static const refunded = 'refunded';

  static const all = [
    draft,
    pendingPayment,
    paid,
    searchingRider,
    accepted,
    pickedUp,
    inTransit,
    delivered,
    cancelled,
    disputed,
    refunded,
  ];
}
