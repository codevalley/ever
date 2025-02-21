import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/note_events.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/usecases/note/delete_note_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([NoteRepository])
import 'delete_note_usecase_test.mocks.dart';

void main() {
  late MockNoteRepository mockRepository;
  late DeleteNoteUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = DeleteNoteUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await useCase.dispose();
  });

  test('successful note deletion', () async {
    const params = DeleteNoteParams(noteId: 'note123');

    when(mockRepository.delete(params.noteId))
        .thenAnswer((_) => Stream.value(null));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_note'));
    expect(events[1], isA<NoteDeleted>());
    expect((events[1] as NoteDeleted).noteId, equals(params.noteId));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('delete_note'));
  });

  test('handles note not found', () async {
    const params = DeleteNoteParams(noteId: 'nonexistent');

    when(mockRepository.delete(params.noteId))
        .thenAnswer((_) => Stream.error('Note not found'));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Note not found'));
  });

  test('handles network error with retries', () async {
    const params = DeleteNoteParams(noteId: 'note123');

    // Mock repository to fail with network error 3 times then succeed
    var attempts = 0;
    when(mockRepository.delete(params.noteId))
        .thenAnswer((_) {
          attempts++;
          if (attempts <= 3) {
            return Stream.error('Network error');
          }
          return Stream.value(null);
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
    expect(events[4], isA<NoteDeleted>());         // Success on fourth attempt
    expect(events[5], isA<OperationSuccess>());    // Final success

    // Verify repository was called 4 times
    verify(mockRepository.delete(params.noteId)).called(4);
  });

  test('handles network error exhausting retries', () async {
    const params = DeleteNoteParams(noteId: 'note123');

    // Mock repository to always fail with network error
    when(mockRepository.delete(params.noteId))
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
    verify(mockRepository.delete(params.noteId)).called(4);
  });

  test('prevents concurrent deletions', () async {
    const params = DeleteNoteParams(noteId: 'note123');

    final completer = Completer<void>();
    when(mockRepository.delete(params.noteId))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First deletion
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second deletion while first is in progress
    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Complete first deletion
    completer.complete();
    await Future.delayed(Duration.zero);

    // Verify only one deletion was attempted
    verify(mockRepository.delete(params.noteId)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_note'));
    expect(events[1], isA<NoteDeleted>());
    expect(events[2], isA<OperationSuccess>());
  });

  test('validates note id', () async {
    const params = DeleteNoteParams(noteId: '');

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events[0], isA<OperationFailure>());
    expect((events[0] as OperationFailure).error, equals('Note ID cannot be empty'));
    verifyNever(mockRepository.delete(any));
  });
} 