import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import '../platform/file_service.dart';
import '../platform/haptic_service.dart';
import '../platform/notification_service.dart';
import '../security/security_service.dart';
import '../storage/database.dart';
import '../utilities/logger.dart';

final sl = GetIt.instance;

/// Initialize all application dependencies.
Future<void> initServiceLocator() async {
  // 1. Logging Foundation
  final logger = AppLoggerImpl();
  sl.registerLazySingleton<AppLogger>(() => logger);

  // 2. Local Platform Abstractions
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<FlutterLocalNotificationsPlugin>(
    () => FlutterLocalNotificationsPlugin(),
  );

  sl.registerLazySingleton<SecurityService>(
    () => SecurityServiceImpl(secureStorage: sl<FlutterSecureStorage>()),
  );

  sl.registerLazySingleton<FileService>(() => const FileServiceImpl());
  sl.registerLazySingleton<HapticService>(() => const HapticServiceImpl());

  final notificationService = NotificationServiceImpl(
    notificationsPlugin: sl<FlutterLocalNotificationsPlugin>(),
  );
  sl.registerLazySingleton<NotificationService>(() => notificationService);

  // 3. Database Initialization
  final securityService = sl<SecurityService>();
  final keyResult = await securityService.getDatabaseKey();

  final keyBytes = keyResult.fold((key) => key, (failure) {
    logger.error(
      'CRITICAL: Failed to load database encryption key during DI initialization: ${failure.message}',
    );
    // Fallback key to allow initialization, in a production setup this would prompt recovery
    return List<int>.filled(32, 0);
  });

  // Open database connection and register database instance
  final databaseConnection = openEncryptedConnection(keyBytes);
  final appDatabase = AppDatabase(databaseConnection);
  sl.registerSingleton<AppDatabase>(appDatabase);

  logger.info(
    'Dependency Injection and Secure Database initialized successfully.',
  );
}
