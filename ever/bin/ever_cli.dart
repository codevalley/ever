import 'dart:io';

import 'package:ever/core/logging.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/core/local_cache.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/datasources/user_ds.dart';
import 'package:ever/domain/datasources/note_ds.dart';
import 'package:ever/domain/datasources/task_ds.dart';
import 'package:ever/domain/presenter/cli_presenter.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/user/get_current_user_usecase.dart';
import 'package:ever/domain/usecases/user/login_usecase.dart';
import 'package:ever/domain/usecases/user/refresh_token_usecase.dart';
import 'package:ever/domain/usecases/user/register_usecase.dart';
import 'package:ever/domain/usecases/user/sign_out_usecase.dart';
import 'package:ever/domain/usecases/note/create_note_usecase.dart';
import 'package:ever/domain/usecases/note/update_note_usecase.dart';
import 'package:ever/domain/usecases/note/delete_note_usecase.dart';
import 'package:ever/domain/usecases/note/list_notes_usecase.dart';
import 'package:ever/domain/usecases/note/get_note_usecase.dart';
import 'package:ever/domain/usecases/task/create_task_usecase.dart';
import 'package:ever/domain/usecases/task/update_task_usecase.dart';
import 'package:ever/domain/usecases/task/delete_task_usecase.dart';
import 'package:ever/domain/usecases/task/list_tasks_usecase.dart';
import 'package:ever/domain/usecases/task/get_task_usecase.dart';
import 'package:ever/implementations/cache/file_cache.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/implementations/datasources/note_ds_impl.dart';
import 'package:ever/implementations/datasources/task_ds_impl.dart';
import 'package:ever/implementations/http/timeout_client.dart';
import 'package:ever/implementations/repositories/user_repository_impl.dart';
import 'package:ever/implementations/repositories/note_repository_impl.dart';
import 'package:ever/implementations/repositories/task_repository_impl.dart';
import 'package:ever/ui/cli/app.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:ever/implementations/config/api_config.dart';

final getIt = GetIt.instance;

void main(List<String> args) async {
  final logger = Logger();
  
  try {
    // Parse global flags before anything else
    final parser = ArgParser()
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose (debug) logging',
        negatable: false,
      )
      ..addOption(
        'api-url',
        help: 'Override the API base URL',
      );

    final results = parser.parse(args);
    final verbose = results['verbose'] as bool;
    final apiUrl = results['api-url'] as String?;
    
    // Configure logging based on verbose flag
    initLogging(LogConfig(
      enabled: true,
      minLevel: verbose ? LogLevel.debug : LogLevel.info,
      showTimestamp: true,
      showLevel: true,
    ));

    if (verbose) {
      logger.detail('Verbose logging enabled');
    }

    // Update API URL if provided
    if (apiUrl != null) {
      ApiConfig.updateBaseUrl(apiUrl);
      logger.info('Using API URL: ${ApiConfig.apiBaseUrl}');
    }
    
    // Set up dependency injection
    await setupDependencies();
    
    // Create CLI app
    final app = CliApp(
      presenter: getIt<CliPresenter>(),
      logger: logger,
    );
    
    // Run command with remaining args
    final remainingArgs = results.rest;
    final exitCode = await app.run(remainingArgs);
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

  // Register repositories first since we need them for access token
  getIt.registerSingleton<UserRepository>(
    UserRepositoryImpl(
      getIt<UserDataSource>(),
      retryConfig: RetryConfig.defaultConfig,
      circuitBreaker: CircuitBreaker(),
    ),
  );

  // Now register note data source with access token from user repository
  final noteDs = NoteDataSourceImpl(
    client: client,
    cache: getIt<LocalCache>(),
    retryConfig: RetryConfig.defaultConfig,
    circuitBreakerConfig: CircuitBreakerConfig.defaultConfig,
    getAccessToken: () => getIt<UserRepository>().currentToken ?? '',
  );
  getIt.registerSingleton<NoteDataSource>(noteDs);

  // Register note repository
  getIt.registerSingleton<NoteRepository>(
    NoteRepositoryImpl(
      getIt<NoteDataSource>(),
      retryConfig: RetryConfig.defaultConfig,
      circuitBreaker: CircuitBreaker(),
    ),
  );

  // Now register task data source with access token from user repository
  final taskDs = TaskDataSourceImpl(
    client: client,
    cache: getIt<LocalCache>(),
    retryConfig: RetryConfig.defaultConfig,
    circuitBreakerConfig: CircuitBreakerConfig.defaultConfig,
    getAccessToken: () => getIt<UserRepository>().currentToken ?? '',
  );
  getIt.registerSingleton<TaskDataSource>(taskDs);

  // Register task repository
  getIt.registerSingleton<TaskRepository>(
    TaskRepositoryImpl(
      getIt<TaskDataSource>(),
      retryConfig: RetryConfig.defaultConfig,
      circuitBreaker: CircuitBreaker(),
    ),
  );

  // User Use Cases
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

  // Note Use Cases
  getIt.registerFactory<CreateNoteUseCase>(
    () => CreateNoteUseCase(getIt<NoteRepository>()),
  );

  getIt.registerFactory<UpdateNoteUseCase>(
    () => UpdateNoteUseCase(getIt<NoteRepository>()),
  );

  getIt.registerFactory<DeleteNoteUseCase>(
    () => DeleteNoteUseCase(getIt<NoteRepository>()),
  );

  getIt.registerFactory<ListNotesUseCase>(
    () => ListNotesUseCase(getIt<NoteRepository>()),
  );

  getIt.registerFactory<GetNoteUseCase>(
    () => GetNoteUseCase(getIt<NoteRepository>()),
  );

  // Task Use Cases
  getIt.registerFactory<CreateTaskUseCase>(
    () => CreateTaskUseCase(getIt<TaskRepository>()),
  );

  getIt.registerFactory<UpdateTaskUseCase>(
    () => UpdateTaskUseCase(getIt<TaskRepository>()),
  );

  getIt.registerFactory<DeleteTaskUseCase>(
    () => DeleteTaskUseCase(getIt<TaskRepository>()),
  );

  getIt.registerFactory<ListTasksUseCase>(
    () => ListTasksUseCase(getIt<TaskRepository>()),
  );

  getIt.registerFactory<GetTaskUseCase>(
    () => GetTaskUseCase(getIt<TaskRepository>()),
  );

  // Presenter
  getIt.registerSingleton<CliPresenter>(
    CliPresenter(
      registerUseCase: getIt<RegisterUseCase>(),
      loginUseCase: getIt<LoginUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      refreshTokenUseCase: getIt<RefreshTokenUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
      createNoteUseCase: getIt<CreateNoteUseCase>(),
      updateNoteUseCase: getIt<UpdateNoteUseCase>(),
      deleteNoteUseCase: getIt<DeleteNoteUseCase>(),
      listNotesUseCase: getIt<ListNotesUseCase>(),
      getNoteUseCase: getIt<GetNoteUseCase>(),
      createTaskUseCase: getIt<CreateTaskUseCase>(),
      updateTaskUseCase: getIt<UpdateTaskUseCase>(),
      deleteTaskUseCase: getIt<DeleteTaskUseCase>(),
      listTasksUseCase: getIt<ListTasksUseCase>(),
      getTaskUseCase: getIt<GetTaskUseCase>(),
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