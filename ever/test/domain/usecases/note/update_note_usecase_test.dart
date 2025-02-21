import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/note_events.dart';
import 'package:ever/domain/entities/note.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/usecases/note/update_note_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([NoteRepository])
import 'update_note_usecase_test.mocks.dart';

void main() {
  late MockNoteRepository mockRepository;
  late UpdateNoteUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = UpdateNoteUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await useCase.dispose();
  });

  test('validates empty note id', () async {
    final params = UpdateNoteParams(
      noteId: '',
      content: 'Updated Content',
    );

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events[0], isA<OperationFailure>());
    expect((events[0] as OperationFailure).error, equals('Note ID cannot be empty'));
    verifyNever(mockRepository.read(any));
    verifyNever(mockRepository.update(any));
  });

  test('validates empty content', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: '',
    );

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events[0], isA<OperationFailure>());
    expect((events[0] as OperationFailure).error, equals('Content cannot be empty if provided'));
    verifyNever(mockRepository.read(any));
    verifyNever(mockRepository.update(any));
  });

  test('successful note update', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final updatedNote = Note(
      id: params.noteId,
      content: params.content!,
      userId: existingNote.userId,
      createdAt: existingNote.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingNote.processingStatus,
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.value(existingNote));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.value(updatedNote));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_note'));
    expect(events[1], isA<NoteUpdated>());
    expect((events[1] as NoteUpdated).note, equals(updatedNote));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('update_note'));
  });

  test('handles note not found', () async {
    final params = UpdateNoteParams(
      noteId: 'nonexistent',
      content: 'Updated Content',
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.error('Note not found'));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Note not found'));
  });

  test('handles network error with retries', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final updatedNote = Note(
      id: params.noteId,
      content: params.content!,
      userId: existingNote.userId,
      createdAt: existingNote.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingNote.processingStatus,
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.value(existingNote));

    // Mock repository to fail with network error 3 times then succeed
    var attempts = 0;
    when(mockRepository.update(any))
        .thenAnswer((_) {
          attempts++;
          if (attempts <= 3) {
            return Stream.error('Network error');
          }
          return Stream.value(updatedNote);
        });

    await useCase.execute(params);
    // Wait for all retries (100ms + 200ms + 300ms)
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events sequence
    expect(events.length, equals(6));
    expect(events[0], isA<OperationInProgress>()); // Initial attempt
    expect(events[1], isA<OperationInProgress>()); // First retry
    expect(events[2], isA<OperationInProgress>()); // Second retry
    expect(events[3], isA<OperationInProgress>()); // Third retry
    expect(events[4], isA<NoteUpdated>());         // Success on fourth attempt
    expect(events[5], isA<OperationSuccess>());    // Final success

    // Verify repository was called 4 times
    verify(mockRepository.update(any)).called(4);
  });

  test('handles network error exhausting retries', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.value(existingNote));

    // Mock repository to always fail with network error
    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.error('Network error'));

    await useCase.execute(params);
    // Wait for all retries (100ms + 200ms + 300ms)
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events sequence
    expect(events.length, equals(5));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationInProgress>());
    expect(events[2], isA<OperationInProgress>());
    expect(events[3], isA<OperationInProgress>());
    expect(events[4], isA<OperationFailure>());
    expect((events[4] as OperationFailure).error, equals('Network error'));

    // Verify repository was called 4 times (initial + 3 retries)
    verify(mockRepository.update(any)).called(4);
  });

  test('prevents concurrent updates', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final readCompleter = Completer<Note>();
    final updateCompleter = Completer<Note>();

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.fromFuture(readCompleter.future));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.fromFuture(updateCompleter.future));

    // First update
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second update while first is in progress
    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Complete first update
    readCompleter.complete(existingNote);
    await Future.delayed(Duration.zero);

    final updatedNote = Note(
      id: params.noteId,
      content: params.content!,
      userId: existingNote.userId,
      createdAt: existingNote.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingNote.processingStatus,
    );
    updateCompleter.complete(updatedNote);
    await Future.delayed(Duration.zero);

    // Verify only one update was attempted
    verify(mockRepository.update(any)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_note'));
    expect(events[1], isA<NoteUpdated>());
    expect(events[2], isA<OperationSuccess>());
  });
} 