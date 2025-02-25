import '../entities/user.dart';
import '../entities/note.dart';
import '../entities/task.dart';
import '../core/events.dart';

/// Abstract interface for Ever presentation logic
///
/// This abstraction allows for multiple UI implementations while maintaining
/// separation from the domain layer. Implementations can include:
/// - Flutter UI implementation
/// - CLI implementation
/// - Web implementation
/// - etc.
abstract class EverPresenter {
  /// Stream of the current state
  Stream<EverState> get state;

  /// Stream of domain events
  Stream<DomainEvent> get events;

  /// Initialize the presenter
  Future<void> initialize();

  /// Authentication Actions
  Future<void> register(String username);
  Future<void> login(String userSecret);
  Future<void> logout();
  Future<void> refreshSession();

  /// User Actions
  Future<void> getCurrentUser();

  /// Note Actions
  Future<void> createNote(String content);
  Future<void> updateNote(String noteId, {String? content});
  Future<void> deleteNote(String noteId);
  Stream<Note> getNote(String noteId);
  Future<List<Note>> listNotes({bool includeArchived = false});

  /// Task Actions
  Future<void> createTask({
    required String content,
    TaskStatus? status = TaskStatus.todo,
    TaskPriority? priority = TaskPriority.medium,
    DateTime? dueDate,
    List<String>? tags,
    String? parentId,
    String? topicId,
  });
  Future<void> updateTask(String taskId, {
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    List<String>? tags,
    String? parentId,
    String? topicId,
  });
  Future<void> deleteTask(String taskId);
  Future<void> viewTask(String taskId);
  Future<void> listTasks();

  /// General Actions
  Future<void> refresh();
  Future<void> dispose();

  /// Get cached user secret if available
  Future<String?> getCachedUserSecret();
}

/// Represents the state of the Ever UI
class EverState {
  final bool isLoading;
  final User? currentUser;
  final List<Note> notes;
  final List<Task> tasks;
  final String? error;
  final bool isAuthenticated;

  const EverState({
    this.isLoading = false,
    this.currentUser,
    this.notes = const [],
    this.tasks = const [],
    this.error,
    this.isAuthenticated = false,
  });

  /// Create initial state
  factory EverState.initial() => const EverState();

  /// Create loading state
  factory EverState.loading() => const EverState(isLoading: true);

  /// Create error state
  factory EverState.error(String message) => EverState(error: message);

  /// Create authenticated state
  factory EverState.authenticated(User user) => EverState(
        currentUser: user,
        isAuthenticated: true,
      );

  /// Create a copy of this state with some fields replaced
  EverState copyWith({
    bool? isLoading,
    User? currentUser,
    List<Note>? notes,
    List<Task>? tasks,
    String? error,
    bool? isAuthenticated,
  }) {
    return EverState(
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EverState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          currentUser == other.currentUser &&
          notes == other.notes &&
          tasks == other.tasks &&
          error == other.error &&
          isAuthenticated == other.isAuthenticated;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      currentUser.hashCode ^
      notes.hashCode ^
      tasks.hashCode ^
      error.hashCode ^
      isAuthenticated.hashCode;
} 