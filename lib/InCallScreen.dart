import 'package:flutter/material.dart';

class InCallScreen extends StatelessWidget {
  final String callerUid;
  final String currentUserUid;

  const InCallScreen({
    Key? key,
    required this.callerUid,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('In Call with $callerUid'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Call in progress...'),
            ElevatedButton(
              onPressed: () {
                _endCall();
                Navigator.pop(context);
              },
              child: Text('End Call'),
            ),
          ],
        ),
      ),
    );
  }

  void _endCall() {
    // End the voice call using ZEGOCLOUD
    // Example: ZegoExpressEngine.instance.endCall();
  }
}