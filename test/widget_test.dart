import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultly/main.dart';
import 'package:vaultly/models/document.dart';
import 'package:vaultly/providers/vault_providers.dart';

class _EmptyDocumentsNotifier extends DocumentsNotifier {
  @override
  Future<List<Document>> build() async => [];
}

void main() {
  testWidgets('Home screen shows the empty vault state and a capture entry point', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentsProvider.overrideWith(_EmptyDocumentsNotifier.new)],
        child: const VaultlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaultly'), findsOneWidget);
    expect(find.text('Your vault is empty'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Scan document'), findsOneWidget);
  });
}
