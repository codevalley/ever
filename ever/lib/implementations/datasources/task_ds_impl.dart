import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logging.dart';
import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/local_cache.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/events/task_events.dart';
import '../../domain/datasources/task_ds.dart';
import '../../domain/entities/task.dart';
import '../config/api_config.dart';
import '../models/task_model.dart';

/// Implementation of TaskDataSource using HTTP and local cache
class TaskDataSourceImpl implements TaskDataSource {
  final http.Client client;
  final LocalCache cache;
  final RetryConfig retryConfig;
  final CircuitBreakerConfig circuitBreakerConfig;
  final String Function() getAccessToken;
  
  final _eventController = StreamController<DomainEvent>.broadcast();

  // Cache key constants
  static const _taskCachePrefix = 'task:';
  static const _taskListCacheKey = 'task:list';

  TaskDataSourceImpl({
    required this.client,
    required this.cache,
    required this.retryConfig,
    required this.circuitBreakerConfig,
    required this.getAccessToken,
  });

  String get accessToken => getAccessToken();

  String _getTaskKey(String taskId) => '$_taskCachePrefix$taskId';

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  // Add initialization flag
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    await cache.initialize();
    _isInitialized = true;
  }

  @override
  void dispose() {
    _eventController.close();
  }

  @override
  bool isOperationSupported(String operation) {
    // All operations are supported
    return true;
  }

  /// Execute a Future operation with retry logic
  Future<T> _executeWithRetryFuture<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    var attempts = 0;
    final startTime = DateTime.now();
    
    // Add a small delay before first attempt to ensure connection is ready
    if (!_isInitialized) {
      await Future.delayed(Duration(milliseconds: 100));
      _isInitialized = true;
    }

    while (true) {
      try {
        attempts++;
        iprint('Attempt $attempts executing $operation', '🔄');
        
        // For first attempt, ensure connection is ready
        if (attempts == 1) {
          try {
            final testUrl = Uri.parse('${ApiConfig.apiBaseUrl}/health');
            await client.get(
              testUrl, 
              headers: ApiConfig.headers.withAuth(accessToken)
            ).timeout(Duration(seconds: 2));
          } catch (e) {
            // If health check fails, throw a retriable error
            throw http.ClientException('Connection not ready');
          }
        }
        
        return await apiCall();
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        wprint('$operation failed after ${elapsed.inMilliseconds}ms: $e');
        
        if (!retryConfig.shouldRetry(e) || attempts >= retryConfig.maxAttempts) {
          if (attempts > 1) {
            eprint('$operation failed after $attempts attempts', '❌');
            _eventController.add(RetryExhausted(operation, e, attempts));
          }
          rethrow;
        }
        
        final delay = retryConfig.getDelayForAttempt(attempts);
        iprint('Waiting ${delay.inMilliseconds}ms before attempt ${attempts + 1}', '⏳');
        _eventController.add(RetryAttempt(operation, attempts, delay, e));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Stream<Task> create(Task task) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.create));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.create,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.create}');
          final model = TaskModel.forCreation(
            content: task.content,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
            tags: task.tags,
            parentId: task.parentId,
            topicId: task.topicId,
          );
          final body = json.encode(model.toJson());
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 201) {
            return response;
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      final responseData = json.decode(response.body);
      final data = responseData['data'];
      final createdTask = TaskModel.fromJson(data).toDomain();
      
      // Cache the newly created task
      await cache.set(_getTaskKey(createdTask.id), data);
      // Invalidate list cache since we have a new task
      await cache.remove(_taskListCacheKey);
      
      if (attempts > 1) {
        _eventController.add(RetrySuccess(ApiConfig.operations.task.create, attempts));
      }
      
      _eventController.add(OperationSuccess(ApiConfig.operations.task.create, createdTask));
      _eventController.add(TaskCreated(createdTask));
      
      yield createdTask;
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.create,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<Task> update(Task task) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.update));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.update,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.task(task.id)}');
          final model = TaskModel(
            id: task.id,
            content: task.content,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
            tags: task.tags,
            parentId: task.parentId,
            topicId: task.topicId,
            processingStatus: ProcessingStatus.pending,
            enrichmentData: {},
          );
          final body = json.encode(model.toJson());
          
          iprint('API Request: PUT $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.put(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        final updatedTask = TaskModel.fromJson(data).toDomain();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.update, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.update, updatedTask));
        _eventController.add(TaskUpdated(updatedTask));
        
        yield updatedTask;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.update,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<void> delete(String id) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.delete));
    var attempts = 0;
    final startTime = DateTime.now();

    while (true) {
      try {
        attempts++;
        iprint('Attempt $attempts executing delete task', '🔄');
        
        final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.task(id)}');
        
        iprint('API Request: DELETE $url', '🌐');
        iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
        
        final response = await client.delete(
          url,
          headers: ApiConfig.headers.withAuth(accessToken),
        );

        iprint('API Response Status: ${response.statusCode}', '📥');
        iprint('Response Body: ${response.body}', '📦');

        if (response.statusCode == 204 || response.statusCode == 200) {
          if (attempts > 1) {
            _eventController.add(RetrySuccess(ApiConfig.operations.task.delete, attempts));
          }
          
          // Clear cache for the deleted task
          await cache.remove(_getTaskKey(id));
          // Invalidate list cache since we deleted a task
          await cache.remove(_taskListCacheKey);
          
          _eventController.add(OperationSuccess(ApiConfig.operations.task.delete));
          _eventController.add(TaskDeleted(id));
          
          return;
        } else {
          String error;
          try {
            error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
          } catch (e) {
            error = 'Failed to parse error message: ${response.body}';
          }
          
          if (response.statusCode >= 500) {
            throw http.ClientException('Service unavailable');
          }
          throw Exception(error);
        }
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        wprint('delete_task failed after ${elapsed.inMilliseconds}ms: $e');
        
        if (!retryConfig.shouldRetry(e) || attempts >= retryConfig.maxAttempts) {
          if (attempts > 1) {
            eprint('delete_task failed after $attempts attempts', '❌');
            _eventController.add(RetryExhausted(ApiConfig.operations.task.delete, e, attempts));
          }
          _eventController.add(OperationFailure(
            ApiConfig.operations.task.delete,
            e.toString(),
          ));
          rethrow;
        }
        
        final delay = retryConfig.getDelayForAttempt(attempts);
        iprint('Waiting ${delay.inMilliseconds}ms before attempt ${attempts + 1}', '⏳');
        _eventController.add(RetryAttempt(ApiConfig.operations.task.delete, attempts, delay, e));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Stream<List<Task>> list({Map<String, dynamic>? filters}) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.list,
        () async {
          attempts++;
          var url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.list}');
          if (filters != null && filters.isNotEmpty) {
            url = url.replace(queryParameters: filters.map((k, v) => MapEntry(k, v.toString())));
          }
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final data = responseData['data'] as Map<String, dynamic>;
        final items = data['items'] as List;
        final tasks = items.map((item) => TaskModel.fromJson(item).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.list, tasks));
        _eventController.add(TasksRetrieved(tasks));
        
        yield tasks;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.list,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<Task> read(String id) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.read));
    final cacheKey = _getTaskKey(id);
    
    try {
      // Log cache operation
      iprint('Clearing cache for key: $cacheKey', '🗑️');
      
      // Clear cache and wait for completion
      await cache.remove(cacheKey);
      
      // Verify cache is cleared
      final cachedData = await cache.get(cacheKey);
      if (cachedData != null) {
        wprint('Cache not properly cleared for key: $cacheKey', '⚠️');
      }

      // Fetch fresh data
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.read,
        () async {
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.task(id)}');
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            return response;
          } else if (response.statusCode == 404) {
            throw Exception('Task not found');
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      final responseData = json.decode(response.body);
      final data = responseData['data'];
      final task = TaskModel.fromJson(data).toDomain();
      
      // Validate fetched task matches requested ID
      if (task.id != id) {
        throw Exception('Server returned incorrect task');
      }
      
      // Store in cache
      iprint('Storing task in cache with key: $cacheKey', '💾');
      await cache.set(cacheKey, data);
      
      _eventController.add(OperationSuccess(ApiConfig.operations.task.read, task));
      _eventController.add(TaskRetrieved(task));
      
      yield task;
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.read,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.list,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.list}')
              .replace(queryParameters: {'status': status.toString()});
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final dataList = responseData['data'] as List;
        final tasks = dataList.map((data) => TaskModel.fromJson(data).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.list, tasks));
        
        return tasks;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.list,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<List<Task>> getByPriority(TaskPriority priority) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.list,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.list}')
              .replace(queryParameters: {'priority': priority.toString()});
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final dataList = responseData['data'] as List;
        final tasks = dataList.map((data) => TaskModel.fromJson(data).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.list, tasks));
        
        return tasks;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.list,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<List<Task>> getSubtasks(String taskId) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.list,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.list}')
              .replace(queryParameters: {'parent_id': taskId});
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final dataList = responseData['data'] as List;
        final tasks = dataList.map((data) => TaskModel.fromJson(data).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.list, tasks));
        
        return tasks;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.list,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<Task> updateStatus(String taskId, TaskStatus status) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.task.update));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.task.update,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.task.task(taskId)}');
          final body = json.encode({'status': status.toString()});
          
          iprint('API Request: PATCH $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.patch(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        final task = TaskModel.fromJson(data).toDomain();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.task.update, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.task.update, task));
        _eventController.add(TaskUpdated(task));
        
        return task;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.task.update,
        e.toString(),
      ));
      rethrow;
    }
  }
} 