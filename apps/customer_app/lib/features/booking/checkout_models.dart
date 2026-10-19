/// Stable values for the future booking API. UI text belongs in the view layer.
enum BookingStatus {
  pendingAssignment,
  confirmed,
  assigned,
  inProgress,
  completed,
  cancelled,
}

enum PaymentStatus { pending, paid, failed, refunded }

enum CheckoutPaymentMethod { upi, card, cashOnService }

enum PaymentTiming { now, afterService }

/// A local snapshot for the development checkout preview, not a booking record.
class CheckoutPreview {
  const CheckoutPreview({
    required this.services,
    required this.date,
    required this.time,
    required this.bookingPreference,
    required this.addressLabel,
    required this.addressDetails,
    required this.subtotal,
    required this.discount,
    required this.convenienceFee,
    required this.total,
    required this.paymentMethod,
  });

  final List<PreviewService> services;
  final DateTime date;
  final String time;
  final String bookingPreference;
  final String addressLabel;
  final String addressDetails;
  final int subtotal;
  final int discount;
  final int convenienceFee;
  final int total;
  final CheckoutPaymentMethod paymentMethod;

  BookingStatus get bookingStatus => BookingStatus.confirmed;
  PaymentStatus get paymentStatus => PaymentStatus.pending;
  PaymentTiming get paymentTiming =>
      paymentMethod == CheckoutPaymentMethod.cashOnService
      ? PaymentTiming.afterService
      : PaymentTiming.now;
}

class PreviewService {
  const PreviewService({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  int get lineTotal => quantity * unitPrice;
}
