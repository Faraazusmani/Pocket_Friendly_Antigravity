import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

class Profile {
  final String id;
  final String name;
  final String defaultCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory method to enforce "Always Valid" Profile instantiation.
  static Result<Profile, ValidationFailure> create({
    required String id,
    required String name,
    required String defaultCurrency,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (name.trim().length < 2) {
      return const FailureResult(
        ValidationFailure('Profile name must be at least 2 characters long'),
      );
    }
    if (defaultCurrency.trim().length != 3) {
      return const FailureResult(
        ValidationFailure('Default currency must be a 3-letter ISO code'),
      );
    }

    return Success(
      Profile(
        id: id,
        name: name.trim(),
        defaultCurrency: defaultCurrency.trim().toUpperCase(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultCurrency': defaultCurrency,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    defaultCurrency: json['defaultCurrency'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
