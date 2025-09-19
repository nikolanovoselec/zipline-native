import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipline_native_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService.resetForTesting();
  });

  test('saveCredentials stores secrets in secure storage only', () async {
    final service = AuthService();

    await service.saveCredentials(
      ziplineUrl: 'https://zipline.example.com',
      username: 'nerd',
      password: 'superSecret',
      cfClientId: 'client123',
      cfClientSecret: 'secret456',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zipline_url'), 'https://zipline.example.com');
    expect(prefs.getString('zipline_username'), 'nerd');
    expect(prefs.getString('zipline_password'), isNull);
    expect(prefs.getString('cf_client_secret'), isNull);

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'zipline_password'), 'superSecret');
    expect(await storage.read(key: 'cf_client_id'), 'client123');
    expect(await storage.read(key: 'cf_client_secret'), 'secret456');
  });

  test('clearAllCredentials preserves unrelated preferences', () async {
    SharedPreferences.setMockInitialValues({
      'zipline_url': 'https://before.example',
      'zipline_username': 'nerd',
      'theme_mode': 'dark',
    });
    FlutterSecureStorage.setMockInitialValues({
      'zipline_password': 'abc',
      'session_cookie': 'cookie',
      'cf_client_id': 'id',
      'cf_client_secret': 'secret',
    });
    await AuthService.resetForTesting();

    final service = AuthService();
    await service.clearAllCredentials();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zipline_url'), isNull);
    expect(prefs.getString('zipline_username'), isNull);
    expect(prefs.getString('theme_mode'), 'dark');

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'zipline_password'), isNull);
    expect(await storage.read(key: 'session_cookie'), isNull);
    expect(await storage.read(key: 'cf_client_id'), isNull);
    expect(await storage.read(key: 'cf_client_secret'), isNull);
  });
}
