import 'dart:async';

import 'package:flutter/material.dart';

/// A debounced search field — [onChanged] fires 300ms after the user stops
/// typing, not on every keystroke, so search queries don't hit the database
/// on each character.
class VaultSearchBar extends StatefulWidget {
  const VaultSearchBar({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<VaultSearchBar> createState() => _VaultSearchBarState();
}

class _VaultSearchBarState extends State<VaultSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.onChanged(value));
    setState(() {}); // refresh the clear button's visibility immediately
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search your documents',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
