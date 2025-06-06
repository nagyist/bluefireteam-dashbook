import 'package:dashbook/dashbook.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumberProperty extends StatefulWidget {
  final Property<double> property;
  final PropertyChanged onChanged;

  const NumberProperty({
    required this.property,
    required this.onChanged,
    super.key,
  });

  @override
  State<StatefulWidget> createState() =>
      NumberPropertyState(property.getValue());
}

class NumberPropertyState extends State<NumberProperty> {
  TextEditingController controller = TextEditingController();

  NumberPropertyState(double value) {
    controller.text = value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return PropertyScaffold(
      tooltipMessage: widget.property.tooltipMessage,
      label: widget.property.name,
      child: TextField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          widget.property.value = double.tryParse(value);
          widget.onChanged();
        },
        controller: controller,
      ),
    );
  }
}
