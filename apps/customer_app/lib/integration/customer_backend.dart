/// Mobile-owned boundaries awaiting verified, mounted customer contracts.
/// No speculative route strings or local-success implementations belong here.
class IntegrationPending implements Exception {
  const IntegrationPending(this.feature);
  final String feature;
  @override
  String toString() => '$feature requires an authenticated backend contract.';
}

enum CustomerSessionState { signedOut, authenticated, expired }

enum CollectionMethod { cash, upi }

enum CollectionStatus { pending, paid, failed, refunded }

String normalizeIndianMobile(String input) {
  var value = input.replaceAll(RegExp(r'[\s()-]'), '');
  if (value.startsWith('+91')) value = value.substring(3);
  if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
    throw const FormatException('Enter a valid Indian mobile number.');
  }
  return '+91$value';
}

class CustomerIdentity {
  const CustomerIdentity({
    required this.id,
    required this.phone,
    required this.name,
  });
  final String id;
  final String phone;
  final String name;
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.line,
    required this.city,
    required this.postalCode,
    required this.isDefault,
  });
  final String id, line, city, postalCode;
  final bool isDefault;
}

class CartLine {
  CartLine({required this.serviceId, required this.quantity}) {
    if (serviceId.isEmpty || quantity < 1) {
      throw ArgumentError('Invalid cart line');
    }
  }
  final String serviceId;
  final int quantity;
}

/// All amounts are integer paise, supplied by the server, never a UI calculation.
class CheckoutQuote {
  CheckoutQuote({
    required this.id,
    required this.totalPaise,
    required this.expiresAt,
  }) {
    if (id.isEmpty || totalPaise < 0) throw ArgumentError('Invalid quote');
  }
  final String id;
  final int totalPaise;
  final DateTime expiresAt;
}

class BookingRequest {
  const BookingRequest({
    required this.quoteId,
    required this.addressId,
    required this.slotId,
    required this.idempotencyKey,
    required this.method,
  });
  final String quoteId, addressId, slotId, idempotencyKey;
  final CollectionMethod method;
}

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.number,
    required this.status,
    required this.totalPaise,
    required this.paymentStatus,
  });
  final String id, number, status;
  final int totalPaise;
  final CollectionStatus paymentStatus;
}

abstract interface class CustomerBackend {
  Future<void> requestOtp(String phone);
  Future<CustomerIdentity> verifyOtp(String challengeId, String otp);
  Future<void> logout();
  Future<CustomerIdentity> profile();
  Future<CustomerIdentity> updateProfile(String name);
  Future<List<CustomerAddress>> addresses();
  Future<CustomerAddress> saveAddress(CustomerAddress address);
  Future<void> deleteAddress(String id);
  Future<List<CartLine>> cart();
  Future<List<CartLine>> updateCart(List<CartLine> lines);
  Future<CheckoutQuote> quote({String? coupon});
  Future<List<String>> availableSlots(DateTime date, String addressId);
  Future<CustomerBooking> createBooking(BookingRequest request);
  Future<List<CustomerBooking>> bookings({required int page});
  Future<CustomerBooking> booking(String id);
}

/// Fail-closed adapter until mobile identity, authorization and DTOs are agreed.
class PendingCustomerBackend implements CustomerBackend {
  const PendingCustomerBackend();
  Never _pending(String feature) => throw IntegrationPending(feature);
  @override
  Future<void> requestOtp(String phone) async {
    normalizeIndianMobile(phone);
    _pending('OTP');
  }

  @override
  Future<CustomerIdentity> verifyOtp(String challengeId, String otp) async =>
      _pending('OTP verification');
  @override
  Future<void> logout() async => _pending('Logout');
  @override
  Future<CustomerIdentity> profile() async => _pending('Profile');
  @override
  Future<CustomerIdentity> updateProfile(String name) async =>
      _pending('Profile update');
  @override
  Future<List<CustomerAddress>> addresses() async => _pending('Addresses');
  @override
  Future<CustomerAddress> saveAddress(CustomerAddress address) async =>
      _pending('Address save');
  @override
  Future<void> deleteAddress(String id) async => _pending('Address deletion');
  @override
  Future<List<CartLine>> cart() async => _pending('Cart');
  @override
  Future<List<CartLine>> updateCart(List<CartLine> lines) async =>
      _pending('Cart update');
  @override
  Future<CheckoutQuote> quote({String? coupon}) async =>
      _pending('Checkout quote');
  @override
  Future<List<String>> availableSlots(DateTime date, String addressId) async =>
      _pending('Availability');
  @override
  Future<CustomerBooking> createBooking(BookingRequest request) async =>
      _pending('Booking creation');
  @override
  Future<List<CustomerBooking>> bookings({required int page}) async =>
      _pending('Booking history');
  @override
  Future<CustomerBooking> booking(String id) async =>
      _pending('Booking tracking');
}
