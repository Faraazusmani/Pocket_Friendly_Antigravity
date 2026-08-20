import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {
  const LoadDashboard();
}

class ChangeMonth extends DashboardEvent {
  final DateTime month;

  const ChangeMonth(this.month);

  @override
  List<Object?> get props => [month];
}

class TogglePrivacyMode extends DashboardEvent {
  const TogglePrivacyMode();
}

class ChangeCurrency extends DashboardEvent {
  final String currency;

  const ChangeCurrency(this.currency);

  @override
  List<Object?> get props => [currency];
}
