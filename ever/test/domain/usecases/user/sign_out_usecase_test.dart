import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/user_events.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/user/sign_out_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([UserRepository])
import 'sign_out_usecase_test.mocks.dart';

void main() {
  late MockUserRepository mockRepository;
  late SignOutUseCase useCase;
  late StreamController<DomainEvent> repositoryEvents;
  late StreamController<void> signOutStream;

  setUp(() {
    mockRepository = MockUserRepository();
    repositoryEvents = StreamController<DomainEvent>.broadcast();
    signOutStream = StreamController<void>();
    
    when(mockRepository.events).thenAnswer((_) => repositoryEvents.stream);
    useCase = SignOutUseCase(mockRepository);
  });

  tearDown(() {
    useCase.dispose();
    repositoryEvents.close();
    signOutStream.close();
  });

  test('successful sign out', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.signOut())
        .thenAnswer((_) => signOutStream.stream);

    useCase.execute();
    
    // Repository emits progress
    repositoryEvents.add(OperationInProgress('sign_out'));
    await Future.delayed(Duration(milliseconds: 10));

    // Repository emits success
    signOutStream.add(null);
    repositoryEvents.add(const UserLoggedOut());
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, 'sign_out');
    expect(events[1], isA<UserLoggedOut>());

    await subscription.cancel();
  });

  test('forwards repository failure', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.signOut())
        .thenAnswer((_) => Stream.error('Sign out failed'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('sign_out', 'Sign out failed'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<OperationFailure>());
    expect((events.first as OperationFailure).error, 'Sign out failed');

    await subscription.cancel();
  });

  test('converts unauthorized error to success', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.signOut())
        .thenAnswer((_) => Stream.error('Unauthorized'));

    useCase.execute();
    
    repositoryEvents.add(OperationFailure('sign_out', 'Unauthorized'));
    await Future.delayed(Duration(milliseconds: 10));

    expect(events, hasLength(1));
    expect(events.first, isA<UserLoggedOut>());

    await subscription.cancel();
  });

  test('prevents concurrent sign outs', () async {
    final events = <DomainEvent>[];
    final subscription = useCase.events.listen(events.add);

    when(mockRepository.signOut())
        .thenAnswer((_) => signOutStream.stream);

    // First sign out
    useCase.execute();
    
    // Repository emits progress for first sign out
    repositoryEvents.add(OperationInProgress('sign_out'));
    await Future.delayed(Duration(milliseconds: 10));

    // Try second sign out while first is in progress
    useCase.execute();
    await Future.delayed(Duration(milliseconds: 10));

    // Complete first sign out
    signOutStream.add(null);
    repositoryEvents.add(const UserLoggedOut());
    await Future.delayed(Duration(milliseconds: 10));

    // Verify only one sign out was processed
    verify(mockRepository.signOut()).called(1);
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<UserLoggedOut>());

    await subscription.cancel();
  });
} 