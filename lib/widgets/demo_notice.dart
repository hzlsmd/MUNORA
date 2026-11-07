import 'package:flutter/material.dart';

class DemoNotice extends StatelessWidget {
  final String message;
  final Widget child;
  const DemoNotice({super.key, required this.message, required this.child});

  @override
  Widget build(BuildContext context) => Column(children: [
        SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.all(12),
              child: Text(message, style: const TextStyle(fontSize: 12)),
            )),
        Expanded(child: child),
      ]);
}
