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

  test('handles network error', () async {
    const params = DeleteNoteParams(noteId: 'note123');

    when(mockRepository.delete(params.noteId))
        .thenAnswer((_) => Stream.error('Network error'));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_note'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Network error'));
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
} 