import '../../domain/entities/user.dart';
import '../config/api_config.dart';

/// Model class for User data from API
class UserModel {
  final String id;
  final String username;
  final String? userSecret;
  final String? accessToken;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    this.userSecret,
    this.accessToken,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create model from API JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json[ApiConfig.keys.user.id] as String,
      username: json[ApiConfig.keys.auth.username] as String,
      userSecret: json[ApiConfig.keys.auth.userSecret] as String?,
      accessToken: json[ApiConfig.keys.auth.accessToken] as String?,
      createdAt: DateTime.parse(json[ApiConfig.keys.user.createdAt] as String),
      updatedAt: json[ApiConfig.keys.user.updatedAt] != null
          ? DateTime.parse(json[ApiConfig.keys.user.updatedAt] as String)
          : null,
    );
  }

  /// Convert model to JSON for API
  Map<String, dynamic> toJson() {
    return {
      ApiConfig.keys.user.id: id,
      ApiConfig.keys.auth.username: username,
      ApiConfig.keys.auth.userSecret: userSecret,
      ApiConfig.keys.auth.accessToken: accessToken,
      ApiConfig.keys.user.createdAt: createdAt.toIso8601String(),
      ApiConfig.keys.user.updatedAt: updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  User toDomain() {
    return User(
      id: id,
      username: username,
      userSecret: userSecret,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
