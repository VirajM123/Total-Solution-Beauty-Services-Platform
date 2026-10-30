const fs = require('fs');
const file = 'beauty-services/apps/customer_app/lib/features/home/development_home_screen.dart';
let s = fs.readFileSync(file, 'utf8');
function range(a,b,value) { const start=s.indexOf(a), end=s.indexOf(b,start+1); if(start<0||end<0)throw Error(a); s=s.slice(0,start)+value+'\n\n'+s.slice(end); }
function rep(a,b) { if(!s.includes(a))throw Error(a); s=s.replace(a,b); }
range('const _previewServices = [','String _serviceImage', '');
range('final _previewServiceDetails = <_Service>[','const _developmentBanners = [','');
range('const _developmentBanners = [','/// Local preview;', '');
// Catalog categories and account records belong to the server.
rep('  List<_Service> _services = [];', `  List<_Service> _services = [];
  List<(String, IconData, String?)> _categories = [('All Services', Icons.grid_view, null)];
  List<PromotionalBanner> _banners = [];
  List<Map<String, dynamic>> _offersData = [], _packagesData = [], _bookingsData = [];
  Map<String, dynamic> _account = {};
  bool _catalogLoading = true;
  String? _catalogError;
  Timer? _catalogRefreshTimer;`);
range('  final _savedAddresses = <_SavedAddress>[','  int _tab =', '  final _savedAddresses = <_SavedAddress>[];');
rep("String _location = 'Latur, Maharashtra';", "String _location = 'Select an address';");
rep("String _selectedAddressId = '6ae05a3b9075320591000001';", "String _selectedAddressId = '';");
rep("String _customerName = 'Omkar Bhange';", "String _customerName = '';");
rep('    _syncBookingCatalog();\n  }', `    _syncBookingCatalog();
    _loadAccount();
    _catalogRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncBookingCatalog());
  }

  Future<void> _loadAccount() async {
    try {
      final result = await _operationsApi.getProfile();
      if (!mounted) return;
      setState(() {
        _account = Map<String, dynamic>.from(result['user'] as Map? ?? {});
        _customerName = '\${_account['fullName'] ?? ''}';
      });
    } catch (error) {
      if (mounted) _message('Unable to load your profile. Please retry.');
    }
  }`);
range('      if (mounted && addrs.isNotEmpty) {','      final bookings =', `      if (mounted) {
        setState(() {
          _savedAddresses.clear();
          for (final a in addrs) {
            _savedAddresses.add(_SavedAddress(
              id: '\${a['_id'] ?? a['id'] ?? ''}',
              label: '\${a['label'] ?? ''}', street: '\${a['line1'] ?? ''}',
              city: '\${a['city'] ?? ''}', postalCode: '\${a['postalCode'] ?? ''}',
              serviceAreaId: '\${a['serviceAreaId'] ?? ''}',
            ));
          }
          if (!_savedAddresses.any((a) => a.id == _selectedAddressId)) {
            _selectedAddressId = _savedAddresses.isEmpty ? '' : _savedAddresses.first.id;
          }
          _location = _savedAddresses.isEmpty ? 'Select an address' : _selectedAddress.city;
        });
      }
`);
rep('      if (mounted && bookings.isNotEmpty) {', '      if (mounted) setState(() => _bookingsData = bookings);\n      if (mounted && bookings.isNotEmpty) {');
rep("'BLUE HAIR COLOUR'", "'Service'"); // remaining fallback service in booking restore
s=s.replaceAll("'BLUE HAIR COLOUR'", "'Service'").replace('?? 1560000','?? 0');
rep('              date: _bookingDate,', "              date: DateTime.tryParse('\${active['startsAt']}')?.toLocal() ?? _bookingDate,");
range('      final catalogServices = await _operationsApi.getCatalogServices();','      if (mounted) {', `      final catalogServices = await _operationsApi.getCatalogServices();
      final categories = await _operationsApi.getRecords('/api/catalog/categories');
      final offers = await _operationsApi.getRecords('/api/catalog/offers');
      final packages = await _operationsApi.getRecords('/api/catalog/packages');
      final banners = await _operationsApi.getRecords('/api/catalog/banners');`);
range('              final category = _categories','              available.add(', `              final category = categoryName;`);
rep('preview.isEmpty ? AppAssets.goldFacial : preview.first.image,', "'\${service['thumbnail'] ?? ((service['images'] as List? ?? []).isEmpty ? '' : service['images'][0]['url'] ?? '')}',");
rep('          _services = available;', `          _services = available;
          _categories = [('All Services', Icons.grid_view, null),
            for (final category in categories) ('\${category['name']}', Icons.spa_outlined, null)];
          _offersData = offers;
          _packagesData = packages;
          _banners = [for (final banner in banners)
            if ((banner['audiences'] as List? ?? []).contains('customer'))
              PromotionalBanner(id: '\${banner['_id'] ?? banner['id']}',
                title: '\${banner['name'] ?? ''}', subtitle: '\${banner['subtitle'] ?? ''}',
                imageAsset: '\${banner['thumbnail'] ?? ''}',
                action: banner['targetType'] == 'service' ? PromotionalBannerAction.service : PromotionalBannerAction.offer,
                targetId: '\${banner['targetId'] ?? ''}')];
          _catalogLoading = false;
          _catalogError = null;`);
