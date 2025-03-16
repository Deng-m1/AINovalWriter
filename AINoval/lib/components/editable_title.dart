import 'package:flutter/material.dart';
import 'dart:async';

class Debouncer {
  Timer? _timer;
  final Duration delay;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class EditableTitle extends StatefulWidget {
  final String initialText;
  final Function(String) onChanged;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;

  const EditableTitle({
    Key? key,
    required this.initialText,
    required this.onChanged,
    this.style,
    this.textAlign = TextAlign.left,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<EditableTitle> {
  late TextEditingController _controller;
  late Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _debouncer = Debouncer();
  }

  @override
  void didUpdateWidget(EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: widget.style,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      textAlign: widget.textAlign,
      autofocus: widget.autofocus,
      onChanged: (value) {
        _debouncer.run(() {
          widget.onChanged(value);
        });
      },
    );
  }
}