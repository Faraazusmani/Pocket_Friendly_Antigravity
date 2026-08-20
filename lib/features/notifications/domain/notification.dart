import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum NotificationStatus { pending, delivered, clicked }

class NotificationEntity {
  final String id;
  final String profileId;
  final String type;
  final DateTime scheduledAt;
  final String? payload;
  final NotificationStatus status;
  final String? relatedEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationEntity({
    required this.id,
    required this.profileId,
    required this.type,
    required this.scheduledAt,
    this.payload,
    required this.status,
    this.relatedEntityId,
    required this.createdAt,
    required this.updatedAt,
  });

  static Result<NotificationEntity, ValidationFailure> create({
    required String id,
    required String profileId,
    required String type,
    required DateTime scheduledAt,
    String? payload,
    required NotificationStatus status,
    String? relatedEntityId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Notification ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (type.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Notification type cannot be empty'),
      );
    }

    return Success(
      NotificationEntity(
        id: id,
        profileId: profileId,
        type: type.trim(),
        scheduledAt: scheduledAt,
        payload: payload,
        status: status,
        relatedEntityId: relatedEntityId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'type': type,
    'scheduledAt': scheduledAt.toIso8601String(),
    'payload': payload,
    'status': status.name,
    'relatedEntityId': relatedEntityId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NotificationEntity.fromJson(Map<String, dynamic> json) =>
      NotificationEntity(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        type: json['type'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        payload: json['payload'] as String?,
        status: NotificationStatus.values.byName(json['status'] as String),
        relatedEntityId: json['relatedEntityId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
