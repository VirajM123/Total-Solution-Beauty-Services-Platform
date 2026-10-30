const fs=require('fs');
let file='beauty-services/apps/worker_app/lib/features/home/worker_dashboard_screen.dart';
let s=fs.readFileSync(file,'utf8');
const start=s.indexOf('  Widget _offerCard({'),end=s.indexOf('  Widget _dashboardAction(',start);
if(start<0||end<0)throw Error('dashboard methods');
s=s.slice(0,start)+`  Widget _offersSection() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final banner in _liveBanners) Card(child: ListTile(
      title: Text('\${banner['name'] ?? ''}'), subtitle: Text('\${banner['subtitle'] ?? ''}'),
    )),
  ]);

`+s.slice(end);
s=s.replace(/  int _offerIndex = 0;\r?\n  late final PageController _offersController = PageController\([\s\S]*?\);/, '  List<Map<String, dynamic>> _liveBanners = [];');
s=s.replace('    _offersController.dispose();','');
s=s.replace('    _previewOnline = widget.initialOnline;',`    _previewOnline = widget.initialOnline;
    if (!widget.demoMode) _loadBanners();`);
const init=s.indexOf('  void _onNotificationChanged()');
s=s.slice(0,init)+`  Future<void> _loadBanners() async {
    try {
      final banners = await (widget.operationsApi is WorkerMobileOperationsApi
          ? widget.operationsApi as WorkerMobileOperationsApi : WorkerMobileOperationsApi()).fetchCatalogRecords('banners');
      if (mounted) setState(() => _liveBanners = banners.where((b) => (b['audiences'] as List? ?? []).contains('worker')).toList());
    } catch (_) { /* Optional promotional content stays empty when unavailable. */ }
  }

`+s.slice(init);
fs.writeFileSync(file,s);
file='beauty-services/apps/customer_app/lib/features/home/all_services_screen.dart';
s=fs.readFileSync(file,'utf8');
const a=s.indexOf('const _categories = ['),b=s.indexOf('class AllServicesScreen',a);
s=s.slice(0,a)+s.slice(b);
// Backend categories use generic icons until they supply an image.
s=s.replace("import '../../core/constants/app_assets.dart';\n",'');
fs.writeFileSync(file,s);
