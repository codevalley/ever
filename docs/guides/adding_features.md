# Adding New Features Guide

This guide demonstrates how to add new features to the Ever application following our established clean architecture pattern. We'll use the implementation of a "Note" feature as an example.

## Step 1: Domain Layer Setup

### 1.1 Create the Entity (domain/entities/note.dart)
```dart
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode;
}
```

### 1.2 Define Events (domain/events/note_events.dart)
```dart
import '../core/events.dart';
import '../entities/note.dart';

class NoteCreated extends DomainEvent {
  final Note note;
  const NoteCreated(this.note);
}

class NoteUpdated extends DomainEvent {
  final Note note;
  const NoteUpdated(this.note);
}

class NoteDeleted extends DomainEvent {
  final String noteId;
  const NoteDeleted(this.noteId);
}

class NotesRetrieved extends DomainEvent {
  final List<Note> notes;
  const NotesRetrieved(this.notes);
}
```

### 1.3 Define Data Source Interface (domain/datasources/note_ds.dart)
```dart
import '../core/events.dart';
import '../entities/note.dart';

abstract class NoteDataSource {
  Stream<DomainEvent> get events;
  
  Stream<Note> create(Note note);
  Stream<Note> update(Note note);
  Stream<void> delete(String id);
  Stream<List<Note>> list({Map<String, dynamic>? filters});
  Stream<Note> read(String id);
  
  Future<void> initialize();
  void dispose();
}
```

### 1.4 Define Repository Interface (domain/repositories/note_repository.dart)
```dart
import '../core/events.dart';
import '../entities/note.dart';

abstract class NoteRepository {
  Stream<DomainEvent> get events;
  
  Stream<Note> create(Note note);
  Stream<Note> update(Note note);
  Stream<void> delete(String id);
  Stream<List<Note>> list({Map<String, dynamic>? filters});
  Stream<Note> read(String id);
  
  Future<void> initialize();
  void dispose();
}
```

### 1.5 Create Use Cases (domain/usecases/note/...)

#### create_note_usecase.dart
```dart
import '../../core/events.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

class CreateNoteParams {
  final String title;
  final String content;
  final String userId;

  const CreateNoteParams({
    required this.title,
    required this.content,
    required this.userId,
  });
}

class CreateNoteUseCase extends BaseUseCase<CreateNoteParams> {
  final NoteRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();

  CreateNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(CreateNoteParams params) async {
    _events.add(OperationInProgress('create_note'));
    
    try {
      final note = Note(
        id: '', // Will be set by backend
        title: params.title,
        content: params.content,
        userId: params.userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await for (final createdNote in _repository.create(note)) {
        _events.add(NoteCreated(createdNote));
      }
    } catch (e) {
      _events.add(OperationFailure('create_note', e.toString()));
    }
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
```

## Step 2: Implementation Layer Setup

### 2.1 Create Data Model (implementations/models/note_model.dart)
```dart
import '../../domain/entities/note.dart';

class NoteModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  // Convert from JSON
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userId: json['user_id'] as String,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
    };
  }

  // Convert to domain entity
  Note toDomain() {
    return Note(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: userId,
    );
  }

  // Create from domain entity
  factory NoteModel.fromDomain(Note note) {
    return NoteModel(
      id: note.id,
      title: note.title,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      userId: note.userId,
    );
  }
}
```

### 2.2 Implement Data Source (implementations/datasources/note_ds_impl.dart)
```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/logging.dart';
import '../../domain/core/events.dart';
import '../../domain/datasources/note_ds.dart';
import '../../domain/entities/note.dart';
import '../config/api_config.dart';
import '../models/note_model.dart';

class NoteDataSourceImpl implements NoteDataSource {
  final http.Client client;
  final _eventController = StreamController<DomainEvent>.broadcast();

  NoteDataSourceImpl({
    required this.client,
  });

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Stream<Note> create(Note note) async* {
    _eventController.add(OperationInProgress('create_note'));
    
    try {
      final url = Uri.parse('${ApiConfig.apiBaseUrl}/notes');
      final model = NoteModel.fromDomain(note);
      
      final response = await client.post(
        url,
        headers: ApiConfig.headers.json,
        body: json.encode(model.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body)['data'];
        final createdNote = NoteModel.fromJson(data).toDomain();
        _eventController.add(OperationSuccess('create_note', createdNote));
        yield createdNote;
      } else {
        throw Exception('Failed to create note');
      }
    } catch (e) {
      _eventController.add(OperationFailure('create_note', e.toString()));
      rethrow;
    }
  }

  // Implement other methods similarly...
}
```

