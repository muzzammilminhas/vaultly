import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultly/main.dart';

void main() {
  testWidgets('Home screen shows the empty vault state and a capture entry point', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VaultlyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Vaultly'), findsOneWidget);
    expect(find.text('Your vault is empty'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Scan document'), findsOneWidget);
  });
}
