import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;
  const CallScreen({
    super.key,
    required this.callerId,
    required this.calleeId,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
