import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/note_model.dart';

/// REST implementation of the note data source
class NoteRestDataSource {
  final http.Client client;
  final String baseUrl;

  NoteRestDataSource({
    required this.client,
    required this.baseUrl,
  });

  Future<NoteModel> createNote(NoteModel note) async {
    final response = await client.post(
      Uri.parse('$baseUrl/notes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(note.toJson()),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return NoteModel.fromJson(data);
    } else {
      throw Exception('Failed to create note');
    }
  }

  Future<NoteModel> updateNote(NoteModel note) async {
    final response = await client.put(
      Uri.parse('$baseUrl/notes/${note.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(note.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return NoteModel.fromJson(data);
    } else {
      throw Exception('Failed to update note');
    }
  }

  Future<void> deleteNote(String id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/notes/$id'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete note');
    }
  }

  Future<List<NoteModel>> listNotes() async {
    final response = await client.get(
      Uri.parse('$baseUrl/notes'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List;
      return items.map((item) => NoteModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to list notes');
    }
  }
} 