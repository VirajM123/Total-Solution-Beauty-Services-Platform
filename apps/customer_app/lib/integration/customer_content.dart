import 'customer_backend.dart';

/// Domain-only content boundaries. Public resource source exists on the server,
/// but its mounting, eligibility and media contract are not yet available.
class PublishedPackage {
  const PublishedPackage({
    required this.id,
    required this.name,
    required this.serviceIds,
    required this.totalPaise,
    this.imageUrl,
  });
  final String id, name;
  final List<String> serviceIds;
  final int totalPaise;
  final Uri? imageUrl;
}

class EligibleOffer {
  const EligibleOffer({
    required this.id,
    required this.title,
    required this.expiresAt,
  });
  final String id, title;
  final DateTime expiresAt;
}

class PublishedBanner {
  const PublishedBanner({
    required this.id,
    required this.imageUrl,
    required this.displayOrder,
    this.targetId,
  });
  final String id;
  final Uri imageUrl;
  final int displayOrder;
  final String? targetId;
}

class CustomerNotice {
  const CustomerNotice({
    required this.id,
    required this.title,
    required this.read,
  });
  final String id, title;
  final bool read;
}

class BookingReview {
  BookingReview({
    required this.bookingId,
    required this.rating,
    required this.comment,
  }) {
    if (rating < 1 || rating > 5) throw ArgumentError.value(rating, 'rating');
  }
  final String bookingId, comment;
  final int rating;
}

abstract interface class CustomerContentBackend {
  Future<List<PublishedPackage>> packages({required int page});
  Future<List<EligibleOffer>> offers({required int page});
  Future<List<PublishedBanner>> banners();
  Future<List<CustomerNotice>> notifications({required int page});
  Future<void> markNotificationRead(String id);
  Future<void> submitReview(BookingReview review);
}

class PendingCustomerContentBackend implements CustomerContentBackend {
  const PendingCustomerContentBackend();
  @override
  Future<List<PublishedPackage>> packages({required int page}) async =>
      throw const IntegrationPending('Published packages');
  @override
  Future<List<EligibleOffer>> offers({required int page}) async =>
      throw const IntegrationPending('Eligible offers');
  @override
  Future<List<PublishedBanner>> banners() async =>
      throw const IntegrationPending('Published banners');
  @override
  Future<List<CustomerNotice>> notifications({required int page}) async =>
      throw const IntegrationPending('Customer notifications');
  @override
  Future<void> markNotificationRead(String id) async =>
      throw const IntegrationPending('Notification update');
  @override
  Future<void> submitReview(BookingReview review) async =>
      throw const IntegrationPending('Booking review');
}
