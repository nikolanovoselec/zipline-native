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
  locator.registerSingleton<ActivityService>(ActivityService());
  locator.registerSingleton<SharingService>(SharingService());
  locator.registerSingleton<UploadQueueService>(UploadQueueService());
  locator.registerSingleton<ConnectivityService>(ConnectivityService());

  // Register lazy singletons (created on first use)
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<OAuthService>(() => OAuthService());
  locator.registerLazySingleton<BiometricService>(() => BiometricService());
  locator.registerLazySingleton<IntentService>(() => IntentService());

  // Register factory services (new instance each time)
  locator.registerFactory<FileUploadService>(() => FileUploadService());
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
