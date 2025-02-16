import 'package:flutter_test/flutter_test.dart';
import 'package:ever/domain/entities/user.dart';

void main() {
  group('User Entity', () {
    test('should create valid user with all fields', () {
      final user = User(
        id: '123',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.userSecret, 'secret123');
      expect(user.createdAt, DateTime(2024, 1, 1));
      expect(user.updatedAt, DateTime(2024, 1, 1));
    });

    test('should create valid user with minimal fields', () {
      final user = User(
        id: '123',
        username: 'testuser',
      );

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.userSecret, isNull);
      expect(user.createdAt, isNull);
      expect(user.updatedAt, isNull);
    });

    test('should handle empty strings', () {
      final user = User(
        id: '',
        username: '',
      );

      expect(user.id, isEmpty);
      expect(user.username, isEmpty);
    });

    test('should implement value equality', () {
      final user1 = User(
        id: '123',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user2 = User(
        id: '123',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user3 = User(
        id: '456',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
      expect(user1.hashCode, equals(user2.hashCode));
      expect(user1.hashCode, isNot(equals(user3.hashCode)));
    });

    test('should copy with new values', () {
      final user = User(
        id: '123',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updatedUser = user.copyWith(
        username: 'newuser',
        userSecret: 'newsecret',
      );

      expect(updatedUser.id, user.id);
      expect(updatedUser.username, 'newuser');
      expect(updatedUser.userSecret, 'newsecret');
      expect(updatedUser.createdAt, user.createdAt);
      expect(updatedUser.updatedAt, user.updatedAt);
    });

    test('should copy without changing values when not specified', () {
      final user = User(
        id: '123',
        username: 'testuser',
        userSecret: 'secret123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final copiedUser = user.copyWith();

      expect(copiedUser, equals(user));
      expect(copiedUser.hashCode, equals(user.hashCode));
    });
  });
}