rep("      debugPrint('[CustomerApp] Catalog refresh failed: $e');", "      debugPrint('[CustomerApp] Catalog refresh failed: $e');\n      if (mounted) setState(() { _catalogLoading = false; _catalogError = 'Unable to load services. Please retry.'; });");
rep('    _bookingSyncTimer?.cancel();\n    _confirmationTimer?.cancel();', '    _catalogRefreshTimer?.cancel();\n    _bookingSyncTimer?.cancel();\n    _confirmationTimer?.cancel();');
rep("  String get serviceAreaId => 'be21549eeeaf01c30ca4ec6c';", "  String get serviceAreaId => ''; ");
rep("this.serviceAreaId = 'be21549eeeaf01c30ca4ec6c'", "this.serviceAreaId = ''");
rep('      _savedAddresses.firstWhere((address) => address.id == _selectedAddressId);', `      _savedAddresses.firstWhere((address) => address.id == _selectedAddressId,
        orElse: () => const _SavedAddress(id: '', label: 'Select a saved address', street: '', city: '', postalCode: ''));`);
range('  Future<void> _addAddress() async {','  void _addToCart', `  Future<void> _addAddress() async {
    final address = await showDialog<_SavedAddress>(context: context,
      builder: (_) => _AddAddressDialog(initialCity: _savedAddresses.isEmpty ? '' : _selectedAddress.city));
    if (address == null || !mounted) return;
    try {
      final areas = await _operationsApi.getServiceAreas(address.postalCode);
      final matches = areas.where((area) => '\${area['city']}'.toLowerCase() == address.city.toLowerCase()).toList();
      if (matches.isEmpty) { if (mounted) _message('This address is outside the available service areas.'); return; }
      final saved = await _operationsApi.saveAddress(label: address.label, line1: address.street,
        city: address.city, postalCode: address.postalCode, serviceAreaId: '\${matches.first['_id'] ?? matches.first['id']}');
      if (!mounted) return;
      final result = _SavedAddress(id: '\${saved['_id'] ?? saved['id']}', label: '\${saved['label']}',
        street: '\${saved['line1']}', city: '\${saved['city']}', postalCode: '\${saved['postalCode']}', serviceAreaId: '\${saved['serviceAreaId']}');
      setState(() { _savedAddresses.add(result); _selectedAddressId = result.id; _location = result.city; });
    } catch (error) { if (mounted) _message('Unable to save address: $error'); }
  }`);
range('          for (final place in [','            ListTile(', "          for (final place in _savedAddresses.map((a) => a.city).toSet())");
rep('if (service.name == banner.targetId)', 'if (service.backendId == banner.targetId)');
// Remove hardcoded offers, ratings and professional photos from the home screen.
range("        const SizedBox(height: 10),\n        _discount(),", "  Widget _hero(double width)", `        if (_catalogLoading) const Center(child: CircularProgressIndicator()),
        if (_catalogError != null) ...[
          Text(_catalogError!), TextButton(onPressed: _syncBookingCatalog, child: const Text('Retry')),
        ],
        if (_offersData.isNotEmpty || _packagesData.isNotEmpty) ...[
          const SizedBox(height: 12),
          _heading('Offers & Packages', () => setState(() => _tab = 2)),
          for (final offer in _offersData) ListTile(title: Text('\${offer['name']}'), subtitle: Text('\${offer['description'] ?? ''}')),
        ],
      ],
    );
  }
`);
rep('banners: _developmentBanners', 'banners: _banners');
// Backend-backed offers and package records; no invented bundles or coupon activation.
range('  Widget _offers() {','  Widget _offerCategoryChip', `  Widget _offers() => RefreshIndicator(
    onRefresh: _syncBookingCatalog,
    child: ListView(key: const ValueKey('offers-packages-screen'), padding: const EdgeInsets.all(16), children: [
      const Text('Offers & Packages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      if (_offersData.isEmpty && _packagesData.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No offers or packages are available.')),
      for (final offer in _offersData) Card(child: ListTile(title: Text('\${offer['name']}'),
        subtitle: Text('\${offer['description'] ?? ''}\\nCode: \${offer['code'] ?? ''}'))),
      for (final package in _packagesData) Card(child: ListTile(title: Text('\${package['name']}'),
        subtitle: Text('\${package['description'] ?? ''}\\n\${package['durationMinutes']} min'),
        trailing: Text('\${CatalogService.formatPaise(BigInt.parse('\${package['pricePaise']}'))}'))),
    ]),
  );`);
