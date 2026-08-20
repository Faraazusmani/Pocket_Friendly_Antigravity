import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import 'account.dart';

enum PaymentModeStatus { active, archived }

class PaymentMode {
  final String id;
  final String profileId;
  final String name;
  final List<AccountType> applicableAccountTypes;
  final bool isDefault;
  final bool isSystem;
  final PaymentModeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const PaymentMode({
    required this.id,
    required this.profileId,
    required this.name,
    required this.applicableAccountTypes,
    required this.isDefault,
    required this.isSystem,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Factory method to enforce "Always Valid" PaymentMode values.
  static Result<PaymentMode, ValidationFailure> create({
    required String id,
    required String profileId,
    required String name,
    required List<AccountType> applicableAccountTypes,
    required bool isDefault,
    required bool isSystem,
    required PaymentModeStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('PaymentMode ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (name.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('PaymentMode name cannot be empty'),
      );
    }
    if (applicableAccountTypes.isEmpty) {
      return const FailureResult(
        ValidationFailure('PaymentMode must support at least one account type'),
      );
    }

    return Success(
      PaymentMode(
        id: id,
        profileId: profileId,
        name: name.trim(),
        applicableAccountTypes: List.unmodifiable(applicableAccountTypes),
        isDefault: isDefault,
        isSystem: isSystem,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      ),
    );
  }

  /// Verifies if this payment mode is compatible with a given account type.
  bool isCompatibleWith(AccountType accountType) {
    return applicableAccountTypes.contains(accountType);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'applicableAccountTypes': applicableAccountTypes
        .map((e) => e.name)
        .toList(),
    'isDefault': isDefault,
    'isSystem': isSystem,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory PaymentMode.fromJson(Map<String, dynamic> json) => PaymentMode(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    name: json['name'] as String,
    applicableAccountTypes: (json['applicableAccountTypes'] as List<dynamic>)
        .map((e) => AccountType.values.byName(e as String))
        .toList(),
    isDefault: json['isDefault'] as bool,
    isSystem: json['isSystem'] as bool,
    status: PaymentModeStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
  );
}
