import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
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
  late StreamController<User> userStream;

  setUp(() {
    mockRepository = MockUserRepository();
    userStream = StreamController<User>();
    useCase = GetCurrentUserUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
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
    await Future.delayed(const Duration(milliseconds: 50));

    userStream.add(testUser);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_current_user'));
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
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_current_user'));
    expect(events[1], isA<CurrentUserRetrieved>());
    expect((events[1] as CurrentUserRetrieved).user, isNull);

    await subscription.cancel();
  });

  test('handles unauthorized error', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => Stream.error('Unauthorized'));

    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_current_user'));
    expect(events[1], isA<CurrentUserRetrieved>());
    expect((events[1] as CurrentUserRetrieved).user, isNull);

    await subscription.cancel();
  });

  test('handles other errors', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => Stream.error('Network error'));

    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_current_user'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Network error'));

    await subscription.cancel();
  });

  test('prevents concurrent retrievals', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.getCurrentUser())
        .thenAnswer((_) => userStream.stream);

    // First retrieval
    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 50));

    // Try second retrieval while first is in progress
    useCase.execute();
    await Future.delayed(const Duration(milliseconds: 50));

    // Complete first retrieval
    final testUser = User(
      id: 'user123',
      username: 'testuser',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    userStream.add(testUser);
    await Future.delayed(const Duration(milliseconds: 50));

    // Verify only one retrieval was attempted
    verify(mockRepository.getCurrentUser()).called(1);
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_current_user'));
    expect(events[1], isA<CurrentUserRetrieved>());

    await subscription.cancel();
  });
} 