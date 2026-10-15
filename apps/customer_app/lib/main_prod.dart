import 'app/bootstrap.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';

void main() => bootstrap(const AppConfig(Environment.production));
