import 'package:equatable/equatable.dart';

abstract class InsightsEvent extends Equatable {
  const InsightsEvent();

  @override
  List<Object?> get props => [];
}

class LoadInsights extends InsightsEvent {
  final DateTime monthYear;

  const LoadInsights(this.monthYear);

  @override
  List<Object?> get props => [monthYear];
}
