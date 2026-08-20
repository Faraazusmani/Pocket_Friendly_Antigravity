import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

class Tag {
  final String id;
  final String profileId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Tag({
    required this.id,
    required this.profileId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Factory method to enforce "Always Valid" Tag instantiation.
  static Result<Tag, ValidationFailure> create({
    required String id,
    required String profileId,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(ValidationFailure('Tag ID cannot be empty'));
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (name.trim().isEmpty) {
      return const FailureResult(ValidationFailure('Tag name cannot be empty'));
    }

    return Success(
      Tag(
        id: id,
        profileId: profileId,
        name: name.trim(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
  );
}
