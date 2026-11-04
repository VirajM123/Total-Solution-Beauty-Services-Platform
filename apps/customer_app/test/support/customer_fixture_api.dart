import 'package:customer_app/integration/customer_mobile_operations_api.dart';

/// Explicit backend fixture. Production screens never supply sample catalog data.
class CustomerFixtureApi extends CustomerMobileOperationsApi {
  static const catalog = <String, List<String>>{
    'Facial': ['Gold Facial', 'Gold Prime Facial', 'Normal Facial'],
    'Hair Care & Spa': ['Hair Spa'],
    'Makeup': ['Bridal Makeup', 'Party Makeup', 'Engagement Makeup'],
    'Waxing': [
      'Waxing',
      'Full Body Waxing',
      'Half Leg Waxing',
      'Full Leg Waxing',
    ],
    'Manicure & Pedicure': ['Manicure', 'Pedicure', 'Gel Polish', 'Nail Care'],
    'Threading': [
      'Eyebrow Threading',
      'Upper Lip Threading',
      'Chin Threading',
      'Full Face Threading',
    ],
    'Bridal Services': [
      'Bridal Facial',
      'Bridal Hair',
      'Bridal Care',
      'Pre Bridal Care',
    ],
    'Beauty Packages': [
      'Glow Package',
      'Relaxation Package',
      'Engagement Package',
      'Complete Beauty Package',
    ],
    'Body Polish': [
      'Full Body Polish',
      'Arm Polish',
      'Leg Polish',
      'Back Polish',
    ],
    'Clean Up': [
      'Fruit Clean Up',
      'Herbal Clean Up',
      'Anti Acne Clean Up',
      'Detan Clean Up',
    ],
    'Hair Color': [
      'Global Hair Color',
      'Root Touch-Up',
      'Highlights',
      'Balayage',
      'Hair Gloss',
    ],
    'Hair Mehendi': [
      'Full Hair Mehendi',
      'Root Mehendi',
      'Mehendi Application',
    ],
    'Hair Cut': [
      'Women’s Haircut',
      'Layer Cut',
      'Step Cut',
      'Bob Cut',
      'Hair Trim',
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    for (final entry in catalog.entries)
      for (final name in entry.value)
        {
          '_id': (catalog.values.expand((v) => v).toList().indexOf(name) + 1)
              .toRadixString(16)
              .padLeft(24, '0'),
          'name': name,
          'category': {'name': entry.key},
          'pricePaise': 120000,
          'durationMinutes': 60,
        },
  ];
  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async =>
      path.endsWith('/categories')
      ? [
          for (final name in catalog.keys) {'name': name},
        ]
      : [];
  @override
  Future<List<Map<String, dynamic>>> getAddresses() async => [];
  @override
  Future<List<Map<String, dynamic>>> getBookings() async => [];
  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'user': {'fullName': 'Fixture customer'},
  };
  @override
  Future<Map<String, dynamic>> getAccountData(String section) async => {
    'items': [],
  };
  @override
  Future<Map<String, dynamic>> getNotificationPreferences() async => {
    'notificationsEnabled': true,
    'marketingNotificationsEnabled': true,
  };
  @override
  Future<void> saveCartDraft(List<Map<String, dynamic>> items) async {}
}
