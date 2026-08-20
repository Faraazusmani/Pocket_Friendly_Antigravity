import 'package:equatable/equatable.dart';
import '../../../transactions/domain/services/insights_service.dart';

abstract class InsightsState extends Equatable {
  const InsightsState();

  @override
  List<Object?> get props => [];
}

class InsightsInitial extends InsightsState {
  const InsightsInitial();
}

class InsightsLoading extends InsightsState {
  const InsightsLoading();
}

class InsightsLoaded extends InsightsState {
  final InsightData data;
  final DateTime selectedMonth;
  final bool privacyModeEnabled;
  final String defaultCurrency;

  const InsightsLoaded({
    required this.data,
    required this.selectedMonth,
    required this.privacyModeEnabled,
    required this.defaultCurrency,
  });

  @override
  List<Object?> get props => [
    data,
    selectedMonth,
    privacyModeEnabled,
    defaultCurrency,
  ];
}

class InsightsError extends InsightsState {
  final String message;

  const InsightsError(this.message);

  @override
  List<Object?> get props => [message];
}