### 2.3 Implement Repository (implementations/repositories/note_repository_impl.dart)
```dart
import 'dart:async';

import '../../domain/core/events.dart';
import '../../domain/datasources/note_ds.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  final NoteDataSource _dataSource;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _dataSourceSubscription;

  NoteRepositoryImpl(this._dataSource) {
    _dataSourceSubscription = _dataSource.events.listen(_eventController.add);
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Stream<Note> create(Note note) => _dataSource.create(note);

  @override
  Stream<Note> update(Note note) => _dataSource.update(note);

  @override
  Stream<void> delete(String id) => _dataSource.delete(id);

  @override
  Stream<List<Note>> list({Map<String, dynamic>? filters}) => 
      _dataSource.list(filters: filters);

  @override
  Stream<Note> read(String id) => _dataSource.read(id);

  @override
  Future<void> initialize() => _dataSource.initialize();

  @override
  void dispose() {
    _dataSourceSubscription?.cancel();
    _eventController.close();
    _dataSource.dispose();
  }
}
```

## Step 3: Update Presenter

### 3.1 Update EverState (domain/presenter/ever_presenter.dart)
```dart
class EverState {
  // Add notes to state
  final List<Note> notes;

  const EverState({
    // ... existing fields ...
    this.notes = const [],
  });

  // Update copyWith
  EverState copyWith({
    // ... existing parameters ...
    List<Note>? notes,
  }) {
    return EverState(
      // ... existing fields ...
      notes: notes ?? this.notes,
    );
  }
}
```

### 3.2 Update Presenter Interface
```dart
abstract class EverPresenter {
  // ... existing methods ...

  // Add note methods
  Future<void> createNote(String title, String content);
  Future<void> updateNote(String noteId, {String? title, String? content});
  Future<void> deleteNote(String noteId);
  Future<void> getNotes();
}
```

### 3.3 Update Presenter Implementation
```dart
class EverPresenterImpl implements EverPresenter {
  final CreateNoteUseCase _createNoteUseCase;
  // ... other use cases ...

  void _handleNoteEvents(DomainEvent event) {
    if (event is NoteCreated) {
      _updateState((state) => state.copyWith(
        notes: [...state.notes, event.note],
      ));
    } else if (event is NoteUpdated) {
      _updateState((state) => state.copyWith(
        notes: state.notes.map((note) => 
          note.id == event.note.id ? event.note : note
        ).toList(),
      ));
    } else if (event is NoteDeleted) {
      _updateState((state) => state.copyWith(
        notes: state.notes.where((note) => 
          note.id != event.noteId
        ).toList(),
      ));
    } else if (event is NotesRetrieved) {
      _updateState((state) => state.copyWith(
        notes: event.notes,
      ));
    }
  }
}
```

## Step 4: Testing

### 4.1 Entity Tests (test/domain/entities/note_test.dart)
```dart
import 'package:test/test.dart';
import 'package:ever/domain/entities/note.dart';

void main() {
  group('Note Entity', () {
    test('equality', () {
      final note1 = Note(
        id: '1',
        title: 'Test',
        content: 'Content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        userId: 'user1',
      );

      final note2 = Note(
        id: '1',
        title: 'Test',
        content: 'Content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        userId: 'user1',
      );

      expect(note1, equals(note2));
    });
  });
}
```

### 4.2 Use Case Tests (test/domain/usecases/note/create_note_usecase_test.dart)
```dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:ever/domain/repositories/note_repository.dart';
import 'package:ever/domain/usecases/note/create_note_usecase.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  group('CreateNoteUseCase', () {
    late MockNoteRepository repository;
    late CreateNoteUseCase useCase;

    setUp(() {
      repository = MockNoteRepository();
      useCase = CreateNoteUseCase(repository);
    });

    test('creates note successfully', () async {
      // Test implementation
    });
  });
}
```

## Best Practices

1. **Consistent Naming**
   - Use consistent suffixes: `_ds.dart`, `_repository.dart`, `_usecase.dart`
   - Keep event names action-based: `NoteCreated`, `NoteUpdated`

2. **Error Handling**
   - Always emit appropriate events for errors
   - Use specific error types when possible
   - Include meaningful error messages

3. **Testing**
   - Test all use cases
   - Test repository implementations
   - Test error scenarios
   - Use mocks appropriately

4. **Documentation**
   - Document public APIs
   - Include examples in complex cases
   - Explain non-obvious decisions

5. **Event Handling**
   - Clean up subscriptions
   - Handle edge cases
   - Maintain proper event order

## Common Pitfalls to Avoid

1. Don't skip error handling in streams
2. Don't forget to dispose of resources
3. Don't mix domain and implementation concerns
4. Don't bypass the repository layer
5. Don't emit unnecessary state updates

## Next Steps

After implementing a new feature:

1. Update the API configuration
2. Add new endpoints
3. Update the presenter factory
4. Add UI components
5. Write integration tests
6. Update documentation 