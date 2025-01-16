import 'package:flutter/material.dart';

class ReplyMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancelReply;
  final String senderName;

  const ReplyMessageWidget({
    required this.message,
    required this.senderName,
    required this.onCancelReply,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      children: [
        Container(
          color: Colors.green,
          width: 6,
        ),
        const SizedBox(width: 8),
        Expanded(child: buildReplyMessage()),
      ],
    ),
  );

  Widget buildReplyMessage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${'reply to ' + senderName ?? 'User'}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            child: Icon(Icons.cancel, size: 20, color: Colors.red,),
            onTap: onCancelReply,
          )
        ],
      ),
      const SizedBox(height: 8),
      Text(
        message['message'] ?? '',
        style: TextStyle(color: Colors.black54),
      ),
    ],
  );
}
