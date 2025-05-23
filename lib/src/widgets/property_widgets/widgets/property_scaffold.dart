import 'package:dashbook/src/widgets/property_widgets/widgets/title_with_tooltip.dart';
import 'package:flutter/material.dart';

/// Signature for a callback function that is called to tell properties that
/// they have updated values.
///
/// Used a lot like [ChangeNotifier.notifyListeners].
typedef PropertyChanged = void Function();

class PropertyScaffold extends StatelessWidget {
  final String label;
  final Widget child;
  final String? tooltipMessage;

  const PropertyScaffold({
    required this.label,
    required this.child,
    super.key,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: tooltipMessage != null
                ? TitleWithTooltip(
                    label: label,
                    tooltipMessage: tooltipMessage!,
                  )
                : Text(label),
          ),
          Expanded(flex: 6, child: child),
        ],
      ),
    );
  }
}
