import 'package:flutter/material.dart';
import 'package:webapp/colors.dart';

class Preset {
  final IconData? icon;
  final String label;
  final String model;

  const Preset(
    this.label,
    this.model, {
    this.icon,
  });
}

typedef OnSelected = Function(Preset?);

class Presets extends StatefulWidget {
  final List<Preset> presets;
  final String? model;
  final OnSelected onSelected;

  const Presets({
    required this.presets,
    required this.model,
    required this.onSelected,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _PresetsState();
}

class _PresetsState extends State<Presets> {
  int selectedIdx = -1;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: widget.presets.map(
        (preset) {
          final matching = preset.model == widget.model;
          return ChoiceChip(
            avatar: preset.icon != null
                ? Icon(
                    preset.icon,
                    size: 16,
                    color: matching ? Colors.white : Colors.black,
                  )
                : null,
            label: Text(preset.label),
            labelPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
            labelStyle: TextStyle(
              color: matching ? Colors.white : Colors.black,
              fontSize: 12,
            ),
            visualDensity: VisualDensity.compact,
            selected: matching,
            selectedColor: uniBlue,
            onSelected: (_) {
              setState(() {
                widget.onSelected(preset);
              });
            },
          );
        },
      ).toList(),
    );
  }
}
