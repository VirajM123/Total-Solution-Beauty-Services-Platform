import 'package:flutter/foundation.dart';

/// UI-only additional service. Prices are customer charges, not worker payouts.
@immutable
class WorkerExtraServiceItem {
  const WorkerExtraServiceItem({
    required this.id,
    required this.name,
    required this.customerPrice,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final int customerPrice;
  final int durationMinutes;
}

/// Sample catalog only. Production prices must come from the backend.
const previewWorkerExtraServices = <WorkerExtraServiceItem>[
  WorkerExtraServiceItem(id: 'face-bleach', name: 'Face Bleach', customerPrice: 600, durationMinutes: 20),
  WorkerExtraServiceItem(id: 'hair-spa', name: 'Hair Spa', customerPrice: 800, durationMinutes: 45),
  WorkerExtraServiceItem(id: 'manicure', name: 'Manicure', customerPrice: 500, durationMinutes: 30),
  WorkerExtraServiceItem(id: 'pedicure', name: 'Pedicure', customerPrice: 700, durationMinutes: 40),
  WorkerExtraServiceItem(id: 'threading', name: 'Threading', customerPrice: 150, durationMinutes: 15),
  WorkerExtraServiceItem(id: 'head-massage', name: 'Head Massage', customerPrice: 400, durationMinutes: 30),
];
