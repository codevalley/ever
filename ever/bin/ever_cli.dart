import 'dart:io';

import 'package:ever/core/logging.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/core/local_cache.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/datasources/user_ds.dart';
import 'package:ever/domain/presenter/cli_presenter.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/get_current_user_usecase.dart';
import 'package:ever/domain/usecases/user/login_usecase.dart';
import 'package:ever/domain/usecases/user/refresh_token_usecase.dart';
import 'package:ever/domain/usecases/user/register_usecase.dart';
import 'package:ever/domain/usecases/user/sign_out_usecase.dart';
import 'package:ever/implementations/cache/file_cache.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/implementations/http/timeout_client.dart';
import 'package:ever/implementations/repositories/user_repository_impl.dart';
import 'package:ever/ui/cli/app.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

final getIt = GetIt.instance;

void main(List<String> args) async {
  final logger = Logger();
  
  try {
    // Set up default logging
    initLogging(LogConfig(
      enabled: true,
      minLevel: LogLevel.info,
      showTimestamp: true,
      showLevel: true,
    ));
    
    // Set up dependency injection
    await setupDependencies();
    
    // Create CLI app
    final app = CliApp(
      presenter: getIt<CliPresenter>(),
      logger: logger,
    );
    
    // Run command
    final exitCode = await app.run(args);
    exit(exitCode);
  } catch (e, s) {
    logger.err('Fatal error: $e\n$s');
    exit(1);
  }
}

Future<void> setupDependencies() async {
  // Get app directory
  final appDir = path.join(
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.',
    '.ever',
  );
  await Directory(appDir).create(recursive: true);

  // HTTP Client with timeout
  final client = TimeoutClient(
    http.Client(),
    timeout: const Duration(seconds: 10),
  );

  // Local Cache
  getIt.registerSingleton<LocalCache>(
    FileCache(path.join(appDir, 'cache')),
  );

  // Data Sources
  getIt.registerSingleton<UserDataSource>(
    UserDataSourceImpl(
      client: client,
      cache: getIt<LocalCache>(),
      retryConfig: RetryConfig.defaultConfig,
      circuitBreakerConfig: CircuitBreakerConfig.defaultConfig,
    ),
  );

  // Repositories
  getIt.registerSingleton<UserRepository>(
    UserRepositoryImpl(
      getIt<UserDataSource>(),
      retryConfig: RetryConfig.defaultConfig,
      circuitBreaker: CircuitBreaker(),
    ),
  );

  // Use Cases
  getIt.registerFactory<RegisterUseCase>(
    () => RegisterUseCase(getIt<UserRepository>()),
  );
  
  getIt.registerFactory<LoginUseCase>(
    () => LoginUseCase(getIt<UserRepository>()),
  );
  
  getIt.registerFactory<SignOutUseCase>(
    () => SignOutUseCase(getIt<UserRepository>()),
  );
  
  getIt.registerFactory<RefreshTokenUseCase>(
    () => RefreshTokenUseCase(getIt<UserRepository>()),
  );
  
  getIt.registerFactory<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(getIt<UserRepository>()),
  );

  // Presenter
  getIt.registerSingleton<CliPresenter>(
    CliPresenter(
      registerUseCase: getIt<RegisterUseCase>(),
      loginUseCase: getIt<LoginUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      refreshTokenUseCase: getIt<RefreshTokenUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
    ),
  );

  // Initialize components
  await getIt<UserDataSource>().initialize();
}

// Helper function to exit with code
void exit(int code) {
  // Ensure all output is flushed
  stdout.flush();
  stderr.flush();
  // Exit with code
  exitCode = code;
} 