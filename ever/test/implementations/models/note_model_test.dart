import 'package:ever/domain/entities/note.dart';
import 'package:ever/implementations/models/note_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteModel', () {
    test('fromJson creates valid model', () {
      final json = {
        'id': 123,
        'title': 'Test Note',
        'content': 'Test Content',
        'user_id': 'user123',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'attachments': [
          {
            'type': 'image/jpeg',
            'url': 'https://example.com/image.jpg',
          }
        ],
        'processing_status': 'pending',
        'enrichment_data': {'key': 'value'},
      };

      final model = NoteModel.fromJson(json);

      expect(model.id, equals(123));

      expect(model.content, equals('Test Content'));
      expect(model.userId, equals('user123'));
      expect(model.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
      expect(model.updatedAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
      expect(model.attachments, hasLength(1));
      expect(model.attachments.first.type, equals('image/jpeg'));
      expect(model.attachments.first.url, equals('https://example.com/image.jpg'));
      expect(model.processingStatus, equals(ProcessingStatus.pending));
      expect(model.enrichmentData, equals({'key': 'value'}));
    });

    test('toJson creates valid json', () {
      final model = NoteModel(
        id: 123,

        content: 'Test Content',
        userId: 'user123',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        attachments: [
          AttachmentModel(
            type: 'image/jpeg',
            url: 'https://example.com/image.jpg',
          ),
        ],
        processingStatus: ProcessingStatus.pending,
        enrichmentData: {'key': 'value'},
      );

      final json = model.toJson();

      expect(json['id'], equals(123));

      expect(json['content'], equals('Test Content'));
      expect(json['user_id'], equals('user123'));
      expect(json['created_at'], equals('2024-01-01T00:00:00.000Z'));
      expect(json['updated_at'], equals('2024-01-01T00:00:00.000Z'));
      expect(json['attachments'], hasLength(1));
      expect(json['attachments'][0], equals({
        'type': 'image/jpeg',
        'url': 'https://example.com/image.jpg',
      }));
      expect(json['processing_status'], equals('pending'));
      expect(json['enrichment_data'], equals({'key': 'value'}));
    });

    test('toDomain creates valid entity', () {
      final model = NoteModel(
        id: 123,

        content: 'Test Content',
        userId: 'user123',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        attachments: [
          AttachmentModel(
            type: 'image/jpeg',
            url: 'https://example.com/image.jpg',
          ),
        ],
        processingStatus: ProcessingStatus.pending,
        enrichmentData: {'key': 'value'},
      );

      final entity = model.toDomain();

      expect(entity, isA<Note>());
      expect(entity.id, equals('123'));

      expect(entity.content, equals('Test Content'));
      expect(entity.userId, equals('user123'));
      expect(entity.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
      expect(entity.updatedAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
    });

    test('forCreation creates valid model', () {
      final model = NoteModel.forCreation(

        content: 'Test Content',
        userId: 'user123',
      );

      expect(model.id, equals(0));

      expect(model.content, equals('Test Content'));
      expect(model.userId, equals('user123'));
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
      expect(model.attachments, isEmpty);
      expect(model.processingStatus, equals(ProcessingStatus.pending));
      expect(model.enrichmentData, isNull);
    });
  });

  group('AttachmentModel', () {
    test('fromJson creates valid model', () {
      final json = {
        'type': 'image/jpeg',
        'url': 'https://example.com/image.jpg',
      };

      final model = AttachmentModel.fromJson(json);

      expect(model.type, equals('image/jpeg'));
      expect(model.url, equals('https://example.com/image.jpg'));
    });

    test('toJson creates valid json', () {
      final model = AttachmentModel(
        type: 'image/jpeg',
        url: 'https://example.com/image.jpg',
      );

      final json = model.toJson();

      expect(json, equals({
        'type': 'image/jpeg',
        'url': 'https://example.com/image.jpg',
      }));
    });

    test('toDomain creates valid entity', () {
      final model = AttachmentModel(
        type: 'image/jpeg',
        url: 'https://example.com/image.jpg',
      );

      final entity = model.toDomain();

      expect(entity, isA<Attachment>());
      expect(entity.type, equals('image/jpeg'));
      expect(entity.url, equals('https://example.com/image.jpg'));
    });
  });
} 