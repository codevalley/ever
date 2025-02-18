import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/refresh_token_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserRepository])
import 'refresh_token_usecase_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late RefreshTokenUseCase useCase;
  late StreamController<DomainEvent> repositoryEvents;
  late StreamController<String> tokenStream;

  setUp(() {
    mockRepository = MockUserRepository();
    repositoryEvents = StreamController<DomainEvent>.broadcast();
    tokenStream = StreamController<String>();
    
    when(mockRepository.events).thenAnswer((_) => repositoryEvents.stream);
    useCase = RefreshTokenUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
    repositoryEvents.close();
    tokenStream.close();
  });

  test('sets up expiration timers on token obtained', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.refreshToken())
        .thenAnswer((_) => tokenStream.stream);

    // Set up token that expires in 15 minutes
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    
    // Emit token obtained event
    repositoryEvents.add(TokenObtained('token123', expiresAt));
    await Future.delayed(const Duration(milliseconds: 100));

    // Verify initial event
    expect(events, hasLength(1));
    expect(events.first, isA<TokenObtained>());

    // Manually trigger refresh
    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 100));
    
    verify(mockRepository.refreshToken()).called(1);

    await subscription.cancel();
  });

  test('prevents concurrent refresh operations', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.refreshToken())
        .thenAnswer((_) => tokenStream.stream);

    // First refresh
    useCase.execute();
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('refresh_token'));
    await Future.delayed(const Duration(milliseconds: 10));

    // Try second refresh while first is in progress
    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 10));

    // Complete first refresh
    tokenStream.add('new_token');
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    repositoryEvents.add(TokenRefreshed('new_token', expiresAt));
    await Future.delayed(const Duration(milliseconds: 10));

    // Verify only one refresh was attempted
    verify(mockRepository.refreshToken()).called(1);
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<TokenRefreshed>());

    await subscription.cancel();
  });

  test('handles refresh failure', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.refreshToken())
        .thenAnswer((_) => Stream.error('Refresh failed'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('refresh_token', 'Refresh failed'));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<TokenRefreshFailed>());
    expect((events.first as TokenRefreshFailed).error, 'Refresh failed');

    await subscription.cancel();
  });

  test('emits token expired when token expires', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    // Set up token that expires immediately
    final expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    
    // Emit the token obtained event
    final obtainedEvent = TokenObtained('token123', expiresAt);
    repositoryEvents.add(obtainedEvent);
    
    // Wait for events to be processed
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Verify events - note that TokenExpired is emitted first due to immediate expiration
    expect(events.length, 2, reason: 'Expected both TokenExpired and TokenObtained events');
    expect(events[0], isA<TokenExpired>(), reason: 'First event should be TokenExpired for expired token');
    expect(events[1], isA<TokenObtained>(), reason: 'Second event should be TokenObtained');
    expect((events[1] as TokenObtained).token, equals('token123'));
    expect((events[1] as TokenObtained).expiresAt, equals(expiresAt));

    await subscription.cancel();
  });

  test('attempts refresh when token is close to expiry', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.refreshToken())
        .thenAnswer((_) => tokenStream.stream);

    // Set up token that expires soon (within refresh threshold)
    final expiresAt = DateTime.now().add(const Duration(minutes: 8));
    repositoryEvents.add(TokenObtained('token123', expiresAt));
    
    await Future.delayed(const Duration(milliseconds: 10));

    // Should trigger automatic refresh
    verify(mockRepository.refreshToken()).called(1);

    // Complete refresh
    tokenStream.add('new_token');
    final newExpiresAt = DateTime.now().add(const Duration(hours: 1));
    repositoryEvents.add(TokenRefreshed('new_token', newExpiresAt));
    
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, containsAllInOrder([
      isA<TokenObtained>(),
      isA<TokenRefreshed>(),
    ]));

    await subscription.cancel();
  });

  test('cleans up timers on dispose', () async {
    // Set up token with future expiry
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    repositoryEvents.add(TokenObtained('token123', expiresAt));
    
    await Future.delayed(const Duration(milliseconds: 10));
    
    // Dispose use case
    useCase.dispose();

    // No more events should be emitted
    expect(useCase.events, emitsDone);
  });
} 