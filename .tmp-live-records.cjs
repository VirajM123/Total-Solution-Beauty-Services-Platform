const fs=require('fs');
let file='beauty-services/apps/customer_app/lib/features/home/development_home_screen.dart';
let s=fs.readFileSync(file,'utf8');
function range(a,b,v=''){const i=s.indexOf(a),j=s.indexOf(b,i+1);if(i<0||j<0)throw Error(a);s=s.slice(0,i)+v+'\n'+s.slice(j);}
s=s.replace('  String? _liveBookingId;', '  String? _liveBookingId;\n  Map<String, dynamic>? _serverBooking;');
range("          final items = active['items'] as List?;",'          final totalPaise', '');
range('            _checkoutPreview = CheckoutPreview(','          });\n          _startLiveBookingSync(bid);', '            _serverBooking = active;\n            _checkoutPreview = _previewFromBooking(active);');
range('    final preview = CheckoutPreview(', '    final created = await _createBackendBooking(address);', '');
s=s.replace('        _checkoutPreview = preview;', '        _checkoutPreview = _previewFromBooking(_serverBooking!);');
s=s.replace('        _liveBookingId = bid;\n        _checkoutStep = 6;', `        _liveBookingId = bid;
        _serverBooking = booking;
        _liveBookingTotal = (int.tryParse('\${booking['totalPaise']}') ?? 0) ~/ 100;
        _checkoutStep = 6;`);
s=s.replace('          _liveBookingStatus = status;',`          _liveBookingStatus = status;
          _serverBooking = data;
          _checkoutPreview = _previewFromBooking(data);`);
const pos=s.indexOf('  void _startLiveBookingSync(');
s=s.slice(0,pos)+`  CheckoutPreview _previewFromBooking(Map<String, dynamic> booking) {
    final scheduled = DateTime.parse('\${booking['startsAt']}').toLocal();
    final address = booking['addressSnapshot'] as Map? ?? {};
    int rupees(dynamic paise) => (int.tryParse('$paise') ?? 0) ~/ 100;
    return CheckoutPreview(
      services: [for (final item in (booking['items'] as List? ?? []))
        PreviewService(name: '\${item['name'] ?? 'Service'}', quantity: int.tryParse('\${item['quantity']}') ?? 1,
          unitPrice: rupees(item['pricePaise']))],
      date: scheduled, time: TimeOfDay.fromDateTime(scheduled).format(context),
      bookingPreference: _bookingPreference,
      addressLabel: '\${address['label'] ?? ''}',
      addressDetails: [address['line1'], address['line2'], address['city'], address['postalCode']].where((v) => v != null && '$v'.isNotEmpty).join(', '),
      subtotal: rupees(booking['subtotalPaise']), discount: rupees(booking['discountPaise']), convenienceFee: 0, tip: 0,
      total: rupees(booking['totalPaise']),
      paymentMethod: CheckoutPaymentMethod.cashOnService,
    );
  }

`+s.slice(pos);
const a=s.indexOf('    return Column(',s.indexOf('  Widget _bookingConfirmationStep()'));
const b=s.indexOf('  Widget _offers()',a);
s=s.slice(0,a)+`    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Booking \${_liveBookingId ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(_liveBookingStatus ?? 'Status unavailable'),
      _bookingPreviewDetailCard(),
    ]);
  }

`+s.slice(b);
s=s.replace('    } catch (_) {}\n  }\n\n  Future<void> _syncBookingCatalog()', "    } catch (error) { if (mounted) _message('Unable to load your account data. Please retry.'); }\n  }\n\n  Future<void> _syncBookingCatalog()");
fs.writeFileSync(file,s);
// Catalog errors must be visible instead of appearing as an empty database.
file='beauty-services/apps/customer_app/lib/integration/customer_mobile_operations_api.dart';
s=fs.readFileSync(file,'utf8');
const start=s.indexOf('  Future<List<Map<String, dynamic>>> getCatalogServices()');
const end=s.indexOf('  Future<List<Map<String, dynamic>>> getCatalogCategories()',start);
s=s.slice(0,start)+"  Future<List<Map<String, dynamic>>> getCatalogServices() => getRecords('/api/catalog/services');\n\n"+s.slice(end);
fs.writeFileSync(file,s);
