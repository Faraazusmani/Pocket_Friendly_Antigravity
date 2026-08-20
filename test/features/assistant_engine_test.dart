import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/features/insights/domain/services/assistant_engine.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';

void main() {
  test('AssistantEngine.parse correctly maps queries and actions', () {
    // 1. Action intents (expense/income commands)
    final act1 = AssistantEngine.parse('Add 500 income from Freelancing');
    expect(act1, isA<ActionIntent>());
    final a1 = act1 as ActionIntent;
    expect(a1.type, TransactionType.income);
    expect(a1.amountMinor, 50000);
    expect(a1.categoryName, 'Freelancing');

    final act2 = AssistantEngine.parse('Spent 250 on dining out');
    expect(act2, isA<ActionIntent>());
    final a2 = act2 as ActionIntent;
    expect(a2.type, TransactionType.expense);
    expect(a2.amountMinor, 25000);
    expect(a2.categoryName, 'Dining out');

    // 2. Query intents (questions about spending)
    final q1 = AssistantEngine.parse(
      'How much did I spend on food last month?',
    );
    expect(q1, isA<QueryIntent>());
    final query1 = q1 as QueryIntent;
    expect(query1.concept, 'spending');
    expect(query1.timeframe, 'last_month');
    expect(query1.categoryName, 'food');

    final q2 = AssistantEngine.parse('What is my savings rate this month?');
    expect(q2, isA<QueryIntent>());
    final query2 = q2 as QueryIntent;
    expect(query2.concept, 'savings_rate');
    expect(query2.timeframe, 'current_month');
  });
}
