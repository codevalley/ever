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
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await useCase.dispose();
  });

  Future<void> pumpEventQueue() async {
    await Future.delayed(Duration.zero);
  }

  test('successful note creation', () async {
    final params = CreateNoteParams(

      content: 'Test Content',
      userId: 'user123',

    );

    final testNote = Note(
      id: 'note123',

      content: params.content,
      userId: params.userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.value(testNote));

    await useCase.execute(params);
    await pumpEventQueue();

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<NoteCreated>());
    expect((events[1] as NoteCreated).note, equals(testNote));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('create_note'));
  });

  test('handles validation error', () async {
    final params = CreateNoteParams(
      content: '', // Empty content should cause validation error
      userId: 'user123',

    );

    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.error('Invalid note data'));

    try {
      await useCase.execute(params);
      fail('Should throw an exception');
    } catch (e) {
      expect(e, isA<String>());
      expect(e, equals('Invalid note data'));
    }
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Invalid note data'));
  });

  test('handles network error', () async {
    final params = CreateNoteParams(

      content: 'Test Content',
      userId: 'user123',

    );

    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.error('Network error'));

    try {
      await useCase.execute(params);
      fail('Should throw an exception');
    } catch (e) {
      expect(e, isA<String>());
      expect(e, equals('Network error'));
    }
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Network error'));
  });

  test('prevents concurrent creations', () async {
    final params = CreateNoteParams(

      content: 'Test Content',
      userId: 'user123',

    );

    final testNote = Note(
      id: 'note123',

      content: params.content,
      userId: params.userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final streamController = StreamController<Note>();
    when(mockRepository.create(any))
        .thenAnswer((_) => streamController.stream);

    // Start first creation
    final firstFuture = useCase.execute(params);
    await pumpEventQueue();

    // Try second creation while first is in progress
    try {
      await useCase.execute(params);
      fail('Should throw a StateError');
    } catch (e) {
      expect(e, isA<StateError>());
      expect((e as StateError).message, contains('Creation already in progress'));
    }

    // Complete first creation
    streamController.add(testNote);
    await streamController.close();
    await firstFuture;
    await pumpEventQueue();

    // Verify only one creation was attempted
    verify(mockRepository.create(any)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_note'));
    expect(events[1], isA<NoteCreated>());
    expect(events[2], isA<OperationSuccess>());
  });
} 