import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/get_current_user_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserRepository])
import 'get_current_user_usecase_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late GetCurrentUserUseCase useCase;
  late StreamController<DomainEvent> repositoryEvents;
  late StreamController<User> userStream;

  setUp(() {
    mockRepository = MockUserRepository();
    repositoryEvents = StreamController<DomainEvent>.broadcast();
    userStream = StreamController<User>();
    
    when(mockRepository.events).thenAnswer((_) => repositoryEvents.stream);
    useCase = GetCurrentUserUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
    repositoryEvents.close();
    userStream.close();
  });

  test('successful user retrieval', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => userStream.stream);

    final testUser = User(
      id: 'user123',
      username: 'testuser',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    useCase.execute();
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('get_current_user'));
    await Future.delayed(const Duration(milliseconds: 10));

    // Repository emits success with user
    userStream.add(testUser);
    repositoryEvents.add(CurrentUserRetrieved(testUser));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<CurrentUserRetrieved>());
    expect((events[1] as CurrentUserRetrieved).user, equals(testUser));

    await subscription.cancel();
  });

  test('handles user not found', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => Stream.error('User not found'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('get_current_user', 'User not found'));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<CurrentUserRetrieved>());
    expect((events.first as CurrentUserRetrieved).user, isNull);

    await subscription.cancel();
  });

  test('handles unauthorized error', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => Stream.error('Unauthorized'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('get_current_user', 'Unauthorized'));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<CurrentUserRetrieved>());
    expect((events.first as CurrentUserRetrieved).user, isNull);

    await subscription.cancel();
  });

  test('handles other errors', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => Stream.error('Network error'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('get_current_user', 'Network error'));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, equals('Network error'));

    await subscription.cancel();
  });

  test('prevents concurrent retrievals', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => userStream.stream);

    // First retrieval
    useCase.execute();
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('get_current_user'));
    await Future.delayed(const Duration(milliseconds: 10));

    // Try second retrieval while first is in progress
    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 10));

    // Complete first retrieval
    final testUser = User(
      id: 'user123',
      username: 'testuser',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    userStream.add(testUser);
    repositoryEvents.add(CurrentUserRetrieved(testUser));
    await Future.delayed(const Duration(milliseconds: 10));

    // Verify only one retrieval was attempted
    verify(mockRepository.getCurrentUser()).called(1);
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<CurrentUserRetrieved>());

    await subscription.cancel();
  });
} 