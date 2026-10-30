const fs=require('fs');
let file='beauty-services/apps/customer_app/lib/features/home/development_home_screen.dart';
let s=fs.readFileSync(file,'utf8');
function range(a,b,v=''){const i=s.indexOf(a),j=s.indexOf(b,i+1);if(i<0||j<0)throw Error(a);s=s.slice(0,i)+v+'\n\n'+s.slice(j);}
range('const _categoryHeroImages','/// Local preview;');
s=s.replace('/// Local preview; booking selections are interactive and held in memory.', '/// Customer catalog and account screens backed by the mobile API.');
range('  Future<void> _showContactPreviewNotice','  void _setOffer', `  Future<void> _showNotifications() async {
    try {
      final records = await _operationsApi.getRecords('/api/mobile/customer/notifications');
      if (!mounted) return;
      showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: ListView(
        children: [const ListTile(title: Text('Notifications')),
          if (records.isEmpty) const ListTile(title: Text('No notifications yet.')),
          for (final record in records) ListTile(title: Text('\${record['title'] ?? record['type'] ?? ''}'), subtitle: Text('\${record['message'] ?? record['body'] ?? ''}')),
        ],
      )));
    } catch (error) { if (mounted) _message('Unable to load notifications. Please retry.'); }
  }`);
range('  void _showAll()','  void _openServiceCategories()');
range('  Widget _professionalContactButton','  Widget _bookingTimeline');
range('  Future<void> _enterCustomTip','  Widget _paymentDetailRow');
range('class _AssignmentBadge','BoxDecoration _softBox');
s=s.replaceAll('  bool _reviewSubmitted = false;','').replaceAll('      _reviewSubmitted = false;','').replaceAll('    _reviewSubmitted = false;','');
s=s.replace('      _tipSelectionCard(),','');
s=s.replace('int get _checkoutTotal => _cartTotal + _tipAmount;', 'int get _checkoutTotal => _cartTotal;').replaceAll('tip: _tipAmount','tip: 0').replaceAll('  int _tipAmount = 0;','').replaceAll('      _tipAmount = 0;','');
s=s.replace('int get _cartDiscount => _offerApplied ? (_cartSubtotal * 0.2).round() : 0;', 'int get _cartDiscount => 0;');
s=s.replace('    _stopServiceTimer();\n    _serviceCompleted = true;', `    if (_liveBookingStatus != 'completed') { _message('Completion is updated after the backend confirms the service and payment.'); return; }
    _stopServiceTimer();
    _serviceCompleted = true;`);
s=s.replace("_message('Available offers are listed in Offers & Packages. Discounts require server confirmation.');",'setState(() => _tab = 2);');
// Header/hero images come from catalog URLs rather than service artwork.
s=s.replace('Image.asset(\n                  heroImage ?? services.first.image,','Image.network(\n                  (heroImage?.isNotEmpty == true ? heroImage! : services.first.image),');
s=s.replace("'\${CatalogService.formatPaise(BigInt.parse('\${package['pricePaise']}'))}'", "CatalogService.formatPaise(BigInt.parse('\${package['pricePaise']}'))");
fs.writeFileSync(file,s);
file='beauty-services/apps/customer_app/lib/features/home/all_services_screen.dart';
s=fs.readFileSync(file,'utf8').replace("import '../../core/constants/app_assets.dart';",'');fs.writeFileSync(file,s);
// Include backend identity summaries only after booking ownership has been checked.
for(file of ['beauty-services/backend/src/platform/mobile.routes.js','admin web panel/backend/src/platform/mobile.routes.js']){
  s=fs.readFileSync(file,'utf8');
  const old="  area.get('/bookings',handler(async(req,res)=>reply(req,res,await list(db,'bookings',req.query,{scope:app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id},fields:['_id']}))))";
  if(!s.includes(old))throw Error(file+' bookings route');
  s=s.replace(old,`  area.get('/bookings',handler(async(req,res)=>{
   const result=await list(db,'bookings',req.query,{scope:app==='customer'?{customerId:req.auth.user._id}:{workerUserId:req.auth.user._id},fields:['_id']})
   if(app==='worker')for(const booking of result.items){
    const customer=await db.collection('users').findOne({_id:booking.customerId},{projection:{fullName:1,mobileNumber:1}})
    if(customer)booking.customerSnapshot={fullName:customer.fullName,mobileNumber:customer.mobileNumber}
   }
   reply(req,res,result)
  }))`);
  const anchor="   if(app==='customer'&&serviceOtp?.availability)";
  s=s.replace(anchor,`   if(app==='customer'&&booking.workerUserId){
    const worker=await db.collection('users').findOne({_id:booking.workerUserId},{projection:{fullName:1}})
    if(worker)result.worker={fullName:worker.fullName}
   }
`+anchor);
  fs.writeFileSync(file,s);
}
