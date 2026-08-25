import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/app_lock_gate.dart';
import 'screens/home_vault_screen.dart';

void main() {
  runApp(const ProviderScope(child: VaultlyApp()));
}

class VaultlyApp extends StatelessWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E5D4B); // deep vault green — reasonable default palette choice
    return MaterialApp(
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: const AppLockGate(child: HomeVaultScreen()),
    );
  }
}
