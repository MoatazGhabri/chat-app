import 'package:new_app/VideoPlayerWidget.dart';
import 'package:flutter/material.dart';

class MessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final BorderRadius borderRadius;
  final String timestamp;
  final bool showNew;
  final VoidCallback onReply;

  const MessageWidget({
    required this.message,
    required this.isCurrentUser,
    required this.borderRadius,
    required this.timestamp,
    required this.showNew,
    required this.onReply,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onReply,
            child: Container(
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue : Colors.grey[300],
                borderRadius: borderRadius,
              ),
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.containsKey('replyTo'))
                    _buildReplyMessage(message['replyTo']),
                  Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black,
                    ),
                  ),
                  if (message.containsKey('imageUrl'))
                    Image.network(
                      message['imageUrl'],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  if (message.containsKey('videoUrl'))
                    VideoPlayerWidget(videoUrl: message['videoUrl']),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timestamp,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              if (showNew)
                Icon(
                  Icons.fiber_new,
                  size: 12,
                  color: Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyMessage(Map<String, dynamic> replyTo) {
    return Container(
      margin: EdgeInsets.only(bottom: 5),
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue[200] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo['message'] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: isCurrentUser ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
