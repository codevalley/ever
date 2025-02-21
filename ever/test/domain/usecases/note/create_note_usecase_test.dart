import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/note_events.dart';
import 'package:ever/domain/entities/note.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/usecases/note/create_note_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([NoteRepository])
import 'create_note_usecase_test.mocks.dart';

void main() {
  late MockNoteRepository mockRepository;
  late CreateNoteUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = CreateNoteUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen((event) {
      events.add(event);
    });
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await useCase.dispose();
  });

  test('successful note creation', () async {
    final params = CreateNoteParams(
      content: 'Test note',
      userId: 'user123',
    );

    final testNote = Note(
      id: 'note1',
      content: params.content,
      userId: params.userId,
      createdAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.value(testNote));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<NoteCreated>());
    expect((events[1] as NoteCreated).note, equals(testNote));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('create_note'));
  });

  test('handles creation failure', () async {
    final params = CreateNoteParams(
      content: 'Test note',
      userId: 'user123',
    );

    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.error('Failed to create note'));

    expect(
      () => useCase.execute(params),
      throwsA(isA<String>()),
    );

    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).operation, equals('create_note'));
    expect((events[1] as OperationFailure).error, equals('Failed to create note'));
  });

  test('prevents concurrent creations', () async {
    final params = CreateNoteParams(
      content: 'Test note',
      userId: 'user123',
    );

    final completer = Completer<Note>();
    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First creation
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second creation while first is in progress
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()),
    );

    // Complete first creation
    final testNote = Note(
      id: 'note1',
      content: params.content,
      userId: params.userId,
      createdAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );
    completer.complete(testNote);
    await Future.delayed(Duration.zero);

    verify(mockRepository.create(any)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<NoteCreated>());
    expect(events[2], isA<OperationSuccess>());
  });
} 