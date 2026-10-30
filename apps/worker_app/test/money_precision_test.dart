import 'package:flutter_test/flutter_test.dart';
import '../lib/features/home/worker_booking_data.dart';

void main() {
  test('bill display retains non-whole-rupee amounts', () {
    expect(formatCustomerPaise(10099), '₹100.99');
    expect(formatCustomerPaise(10000), '₹100');
    expect(formatCustomerPaise(5), '₹0.05');
  });

  test('worker booking payable display uses authoritative paise', () {
    const order = WorkerDashboardOrder(
      id: 'booking-1',
      customer: 'Customer',
      service: 'Service',
      time: '10:00 AM',
      location: 'Latur',
      customerPayable: 100,
      customerPayablePaise: 10099,
      status: 'Assigned',
    );
    expect(order.formattedCustomerPayable, '₹100.99');
  });
}
