import 'package:flutter/material.dart';

/// A tag pill. Pass [onDeleted] for an editable/removable chip (document
/// detail screen); pass [onTap] with [selected] for a filter chip (home
/// screen tag row).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (onDeleted != null) {
      return InputChip(label: Text(label), onDeleted: onDeleted);
    }
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
    );
  }
}
