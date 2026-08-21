import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import '../../features/accounts/data/repositories/account_repository_impl.dart';
import '../../features/accounts/domain/repositories/account_repository.dart';
import '../../features/budgets/data/repositories/budget_repository_impl.dart';
import '../../features/budgets/domain/repositories/budget_repository.dart';
import '../../features/categories/data/repositories/category_repository_impl.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/goals/data/repositories/goal_repository_impl.dart';
import '../../features/goals/domain/repositories/goal_repository.dart';
import '../../features/profiles/data/repositories/profile_repository_impl.dart';
import '../../features/profiles/domain/repositories/profile_repository.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/recurring/data/repositories/recurring_repository_impl.dart';
import '../../features/recurring/domain/repositories/recurring_repository.dart';
import '../platform/file_service.dart';
import '../platform/haptic_service.dart';
import '../platform/notification_service.dart';
import '../security/privacy_mode_service.dart';
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

  // Privacy Mode Settings
  final privacyModeService = PrivacyModeServiceImpl(secureStorage: sl<FlutterSecureStorage>());
  await privacyModeService.init();
  sl.registerSingleton<PrivacyModeService>(privacyModeService);

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
    return List<int>.filled(32, 0);
  });

  // Open database connection and register database instance
  final databaseConnection = openEncryptedConnection(keyBytes);
  final appDatabase = AppDatabase(databaseConnection);
  sl.registerSingleton<AppDatabase>(appDatabase);

  // 4. Repositories
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<RecurringRepository>(
    () => RecurringRepositoryImpl(sl<AppDatabase>()),
  );

  logger.info(
    'Dependency Injection and Secure Database initialized successfully with all repositories.',
  );
}
