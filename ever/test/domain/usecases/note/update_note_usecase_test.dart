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

  test('successful note update', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      title: 'Updated Title',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      title: 'Original Title',
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updatedNote = Note(
      id: params.noteId,
      title: params.title!,
      content: params.content!,
      userId: existingNote.userId,
      createdAt: existingNote.createdAt,
      updatedAt: DateTime.now(),
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
      title: 'Updated Title',
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

  test('handles validation error', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      title: '', // Empty title should cause validation error
    );

    final existingNote = Note(
      id: params.noteId,
      title: 'Original Title',
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.value(existingNote));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.error('Invalid note data'));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Invalid note data'));
  });

  test('handles network error', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      title: 'Original Title',
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    when(mockRepository.read(params.noteId))
        .thenAnswer((_) => Stream.value(existingNote));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.error('Network error'));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Network error'));
  });

  test('prevents concurrent updates', () async {
    final params = UpdateNoteParams(
      noteId: 'note123',
      title: 'Updated Title',
      content: 'Updated Content',
    );

    final existingNote = Note(
      id: params.noteId,
      title: 'Original Title',
      content: 'Original Content',
      userId: 'user123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      title: params.title!,
      content: params.content!,
      userId: existingNote.userId,
      createdAt: existingNote.createdAt,
      updatedAt: DateTime.now(),
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