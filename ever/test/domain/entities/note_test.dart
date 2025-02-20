import 'package:ever/domain/entities/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Note Entity', () {
    test('equality', () {
      final now = DateTime.now();
      final note1 = Note(
        id: 'note123',
        content: 'Test Content',
        userId: 'user123',
        createdAt: now,
        updatedAt: now,
        processingStatus: ProcessingStatus.pending,
      );

      final note2 = Note(
        id: 'note123',
        content: 'Test Content',
        userId: 'user123',
        createdAt: now,
        updatedAt: now,
        processingStatus: ProcessingStatus.pending,
      );

      final differentNote = Note(
        id: 'note456',
        content: 'Different Content',
        userId: 'user123',
        createdAt: now,
        updatedAt: now,
        processingStatus: ProcessingStatus.pending,
      );

      expect(note1, equals(note2));
      expect(note1.hashCode, equals(note2.hashCode));
      expect(note1, isNot(equals(differentNote)));
      expect(note1.hashCode, isNot(equals(differentNote.hashCode)));
    });

    test('different timestamps affect equality', () {
      final note1 = Note(
        id: 'note123',
        content: 'Test Content',
        userId: 'user123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        processingStatus: ProcessingStatus.pending,
      );

      final note2 = Note(
        id: 'note123',
        content: 'Test Content',
        userId: 'user123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2), // Different update time
        processingStatus: ProcessingStatus.pending,
      );

      expect(note1, isNot(equals(note2)));
      expect(note1.hashCode, isNot(equals(note2.hashCode)));
    });
  });

  group('Attachment Entity', () {
    test('equality', () {
      final attachment1 = Attachment(
        type: 'image/jpeg',
        url: 'https://example.com/image1.jpg',
      );

      final attachment2 = Attachment(
        type: 'image/jpeg',
        url: 'https://example.com/image1.jpg',
      );

      final differentAttachment = Attachment(
        type: 'image/png',
        url: 'https://example.com/image2.png',
      );

      expect(attachment1, equals(attachment2));
      expect(attachment1.hashCode, equals(attachment2.hashCode));
      expect(attachment1, isNot(equals(differentAttachment)));
      expect(attachment1.hashCode, isNot(equals(differentAttachment.hashCode)));
    });
  });

  group('ProcessingStatus', () {
    test('enum values', () {
      expect(ProcessingStatus.values, hasLength(3));
      expect(ProcessingStatus.values, contains(ProcessingStatus.pending));
      expect(ProcessingStatus.values, contains(ProcessingStatus.completed));
      expect(ProcessingStatus.values, contains(ProcessingStatus.failed));
    });
  });
} 