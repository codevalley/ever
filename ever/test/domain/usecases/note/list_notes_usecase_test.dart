import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/note_events.dart';
import 'package:ever/domain/entities/note.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/usecases/note/list_notes_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([NoteRepository])
import 'list_notes_usecase_test.mocks.dart';

void main() {
  late MockNoteRepository mockRepository;
  late ListNotesUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = ListNotesUseCase(mockRepository);
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

  test('successful notes listing', () async {
    final params = ListNotesParams(filters: {'user_id': 'user123'});

    final testNotes = [
      Note(
        id: 'note1',
        content: 'Content 1',
        userId: 'user123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      ),
      Note(
        id: 'note2',
        content: 'Content 2',
        userId: 'user123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      ),
    ];

    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.value(testNotes));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_notes'));
    expect(events[1], isA<NotesRetrieved>());
    expect((events[1] as NotesRetrieved).notes, equals(testNotes));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_notes'));
  });

  test('handles empty list', () async {
    final params = ListNotesParams();

    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.value([]));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_notes'));
    expect(events[1], isA<NotesRetrieved>());
    expect((events[1] as NotesRetrieved).notes, isEmpty);
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_notes'));
  });

  test('handles network error with retries', () async {
    final params = ListNotesParams();

    // Mock repository to always return error
    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.error('Network error'));

    // Execute and wait for completion
    await useCase.execute(params);

    // Wait for all retries to complete (100ms + 200ms + 300ms)
    await Future.delayed(Duration(milliseconds: 700));

    // Print events for debugging
    print('Events received: ${events.map((e) => e.runtimeType).toList()}');

    // Verify the sequence of events
    expect(events.length, equals(5), reason: 'Expected: Initial + 3 retries + Final failure');

    // Verify the sequence
    var eventTypes = events.map((e) => e.runtimeType).toList();
    expect(eventTypes, equals([
      OperationInProgress, // Initial attempt
      OperationInProgress, // First retry
      OperationInProgress, // Second retry
      OperationInProgress, // Third retry
      OperationFailure,    // Final failure
    ]));

    // Verify operation names and error
    for (var i = 0; i < 4; i++) {
      expect((events[i] as OperationInProgress).operation, equals('list_notes'),
          reason: 'Event $i should be for list_notes operation');
    }
    expect((events.last as OperationFailure).operation, equals('list_notes'));
    expect((events.last as OperationFailure).error, equals('Network error'));

    // Verify repository was called 4 times (initial + 3 retries)
    verify(mockRepository.list(filters: anyNamed('filters'))).called(4);
  });

  test('prevents concurrent listings', () async {
    final params = ListNotesParams(filters: {'user_id': 'user123'});

    final completer = Completer<List<Note>>();
    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First listing
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second listing while first is in progress
    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Complete first listing
    final testNotes = [
      Note(
        id: 'note1',
        content: 'Content 1',
        userId: 'user123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      ),
    ];
    completer.complete(testNotes);
    await Future.delayed(Duration.zero);

    // Verify only one listing was attempted
    verify(mockRepository.list(filters: anyNamed('filters'))).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_notes'));
    expect(events[1], isA<NotesRetrieved>());
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_notes'));
  });
} 