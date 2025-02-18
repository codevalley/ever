import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/user_events.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/login_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserRepository])
import 'login_usecase_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late LoginUseCase useCase;
  late StreamController<DomainEvent> repositoryEvents;
  late StreamController<String> tokenStream;

  setUp(() {
    mockRepository = MockUserRepository();
    repositoryEvents = StreamController<DomainEvent>.broadcast();
    tokenStream = StreamController<String>();
    
    when(mockRepository.events).thenAnswer((_) => repositoryEvents.stream);
    useCase = LoginUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
    repositoryEvents.close();
    tokenStream.close();
  });

  test('validates user secret - empty', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(LoginParams(userSecret: '  '));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 'User secret cannot be empty');

    await subscription.cancel();
  });

  test('validates user secret - too short', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(LoginParams(userSecret: 'abc123'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 
           'User secret must be at least 8 characters');

    await subscription.cancel();
  });

  test('validates user secret - format', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    useCase.execute(LoginParams(userSecret: '12345678'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 
           'User secret must contain at least one letter and one number');

    await subscription.cancel();
  });

  test('successful token acquisition', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.obtainToken(any))
        .thenAnswer((_) => tokenStream.stream);

    useCase.execute(LoginParams(userSecret: 'validPass123'));
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('login'));
    await Future.delayed(Duration(milliseconds: 10));

    // Repository emits success with token
    tokenStream.add('token123');
    repositoryEvents.add(TokenObtained('token123', DateTime.now().add(Duration(hours: 1))));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, 'login');
    expect(events[1], isA<TokenObtained>());
    expect((events[1] as TokenObtained).token, 'token123');

    await subscription.cancel();
  });

  test('forwards repository failure', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.obtainToken(any))
        .thenAnswer((_) => Stream.error('Authentication failed'));

    useCase.execute(LoginParams(userSecret: 'validPass123'));
    
    repositoryEvents.add(OperationFailure('login', 'Authentication failed'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 'Authentication failed');

    await subscription.cancel();
  });
} 