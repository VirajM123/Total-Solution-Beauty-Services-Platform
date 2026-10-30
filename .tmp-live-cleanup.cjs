const fs=require('fs');
const file='beauty-services/apps/customer_app/lib/features/home/development_home_screen.dart';
let s=fs.readFileSync(file,'utf8');
function range(a,b,v=''){const i=s.indexOf(a),j=s.indexOf(b,i+1);if(i<0||j<0)throw Error(a);s=s.slice(0,i)+v+'\n\n'+s.slice(j);}
range('class _ProfileMenuEntry {','class _AddAddressDialog');
s=s.replace(/String _serviceImage[^\n]*\n/,'');
range('  void _professional()','  void _showAll()');
range('  Widget _discount()','  Widget _bookings()');
range('  Widget _bookingHistoryFilterButton','  Widget _professionalSearchCard');
range('  Widget _offerCategoryChip','  Widget _profile()');
range('  Widget _profileMenuGroup','  Future<void> _showSavedAddresses');
range('  void _showSavedProfessionals()','  void _openBookingHistory()');
range('  void _showReferralCode()','\n}\n\nclass ' , '');
for(const field of ["  bool _notificationsEnabled = true;","  bool _profilePromotionsEnabled = true;","  bool _favoriteProfessional = false;","  String _offersTab = 'Offers';","  String _offersCategory = 'All';","  String _offerSearchQuery = '';","  bool _offerSearchVisible = false;","  String _bookingHistoryFilter = 'All';","  bool _bookingDetailsExpanded = false;"]){s=s.replace(field,'');}
s=s.replaceAll("      _bookingHistoryFilter = 'All';",'').replaceAll('      _bookingDetailsExpanded = false;','');
s=s.replace(/    final offerWidth =[^;]+;/,'');
// Catalog compare prices are allowed only when provided by the server.
s=s.replace('                  backendId: id,',`                  backendId: id,
                  originalPrice: service['compareAtPricePaise'] == null ? null : (num.parse('\${service['compareAtPricePaise']}') / 100).round(),
                  discount: service['compareAtPricePaise'] == null ? null : 'Special price',`);
range('          Image.asset(\n            service.image,','          Padding(', '          _ServicePhoto(service: service, width: width, height: 43),');
range('  Widget _assignedProfessionalCard()','  Widget _professionalContactButton', `  Widget _assignedProfessionalCard() => Card(child: ListTile(
    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
    title: Text(_liveWorkerName ?? 'Awaiting admin allocation'),
    subtitle: Text(_liveBookingStatus ?? 'Booking status unavailable'),
  ));`);
// Replace the illustrated route with the server's travel status.
range('        ClipRRect(\n          borderRadius: BorderRadius.circular(20),\n          child: Stack(', '        _assignedProfessionalCard(),', `        const _InfoCard(Icons.location_on_outlined, 'Travel status', 'Live map tracking is unavailable. Booking progress is updated from the server.'),
        const SizedBox(height: 14),`);
fs.writeFileSync(file,s);
