import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultly/models/document.dart';
import 'package:vaultly/providers/vault_providers.dart';
import 'package:vaultly/screens/home_vault_screen.dart';

class _EmptyDocumentsNotifier extends DocumentsNotifier {
  @override
  Future<List<Document>> build() async => [];
}

void main() {
  // Tests HomeVaultScreen directly rather than through VaultlyApp, since the
  // full app shell now starts behind AppLockGate (PIN/biometric setup),
  // which needs real secure-storage/local_auth platform channels this test
  // environment doesn't have. The lock gate itself isn't unit-testable
  // without those channels, so it's covered by on-device verification.
  testWidgets('Home screen shows the empty vault state and a capture entry point', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentsProvider.overrideWith(_EmptyDocumentsNotifier.new)],
        child: const MaterialApp(home: HomeVaultScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaultly'), findsOneWidget);
    expect(find.text('Your vault is empty'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Scan document'), findsOneWidget);
  });
}
