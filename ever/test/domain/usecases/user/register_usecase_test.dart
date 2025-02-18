import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/register_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserRepository])
import 'register_usecase_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late RegisterUseCase useCase;
  late StreamController<DomainEvent> repositoryEvents;
  late StreamController<User> userStream;

  setUp(() {
    mockRepository = MockUserRepository();
    repositoryEvents = StreamController<DomainEvent>.broadcast();
    userStream = StreamController<User>();
    
    when(mockRepository.events).thenAnswer((_) => repositoryEvents.stream);
    useCase = RegisterUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
    repositoryEvents.close();
    userStream.close();
  });

  test('validates username - empty', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(RegisterParams(username: '  '));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 'Username cannot be empty');

    await subscription.cancel();
  });

  test('validates username - too short', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(RegisterParams(username: 'ab'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 
           'Username must be at least 3 characters');

    await subscription.cancel();
  });

  test('validates username - invalid characters', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(RegisterParams(username: 'user@name'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 
           'Username can only contain letters, numbers, and underscores');

    await subscription.cancel();
  });

  test('successful registration', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    final testUser = User(
      id: 'user123',
      username: 'testuser',
      userSecret: 'secret123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    when(mockRepository.register(any))
        .thenAnswer((_) => userStream.stream);

    useCase.execute(RegisterParams(username: 'testuser'));
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('register'));
    await Future.delayed(Duration(milliseconds: 10));

    // Repository emits success with user
    userStream.add(testUser);
    repositoryEvents.add(UserRegistered(testUser, testUser.userSecret!));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, 'register');
    expect(events[1], isA<UserRegistered>());
    expect((events[1] as UserRegistered).user.username, 'testuser');
    expect((events[1] as UserRegistered).userSecret, 'secret123');

    await subscription.cancel();
  });

  test('forwards repository failure', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.register(any))
        .thenAnswer((_) => Stream.error('Username already taken'));

    useCase.execute(RegisterParams(username: 'testuser'));
    
    repositoryEvents.add(OperationFailure('register', 'Username already taken'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 'Username already taken');

    await subscription.cancel();
  });
} 