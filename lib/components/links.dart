import 'package:flutter/material.dart';

class Link {
  final IconData? icon;
  final String label;
  final String url;
  final String? tooltip;

  const Link(this.label, this.url, {this.icon, this.tooltip});
}

class LinkChip extends StatelessWidget {
  final Link link;
  final VoidCallback onPressed;

  const LinkChip(this.link, this.onPressed, {super.key});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: link.icon != null
          ? Icon(
              link.icon,
              size: 16,
            )
          : null,
      labelPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
      visualDensity: VisualDensity.compact,
      label: Text(
        link.label,
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
      tooltip: link.tooltip ?? link.url,
      onPressed: onPressed,
    );
  }
}