// Existing operational checkout remains available via the active booking card.
range('  Widget _bookingHistoryScreen() {','  Widget _bookingHistoryFilterButton', `  Widget _bookingHistoryScreen() => RefreshIndicator(
    onRefresh: () async { final records = await _operationsApi.getBookings(); if (mounted) setState(() => _bookingsData = records); },
    child: ListView(key: const ValueKey('booking-history-list'), padding: const EdgeInsets.all(16), children: [
      const Text('My Bookings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      if (_bookingsData.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No bookings yet.')),
      for (final booking in _bookingsData) Card(child: ListTile(
        title: Text((booking['items'] as List? ?? []).map((item) => '\${item['name'] ?? 'Service'}').join(', ')),
        subtitle: Text('\${booking['status'] ?? ''}\\n\${DateTime.tryParse('\${booking['startsAt']}')?.toLocal() ?? 'Schedule unavailable'}'),
        trailing: Text(CatalogService.formatPaise(BigInt.tryParse('\${booking['totalPaise']}') ?? BigInt.zero)),
        onTap: '\${booking['_id'] ?? booking['id']}' == _liveBookingId
          ? () => setState(() { _checkoutStep = 6; _tab = 1; }) : null,
      )),
    ]),
  );`);
rep("import '../booking/checkout_models.dart';", "import '../booking/checkout_models.dart';\nimport '../catalog/catalog_repository.dart';");
// Do not advertise local-only profile, referral, favourites, or wallet information.
range('  Widget _profile() => ListView(','  Widget _profileMenuGroup', `  Widget _profile() => RefreshIndicator(onRefresh: _loadAccount, child: ListView(
    padding: const EdgeInsets.all(16), children: [
      ListTile(title: Text(_customerName.isEmpty ? 'Your profile' : _customerName),
        subtitle: Text('\${_account['mobileNumber'] ?? ''}\\n\${_account['email'] ?? ''}'),
        trailing: IconButton(onPressed: _editCustomerProfile, icon: const Icon(Icons.edit_outlined))),
      ListTile(title: const Text('My Addresses'), subtitle: Text('\${_savedAddresses.length} saved'), onTap: _showSavedAddresses),
      ListTile(title: const Text('My Bookings'), subtitle: Text('\${_bookingsData.length} bookings'), onTap: _openBookingHistory),
      ListTile(title: const Text('Offers & Packages'), onTap: () => setState(() => _tab = 2)),
    ],
  ));`);
range("    if (selection == 'add-address' && mounted) {",'    } else if (selection is _SavedAddress && mounted) {', `    if (selection == 'add-address' && mounted) {
      await _addAddress();`);
range('  void _openBookingHistory() => setState(() {','  void _editCustomerProfile()', `  void _openBookingHistory() { _syncCustomerHistory(); setState(() { _tab = 1; _checkoutStep = 13; }); }

  Future<void> _syncCustomerHistory() async {
    final records = await _operationsApi.getBookings();
    if (mounted) setState(() => _bookingsData = records);
  }
`);
rep('              onPressed: () {\n                final updatedName = name.trim();', '              onPressed: () async {\n                final updatedName = name.trim();');
rep('                setState(() => _customerName = updatedName);\n                Navigator.pop(dialogContext);', `                try {
                  await _operationsApi.updateProfile(updatedName);
                  if (!mounted || !dialogContext.mounted) return;
                  setState(() => _customerName = updatedName);
                  Navigator.pop(dialogContext);
                } catch (error) { if (mounted) _message('Unable to save profile: $error'); }`);
// The backend charges no convenience fee; never show an invented charge.
rep('int get _cartTotal => _cartSubtotal - _cartDiscount + 50;', 'int get _cartTotal => _cartSubtotal - _cartDiscount;');
s=s.replaceAll('convenienceFee: 50','convenienceFee: 0').replace("_summaryRow('Convenience Fee', 50)", "_summaryRow('Convenience Fee', 0)").replace("_bookingTotalLine('Convenience Fee', 50)","_bookingTotalLine('Convenience Fee', 0)");
range('  void _setOffer(bool enabled) {','  void _add(_Service service)', `  void _setOffer(bool enabled) { _message('Available offers are listed in Offers & Packages. Discounts require server confirmation.'); }
`);
rep("title: _offerApplied ? 'BEAUTY20 applied' : 'Apply Coupon',", "title: 'Offers & Packages',");
range("                subtitle: _offerApplied\n                    ? '20% discount", '                onTap:', "                subtitle: 'View available offers',");
// Server thumbnail URLs render as network images throughout service lists/details.
rep('    return Image.asset(\n      service.image,', `    if (Uri.tryParse(service.image)?.hasAuthority == true) {
      return Image.network(service.image, width: width, height: height, fit: fit,
        errorBuilder: (_, _, _) => fallback());
    }
    return Image.asset(
      service.image,`);
// Static ratings on real service cards are not backed by reviews.
s=s.replace("_paymentDetailRow('Professional', 'Priya Shinde · Verified')", "_paymentDetailRow('Professional', _liveWorkerName ?? 'Awaiting admin allocation')");
fs.writeFileSync(file,s);
