import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/note_events.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for deleting a note
class DeleteNoteParams {
  final String noteId;

  const DeleteNoteParams({required this.noteId});

  bool validate() {
    return noteId.isNotEmpty;
  }

  String? validateWithMessage() {
    if (noteId.isEmpty) {
      return 'Note ID cannot be empty';
    }
    return null;
  }
}

/// Use case for deleting a note
class DeleteNoteUseCase extends BaseUseCase<DeleteNoteParams> {
  final NoteRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  bool _isDeleting = false;
  int _retryCount = 0;
  static const _maxRetries = 3;

  DeleteNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(DeleteNoteParams params) async {
    if (_isDeleting) {
      return;
    }

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _events.add(OperationFailure('delete_note', validationError));
      return;
    }
    
    _isDeleting = true;
    _retryCount = 0;
    _events.add(OperationInProgress('delete_note'));
    
    while (true) {
      try {
        await for (final _ in _repository.delete(params.noteId)) {
          _events.add(NoteDeleted(params.noteId));
          _events.add(const OperationSuccess('delete_note'));
          _isDeleting = false;
          _retryCount = 0;
          return;
        }
      } catch (e) {
        if (_retryCount < _maxRetries && _shouldRetry(e)) {
          _retryCount++;
          _events.add(OperationInProgress('delete_note'));
          await Future.delayed(Duration(milliseconds: 100 * _retryCount));
          continue;
        } else {
          _events.add(OperationFailure('delete_note', e.toString()));
          _isDeleting = false;
          _retryCount = 0;
          return;
        }
      }
    }
  }

  bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') || 
           errorStr.contains('timeout') || 
           errorStr.contains('connection');
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 