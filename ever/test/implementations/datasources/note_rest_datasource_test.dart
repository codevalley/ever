import 'dart:convert';

import 'package:ever/domain/entities/note.dart';
import 'package:ever/implementations/datasources/note_rest_datasource.dart';
import 'package:ever/implementations/models/note_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'note_rest_datasource_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('NoteRestDataSource', () {
    late MockClient mockClient;
    late NoteRestDataSource dataSource;
    const baseUrl = 'https://api.example.com';

    setUp(() {
      mockClient = MockClient();
      dataSource = NoteRestDataSource(
        client: mockClient,
        baseUrl: baseUrl,
      );
    });

    group('createNote', () {
      test('returns NoteModel on successful creation', () async {
        final note = NoteModel.forCreation(
          title: 'Test Note',
          content: 'Test Content',
          userId: 'user123',
        );

        final responseJson = {
          'id': 'note123',
          'title': 'Test Note',
          'content': 'Test Content',
          'user_id': 'user123',
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-01T00:00:00.000Z',
          'attachments': [],
          'processing_status': 'notProcessed',
          'enrichment_data': {},
        };

        when(mockClient.post(
          Uri.parse('$baseUrl/notes'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
              jsonEncode(responseJson),
              201,
            ));

        final result = await dataSource.createNote(note);

        expect(result.id, equals('note123'));
        expect(result.title, equals('Test Note'));
        expect(result.content, equals('Test Content'));
        expect(result.userId, equals('user123'));
      });

      test('throws exception on non-201 response', () async {
        final note = NoteModel.forCreation(
          title: 'Test Note',
          content: 'Test Content',
          userId: 'user123',
        );

        when(mockClient.post(
          Uri.parse('$baseUrl/notes'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
              'Error creating note',
              400,
            ));

        expect(
          () => dataSource.createNote(note),
          throwsException,
        );
      });
    });

    group('updateNote', () {
      test('returns NoteModel on successful update', () async {
        final note = NoteModel(
          id: 'note123',
          title: 'Updated Note',
          content: 'Updated Content',
          userId: 'user123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          attachments: [],
          processingStatus: ProcessingStatus.notProcessed,
          enrichmentData: {},
        );

        final responseJson = {
          'id': note.id,
          'title': note.title,
          'content': note.content,
          'user_id': note.userId,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
          'attachments': [],
          'processing_status': 'notProcessed',
          'enrichment_data': {},
        };

        when(mockClient.put(
          Uri.parse('$baseUrl/notes/${note.id}'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
              jsonEncode(responseJson),
              200,
            ));

        final result = await dataSource.updateNote(note);

        expect(result.id, equals(note.id));
        expect(result.title, equals(note.title));
        expect(result.content, equals(note.content));
      });

      test('throws exception on non-200 response', () async {
        final note = NoteModel(
          id: 'note123',
          title: 'Updated Note',
          content: 'Updated Content',
          userId: 'user123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          attachments: [],
          processingStatus: ProcessingStatus.notProcessed,
          enrichmentData: {},
        );

        when(mockClient.put(
          Uri.parse('$baseUrl/notes/${note.id}'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
              'Error updating note',
              400,
            ));

        expect(
          () => dataSource.updateNote(note),
          throwsException,
        );
      });
    });

    group('deleteNote', () {
      test('completes successfully on 204 response', () async {
        const noteId = 'note123';

        when(mockClient.delete(
          Uri.parse('$baseUrl/notes/$noteId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response('', 204));

        await expectLater(
          dataSource.deleteNote(noteId),
          completes,
        );
      });

      test('throws exception on non-204 response', () async {
        const noteId = 'note123';

        when(mockClient.delete(
          Uri.parse('$baseUrl/notes/$noteId'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
              'Error deleting note',
              400,
            ));

        expect(
          () => dataSource.deleteNote(noteId),
          throwsException,
        );
      });
    });

    group('listNotes', () {
      test('returns list of NoteModel on successful fetch', () async {
        final responseJson = {
          'items': [
            {
              'id': 'note123',
              'title': 'Test Note 1',
              'content': 'Test Content 1',
              'user_id': 'user123',
              'created_at': '2024-01-01T00:00:00.000Z',
              'updated_at': '2024-01-01T00:00:00.000Z',
              'attachments': [],
              'processing_status': 'notProcessed',
              'enrichment_data': {},
            },
            {
              'id': 'note456',
              'title': 'Test Note 2',
              'content': 'Test Content 2',
              'user_id': 'user123',
              'created_at': '2024-01-01T00:00:00.000Z',
              'updated_at': '2024-01-01T00:00:00.000Z',
              'attachments': [],
              'processing_status': 'notProcessed',
              'enrichment_data': {},
            },
          ],
        };

        when(mockClient.get(
          Uri.parse('$baseUrl/notes'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
              jsonEncode(responseJson),
              200,
            ));

        final result = await dataSource.listNotes();

        expect(result, hasLength(2));
        expect(result[0].id, equals('note123'));
        expect(result[1].id, equals('note456'));
      });

      test('returns empty list on successful fetch with no items', () async {
        final responseJson = {
          'items': [],
        };

        when(mockClient.get(
          Uri.parse('$baseUrl/notes'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
              jsonEncode(responseJson),
              200,
            ));

        final result = await dataSource.listNotes();

        expect(result, isEmpty);
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get(
          Uri.parse('$baseUrl/notes'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
              'Error fetching notes',
              400,
            ));

        expect(
          () => dataSource.listNotes(),
          throwsException,
        );
      });
    });
  });
} 