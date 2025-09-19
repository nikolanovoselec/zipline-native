import 'package:get_it/get_it.dart';
import '../services/auth_service.dart';
import '../services/file_upload_service.dart';
import '../services/upload_queue_service.dart';
import '../services/debug_service.dart';
import '../services/activity_service.dart';
import '../services/sharing_service.dart';
import '../services/biometric_service.dart';
import '../services/intent_service.dart';
import '../services/oauth_service.dart';
import '../services/connectivity_service.dart';

final GetIt locator = GetIt.instance;

void setupServiceLocator() {
  // Register singleton services (single instance throughout app)
  locator.registerSingleton<DebugService>(DebugService());

  // Register lazy singletons (created on first use)
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<OAuthService>(() => OAuthService());
  locator.registerLazySingleton<BiometricService>(() => BiometricService());
  locator.registerLazySingleton<IntentService>(() => IntentService());

  // Register remaining singletons once dependencies are in place
  locator.registerSingleton<ActivityService>(ActivityService());
  locator.registerSingleton<ConnectivityService>(ConnectivityService());
  locator.registerSingleton<UploadQueueService>(UploadQueueService());

  // Register factory services (new instance each time)
  locator.registerFactory<FileUploadService>(() => FileUploadService());

  // Register services that depend on factories
  locator.registerSingleton<SharingService>(SharingService());
}

// Extension for easier access
extension ServiceLocatorExtension on GetIt {
  AuthService get auth => get<AuthService>();
  FileUploadService get fileUpload => get<FileUploadService>();
  UploadQueueService get uploadQueue => get<UploadQueueService>();
  DebugService get debug => get<DebugService>();
  ActivityService get activity => get<ActivityService>();
  SharingService get sharing => get<SharingService>();
  BiometricService get biometric => get<BiometricService>();
  IntentService get intent => get<IntentService>();
  OAuthService get oauth => get<OAuthService>();
  ConnectivityService get connectivity => get<ConnectivityService>();
}
