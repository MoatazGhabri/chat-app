import 'package:agora_uikit/agora_uikit.dart';
import 'package:new_app/WebRtcManager.dart';
import 'package:new_app/WebViewScreen.dart';
import 'package:new_app/call_invitation.dart';
import 'package:new_app/replay.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'enums.dart';
import 'user.dart';
import 'CallAcceptDeclinePage.dart';


class ConversationScreen extends StatefulWidget {
  final String currentUserUid;
  final String otherUserUid;
  final String otherUserName;
  final String otherUserProfileImage;

  const ConversationScreen({
    Key? key,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherUserName,
    required this.otherUserProfileImage,
  }) : super(key: key);

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref().child('conversations');
  DatabaseReference _databaseRef = FirebaseDatabase.instance.reference();
  final ScrollController _scrollController = ScrollController();
  String _conversationId = '';
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  int? _selectedMessageIndex;
  int _lastSeenMessageIndex = -1;
  final Record _record = Record();
  bool _isRecording = false;
  String? _recordedFilePath;
  Map<String, dynamic>? _replyMessage;
  Map<String, GlobalKey> _messageKeys = {};
  int? _animatedMessageIndex;
  AnimationController? _animatedMessageController;
  Animation<double>? _animation;
  late AnimationController _animationController;
  @override
  void initState() {
    super.initState();
    _conversationId =
        _generateConversationId(widget.currentUserUid, widget.otherUserUid);
    _listenForMessages();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _startAudioCall() async {
    Users otherUser = Users(
      uid: widget.otherUserUid,
      name: widget.otherUserName,
      picture: widget.otherUserProfileImage,
    );

    // Send push notification to the other user
    DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users').child(widget.otherUserUid);
    userRef.child('fcmToken').once().then((DatabaseEvent event) async {
      String? fcmToken = event.snapshot.value as String?;

      if (fcmToken != null) {
        await _sendCallNotification(fcmToken, widget.currentUserUid, widget.otherUserUid);
      }
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallAcceptDeclinePage(
          user: otherUser,
          callStatus: DuringCallStatus.calling,
          roomId: null,
        ),
      ),
    );
  }
  String _generateConversationId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return uids.join('_');
  }


  void _listenForMessages() {
    _messagesRef
        .child(_conversationId)
        .onValue
        .listen((event) {
      print('Event received: ${event.snapshot.value}');
      DataSnapshot snapshot = event.snapshot;
      if (snapshot.exists) {
        Map<dynamic, dynamic> messagesMap = snapshot.value as Map<
            dynamic,
            dynamic>;
        print('Messages Map: $messagesMap');

        List<Map<String, dynamic>> messagesList = [];
        messagesMap.forEach((key, value) {
          var message = Map<String, dynamic>.from(value);
          message['key'] = key; // Include the key in each message
          messagesList.add(message);
        });

        messagesList.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        print('Sorted Messages List: $messagesList');

        setState(() {
          _messages = messagesList;
          _isLoading = false;
          _lastSeenMessageIndex = _getLastSeenMessageIndex();
        });

        _markMessagesAsSeen();
        _scrollToBottom();

      } else {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
        print('No messages found');
      }
    }).onError((error) {
      print('Error fetching messages: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _markMessagesAsSeen() {
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i]['senderUid'] == widget.otherUserUid &&
          _messages[i]['seen'] == false) {
        print('Marking message as seen: ${_messages[i]['key']}');
        _messagesRef.child('$_conversationId/${_messages[i]['key']}').update(
            {'seen': true}).then((_) {
          print('Message marked as seen: ${_messages[i]['key']}');
        }).catchError((error) {
          print('Error updating seen field: $error');
        });
      }
    }
  }
  void _scrollToMessage(int index) {
    if (_scrollController.hasClients) {
      final offset = index * 70.0; // Adjust this value if necessary
      _scrollController.animateTo(
        offset,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Trigger the bounce animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateMessage(index);
      });
    }
  }

  void _animateMessage(int index) {
    if (_animatedMessageController != null) {
      _animatedMessageController!.dispose();
    }

    _animatedMessageController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animatedMessageController!,
        curve: Curves.bounceInOut,
      ),
    );

    _animatedMessageIndex = index;
    _animatedMessageController!.forward().then((_) {
      setState(() {
        _animatedMessageIndex = null;
      });
    });
  }

  int _getLastSeenMessageIndex() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['senderUid'] == widget.currentUserUid &&
          _messages[i]['seen'] == true) {
        return i;
      }
    }
    return -1;
  }

  void _sendMessage() {
    String message = _messageController.text;
    if (message.isNotEmpty) {
      DatabaseReference newMessageRef = _messagesRef.child(_conversationId)
          .push();
      newMessageRef.set({
        'senderUid': widget.currentUserUid,
        'receiverUid': widget.otherUserUid,
        'message': message,
        'timestamp': DateTime
            .now()
            .millisecondsSinceEpoch,
        'seen': false,
        'replyTo': _replyMessage, // Add replyTo field if replying
      }).then((_) {
        _messageController.clear();
        _scrollToBottom();
        setState(() {
          _replyMessage = null; // Clear reply state after sending
        });
        if (_messages.last['seen']== false) {
          _sendNotificationToOtherUser(message);
        }
      }).catchError((error) {
        print('Error sending message: $error');
      });
    }
  }

  Future<void> startStopRecord() async {
    if (_isRecording) {
      await stopRecord();
      setState(() {
        _isRecording = false;
      });
    } else {
      // Check and request permission
      if (await _record.hasPermission()) {
        setState(() {
          _isRecording = true;
        });
        final directory = await getApplicationDocumentsDirectory();
        _recordedFilePath = '${directory.path}/temp_${DateTime
            .now()
            .millisecondsSinceEpoch}.m4a';
        // Start recording
        await _record.start(
          path: _recordedFilePath,
          encoder: AudioEncoder.aacLc, // by default
          bitRate: 128000, // by default
          samplingRate: 44100, // by default
        );
      }
    }
  }

  Future<void> stopRecord() async {
    // Get the state of the recorder
    bool isRecording = await _record.isRecording();
    if (isRecording) {
      await _record.stop();
      if (_recordedFilePath != null) {
        File? fileUploaded = await _uploadMedia(_recordedFilePath!);
        if (fileUploaded != null) {
          _sendVoiceMessage(fileUploaded.path);
        }
      }
    }
  }

  Future<File?> _uploadMedia(String filePath) async {
    final file = File(filePath);
    final storageRef = FirebaseStorage.instance.ref().child(
        'voice_messages/${DateTime
            .now()
            .millisecondsSinceEpoch}.m4a');
    final uploadTask = storageRef.putFile(file);

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return File(downloadUrl);
    } catch (error) {
      print('Error uploading voice message: $error');
      return null;
    }
  }

  void _sendVoiceMessage(String downloadUrl) {
    DatabaseReference newMessageRef = _messagesRef.child(_conversationId)
        .push();
    newMessageRef.set({
      'senderUid': widget.currentUserUid,
      'receiverUid': widget.otherUserUid,
      'message': 'voice message',
      'voiceUrl': downloadUrl,
      'timestamp': DateTime
          .now()
          .millisecondsSinceEpoch,
      'seen': false,
    }).then((_) {
      _scrollToBottom();
    }).catchError((error) {
      print('Error sending voice message: $error');
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  String _formatTimestamp(int timestamp) {
    DateTime now = DateTime.now();
    DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (now
        .difference(messageTime)
        .inDays >= 7) {
      var format = DateFormat('MMM dd, yyyy-hh:mm a');
      return format.format(messageTime);
    } else if (now.day == messageTime.day && now.month == messageTime.month &&
        now.year == messageTime.year) {
      var format = DateFormat('hh:mm a');
      return format.format(messageTime);
    } else {
      var format = DateFormat('EEEE');
      String dayOfWeek = format.format(messageTime);
      return '$dayOfWeek - ${messageTime.day}/${messageTime.month}';
    }
  }

  BorderRadius _getMessageBorderRadius(int index) {
    if (index == 0 ||
        _messages[index - 1]['senderUid'] != _messages[index]['senderUid']) {
      // First message in list or first message of a new sender
      return BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(10),
      );
    } else if (index == _messages.length - 1 ||
        _messages[index + 1]['senderUid'] != _messages[index]['senderUid']) {
      // Last message in list or last message of a sender
      return BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      );
    } else {
      // Middle message of a sender
      return BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(10),
      );
    }
  }

  BorderRadius _getMessageBorderRadiusR(int index) {
    if (index == 0 ||
        _messages[index - 1]['senderUid'] != _messages[index]['senderUid']) {
      // First message in list or first message of a new sender
      return BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(30),
      );
    } else if (index == _messages.length - 1 ||
        _messages[index + 1]['senderUid'] != _messages[index]['senderUid']) {
      // Last message in list or last message of a sender
      return BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(30),
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      );
    } else {
      // Middle message of a sender
      return BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(30),
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(30),
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') ||
          fileName.endsWith('.png') || fileName.endsWith('.gif')) {
        // It's an image
        File? fileUploaded = await _uploadFile(file, fileName);
        if (fileUploaded != null) {
          _sendImageMessage(fileUploaded.path, fileName);
        }
      } else if (fileName.endsWith('.mp4')) {
        File? fileUploaded = await _uploadFile(file, fileName);
        if (fileUploaded != null) {
          _sendVMessage(fileUploaded.path, fileName);
        }
      }
      else {
        // It's a regular file
        File? fileUploaded = await _uploadFile(file, fileName);
        if (fileUploaded != null) {
          _sendFileMessage(fileUploaded.path, fileName);
        }
      }
    }
  }

  Future<File?> _uploadFile(File file, String fileName) async {
    final storageRef = FirebaseStorage.instance.ref().child('files/$fileName');
    final uploadTask = storageRef.putFile(file);

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return File(downloadUrl);
    } catch (error) {
      print('Error uploading file: $error');
      return null;
    }
  }

  void _sendFileMessage(String downloadUrl, String fileName) {
    DatabaseReference newMessageRef = _messagesRef.child(_conversationId)
        .push();
    newMessageRef.set({
      'senderUid': widget.currentUserUid,
      'receiverUid': widget.otherUserUid,
      'message': 'file',
      'fileUrl': downloadUrl,
      'fileName': fileName,
      'timestamp': DateTime
          .now()
          .millisecondsSinceEpoch,
      'seen': false,
    }).then((_) {
      _scrollToBottom();
    }).catchError((error) {
      print('Error sending file message: $error');
    });
  }

  void _sendImageMessage(String downloadUrl, String fileName) {
    DatabaseReference newMessageRef = _messagesRef.child(_conversationId)
        .push();
    newMessageRef.set({
      'senderUid': widget.currentUserUid,
      'receiverUid': widget.otherUserUid,
      'message': 'image',
      'imageUrl': downloadUrl,
      'fileName': fileName,
      'timestamp': DateTime
          .now()
          .millisecondsSinceEpoch,
      'seen': false,
    }).then((_) {
      _scrollToBottom();
      _sendNotificationimageToOtherUser('Send you an image', downloadUrl);
    }).catchError((error) {
      print('Error sending file message: $error');
    });
  }

  void _sendVMessage(String downloadUrl, String fileName) {
    DatabaseReference newMessageRef = _messagesRef.child(_conversationId)
        .push();
    newMessageRef.set({
      'senderUid': widget.currentUserUid,
      'receiverUid': widget.otherUserUid,
      'message': 'video',
      'videoUrl': downloadUrl,
      'fileName': fileName,
      'timestamp': DateTime
          .now()
          .millisecondsSinceEpoch,
      'seen': false,
    }).then((_) {
      _scrollToBottom();
    }).catchError((error) {
      print('Error sending file message: $error');
    });
  }
  void _showEmojiDialog(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Wrap(
              children: [
                _buildEmojiButton('❤️', index),
                _buildEmojiButton('😱', index),
                _buildEmojiButton('😢', index),
                _buildEmojiButton('😡', index),
                _buildEmojiButton('😍', index),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildEmojiButton(String emoji, int index) {
    bool isSelected = _messages[index]['reaction'] == emoji;

    return IconButton(
      onPressed: () {
        Navigator.of(context).pop();
        setState(() {
          if (isSelected) {
            _messages[index].remove('reaction');
            _storeReactionInDatabase(index, null);
          } else {
            _messages[index]['reaction'] = emoji;
            _storeReactionInDatabase(index, emoji);
          }
        });
      },
      icon: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          //border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
        ),
        padding: const EdgeInsets.all(5.0),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 20,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  void _storeReactionInDatabase(int index, String? emoji) {
    DatabaseReference messageRef = FirebaseDatabase.instance.ref().child('conversations/$_conversationId/${_messages[index]['key']}');
    if (emoji == null) {
      messageRef.child('reaction').remove().then((_) {
        print('Reaction removed successfully.');
      }).catchError((error) {
        print('Failed to remove reaction: $error');
      });
    } else {
      messageRef.update({'reaction': emoji}).then((_) {
        print('Reaction updated successfully.');
      }).catchError((error) {
        print('Failed to update reaction: $error');
      });
    }
  }
  Future<void> _onOpenLink(LinkableElement link) async {
    final url = Uri.encodeFull(link.url);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewContainer(url: url),
      ),
    );
  }
  void _showBottomBar(int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  Navigator.pop(context);
                  _showDeleteDialog(index);
                },
              ),
              IconButton(
                icon: Icon(Icons.translate),
                onPressed: () {
                  // Implement translation logic here
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  _copyMessage(index);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Message'),
          content: Text('Are you sure you want to delete this message?'),
          actions: [
            // Delete for Me Button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  _deleteMessage(index, false);
                  Navigator.pop(context);
                },
                child: Text(
                  'Delete for Me',
                  style: TextStyle(color: Colors.black), // Change color as needed
                ),
              ),
            ),
            // Delete for Everyone Button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  _deleteMessage(index, true);
                  Navigator.pop(context);
                },
                child: Text(
                  'Delete for Everyone',
                  style: TextStyle(color: Colors.black), // Change color as needed
                ),
              ),
            ),
            // Cancel Button
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  void _copyMessage(int index) {
    final message = _messages[index]['message'];
    Clipboard.setData(ClipboardData(text: message));
  }
  void _deleteMessage(int index, bool forEveryone) async {
    String messageKey = _messages[index]['key'];
    String currentUserUid = widget.currentUserUid;

    if (forEveryone) {
      // Delete the message for everyone
      await FirebaseDatabase.instance
          .reference()
          .child('conversations')
          .child(_conversationId)
          .child(messageKey)
          .remove();
    } else {
      // Delete the message just for the current user
      await FirebaseDatabase.instance
          .reference()
          .child('conversations')
          .child(_conversationId)
          .child(messageKey)
          .child('deletedFor')
          .update({currentUserUid: true});
    }

    setState(() {
      _messages.removeAt(index);
    });
  }
  Future<String> _getUserName(String uid) async {
    DatabaseReference userRef = _databaseRef.child('users').child(uid);
    DataSnapshot snapshot = await userRef.once().then((event) => event.snapshot);
    if (snapshot.value != null) {
      Map<dynamic, dynamic> user = snapshot.value as Map<dynamic, dynamic>;
      return '${user['firstName']} ${user['lastName']}';
    }
    return '';
  }
  Future<void> _sendNotificationToOtherUser(String message) async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users').child(widget.otherUserUid);
    userRef.child('fcmToken').once().then((DatabaseEvent event) async {
      String? fcmToken = event.snapshot.value as String?;

      if (fcmToken != null) {
        String senderName = await _getUserName(widget.currentUserUid);
        _sendPushNotification(fcmToken, "$senderName", message);
      }
    });
  }
  Future<void> _sendNotificationimageToOtherUser(String message, String imageUrl) async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users').child(widget.otherUserUid);
    userRef.child('fcmToken').once().then((DatabaseEvent event) async {
      String? fcmToken = event.snapshot.value as String?;

      if (fcmToken != null) {
        String senderName = await _getUserName(widget.currentUserUid);
        _sendNotificationWithImage(fcmToken, "$senderName", message, imageUrl);
      }
    });
  }
  Future<String> _getProfileImageUrl(String uid) async {
    try {
      Reference ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
      String url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error fetching profile image URL: $e');
      return '';
    }
  }
  void _sendNotificationWithImage(String fcmToken, String title, String body, String imageUrl) async {
    String senderProfileImageUrl = await _getProfileImageUrl(widget.currentUserUid);

    try {
      String accessToken = await getAccessToken();
      var response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/chat-aa4b2/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
              'image': imageUrl,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully');
      } else {
        print('Error sending push notification: ${response.body}');
      }
    } catch (e) {
      print('Exception in sending push notification: $e');
    }
  }

  Future<void> _sendPushNotification(String fcmToken, String title, String body) async {
    String senderProfileImageUrl = await _getProfileImageUrl(widget.currentUserUid);

    try {
      String accessToken = await getAccessToken();
      var response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/chat-aa4b2/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
              'image': senderProfileImageUrl,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully');
      } else {
        print('Error sending push notification: ${response.body}');
      }
    } catch (e) {
      print('Exception in sending push notification: $e');
    }
  }

  static Future<String> getAccessToken() async {
    final serviceJson = {
      "type": "service_account",
      "project_id": "chat-aa4b2",
      "private_key_id": "4d9d60208845d0a3af4ccdbccea348a365e2e023",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGR5AT9/+DOzWN\nhk5ZvDT3GMOdNN0sYbpZefanm2cYP/mGAjIbT5C/MA5UvQQr5vkVunKdRvWlc5oJ\nehtuvIEECZCjEH5r6/XP/ixjwiqnlL6FCiPsYRQVtbBc5QvuL6DIjkeSVeZQnpbj\nx6RxUoOzH0g65Ks9gdaJXYj+TAoTULXNy7+lx/XSR2G/NXFBt9XmPdHY6JwV/BQS\nY0qmQr7/G4bdGDM9FlhRuZ1pbxfm/M+77jfcdkSrYaL1h+dSjfT8FMu2YTd2FJk6\nYEZszWotAqYQ/s2RLfKYfa5Aj6BNUiELdfmopZXYWURQILZ/z7DABB/Aqj+mnsWa\nMMhpDDVHAgMBAAECggEAK24zZdxVcFZAxa4cbVVnOJSJDF8u7vC9E6o+V7oXW91v\nd2X1ubu01dvd17vLNR6TgqnjPwXy+nmWzOqdJaVOkSbTMpSDTHpTzmo7KOK32xse\nnB97fORKtPKmHcLh2Rs/mY5oqOn917zVCjGJmHTdehepB5Vc2M0ew9nkDudy8YXB\n9ChHE2L4RzGJgc+KnqkVENp/REtKINb93IHvoO0E8bujW4xHih1u+6joDYfNAEcu\n86oGobcjh1iym18zGCVfUL146dRX51niD0xFYg+nmT6zbWce2RjHXRQNWKwYYoQQ\nZx5KKK3ZdcvS3f4NxOaKcxxVs4l7HjVc2Fz/wfb+2QKBgQD7MYsU920BMQV0KMSH\ntRm02Xm8dw3ogjW1ysosm6fRPy08xc86VmIBUuklMMo4tSWiOhweILsAHCy1sQMC\nAf/OquWH9lj8EGVMnCIA3IV1SQH6cDuEv9639jUxVyLKsMrulIdpW3RuASJWzf7x\nj2gsnEzdnM+2OwazuExcTihM1QKBgQDKEtLO45r3TVGJqQphOfJltcOZkWN1iDwF\ncSvwLRVpW7I061T5AEvHvLUePlFUiarSXN69PEwgAogxOttYI3ItsrzZ3gF1xY++\nlr9Nh30NkvGpE3C6ibuBgb9XN3l6NC0fHKoGSd/1ChIW+XmjpQ1hHueXLCkrvxT5\ni2cM8jLXqwKBgDf9gxLZU+LAGocZzzSwmVpGX2wy3VbGL1KmMQpgZ7esbVjufpJy\nTsYcxPsVNP4O4qSWb04H3abYoN6e5hy8dViLnz3/GzaUMQAyjSHEBbtu2pIIEjw0\nyGAY8SJeWdL0NUeYs9Y4HGuotQ7EO998J6xJ6pg7K9Fitsu4eMzaXwFBAoGAIQQ6\nVXty0n1bmTZ5b7FcHao5L1pF+eoshGcdWrzDBtfooiThWV3nA9edcDeWak2kD4MF\nEb5MYd6ICiMnu5rvCPBvUtmnO2rwNZ/D2hMNJ66etZVrkc73SA2/Ca0SuBjWVoME\ndMqVQSBIHGDesxJAwWGfTV/1yiQKdUuFpuPb0skCgYEAxAamEwco3hLlfcJ6Yknt\n+e1jEbcBUbT8itDujh3VwVgx/+4p3Q5j/kY4YbTqz7LTlcmORjON0WJxCYFAg2TF\nSsR33+VhtkbYDfUSHuOZkt2BI/pLkQ4VlJNseWXJhSWTGU697Prl9Vcg+SqN1Pu3\nHWQM+CGaVOl/sIemFCJR6Tk=\n-----END PRIVATE KEY-----\n",
      "client_email": "chat-with-moatez@chat-aa4b2.iam.gserviceaccount.com",
      "client_id": "116397775599706564698",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/chat-with-moatez%40chat-aa4b2.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };
    var accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceJson);
    List<String> scopes = [servicecontrol.ServiceControlApi.cloudPlatformScope];

    var authClient = await auth.clientViaServiceAccount(accountCredentials, scopes);
    var accessToken = (await authClient.credentials).accessToken;
    return accessToken.data;
  }
  Future<void> _sendCallNotification(String fcmToken, String callerUid, String calleeUid) async {
    String callerName = await _getUserName(callerUid);
    String callerProfileImageUrl = await _getProfileImageUrl(callerUid);

    try {
      String accessToken = await getAccessToken();
      var response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/chat-aa4b2/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': '$callerName is calling you',
              'body': 'Tap to answer the call.',
              'image': callerProfileImageUrl,
            },
            'data': {
              'callerUid': callerUid,
              'calleeUid': calleeUid,
              'type': 'CALL',
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully');
      } else {
        print('Error sending push notification: ${response.body}');
      }
    } catch (e) {
      print('Exception in sending push notification: $e');
    }
  }


  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    _record.dispose();
    _animatedMessageController?.dispose();

    super.dispose();
  }

  Widget buildReplyMessageUI(BuildContext context, Map<String, dynamic> repliedMessage, String senderName, bool isCurrentUser) {
    Color bubbleColor = isCurrentUser ? Colors.blue[200]! : Colors.grey[300]!;
return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),

    child: Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              color: Colors.green,
              width: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reply to $senderName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (repliedMessage['imageUrl'] != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.5,
                        maxHeight: 50,
                      ),
                      child: Image.network(repliedMessage['imageUrl']),
                    )
                  else if (repliedMessage['videoUrl'] != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.5,
                        maxHeight: 50,
                      ),
                      child: VideoMessageWidget(videoUrl: repliedMessage['videoUrl']),
                    )
                  else
                    Text(
                      repliedMessage['message'] ?? '',
                      style: TextStyle(color: Colors.black54),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildMessageWidget(int index) {
    bool isCurrentUser = _messages[index]['senderUid'] == widget.currentUserUid;
    bool isDifferentUser = index == 0 || _messages[index]['senderUid'] != _messages[index - 1]['senderUid'];
    bool isDeletedForCurrentUser = _messages[index]['deletedFor'] != null &&
        _messages[index]['deletedFor'][widget.currentUserUid] == true;

    if (isDeletedForCurrentUser) {
      return Container(); // Return an empty container if the message is deleted for the current user
    }
    Map<String, dynamic>? repliedMessage;
    if (_messages[index]['replyTo'] != null) {
      repliedMessage = _messages.firstWhere(
            (message) => message['key'] == _messages[index]['replyTo']['key'],
        orElse: () => {},
      );
    }
    return SwipeTo(
      onLeftSwipe: isCurrentUser
          ? (details) {
        setState(() {
          _replyMessage = _messages[index];
        });
      }
          : null,
      onRightSwipe: !isCurrentUser
          ? (details) {
        setState(() {
          _replyMessage = _messages[index];
        });
      }
          : null,
    child: GestureDetector(
      onTap: () {
        setState(() {
          _selectedMessageIndex = _selectedMessageIndex == index ? null : index;
        });
      },
      onLongPress: () {
        _showEmojiDialog(index);
        _showBottomBar(index);
      },
      child: AnimatedBuilder(
        animation: _animation ?? AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final scale = _animatedMessageIndex == index ? _animation!.value : 1.0;
          return Transform(
            transform: Matrix4.identity()..scale(scale),
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isDifferentUser) SizedBox(height: 10),
                if (repliedMessage != null && repliedMessage.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      int replyMessageIndex = _messages.indexWhere((message) => message['key'] == repliedMessage!['key']);
                      if (replyMessageIndex != -1) {
                        _scrollToMessage(replyMessageIndex);
                      }
                    },
                    child: buildReplyMessageUI(
                      context,
                      repliedMessage!,
                      repliedMessage['senderUid'] == widget.currentUserUid ? 'yourself' : widget.otherUserName,
                      isCurrentUser,
                    ),

                  ),
                  SizedBox(height: 5),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_messages[index]['voiceUrl'] != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue[200] : Colors.grey[300],
                            borderRadius: isCurrentUser ? _getMessageBorderRadius(index) : _getMessageBorderRadiusR(index),
                          ),
                          child: VoiceMessageWidget(
                            voiceUrl: _messages[index]['voiceUrl'],
                          ),
                        ),
                      )
                    else if (_messages[index]['fileUrl'] != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue[200] : Colors.grey[300],
                            borderRadius: isCurrentUser ? _getMessageBorderRadius(index) : _getMessageBorderRadiusR(index),
                          ),
                          child: _messages[index]['fileUrl'].endsWith('.pdf')
                              ? GestureDetector(
                            onTap: () {
                              _downloadFile(_messages[index]['fileUrl'], _messages[index]['fileName'] ?? 'file.pdf');
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf, color: isCurrentUser ? Colors.white : Colors.black87),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _messages[index]['fileName'] ?? 'PDF File',
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.white : Colors.black87,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                                Icon(Icons.download, color: isCurrentUser ? Colors.white : Colors.black87),
                              ],
                            ),
                          )
                              : GestureDetector(
                            onTap: () {
                              _downloadFile(_messages[index]['fileUrl'], _messages[index]['fileName'] ?? 'file');
                            },
                            child: Text(
                              _messages[index]['fileName'] ?? 'File',
                              style: TextStyle(
                                color: isCurrentUser ? Colors.white : Colors.black87,
                                fontSize: 16.0,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_messages[index]['imageUrl'] != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImage(url: _messages[index]['imageUrl']),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
                            child: ImageMessageWidget(imageUrl: _messages[index]['imageUrl']),
                          ),
                        )
                      else if (_messages[index]['videoUrl'] != null)
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 2, horizontal: 15),
                            child: VideoMessageWidget(videoUrl: _messages[index]['videoUrl']),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 15,),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrentUser ? Colors.blue[200] : Colors.grey[300],
                                borderRadius: isCurrentUser ? _getMessageBorderRadius(index) : _getMessageBorderRadiusR(index),
                              ),
                              child: Linkify(
                                onOpen: _onOpenLink,
                                text: _messages[index]['message'],
                                style: TextStyle(
                                  color: isCurrentUser ? Colors.white : Colors.black,
                                ),
                                linkStyle: TextStyle(
                                  color: isCurrentUser ? Colors.white : Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                    if (_messages[index]['reaction'] != null)
                      Positioned(
                        bottom: -5,
                        left: isCurrentUser ? 15 : null,
                        right: isCurrentUser ? null : 15,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),

                          ),
                          child: Text(
                            _messages[index]['reaction'],
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    if (isCurrentUser && index == _lastSeenMessageIndex)
                      Positioned(
                        bottom: 0,
                        right: 3,
                        child: CircleAvatar(
                          radius: 6,
                          backgroundImage: NetworkImage(widget.otherUserProfileImage),
                        ),
                      ),
                  ],
                ),
                if (_selectedMessageIndex == index)
                  Padding(
                    padding: isCurrentUser ? const EdgeInsets.only(bottom: 8.0, right: 12.0) : const EdgeInsets.only(bottom: 8.0, left: 12.0),
                    child: Text(
                      _formatTimestamp(_messages[index]['timestamp']),
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  Future<void> _openFile(String fileUrl) async {
    try {
      await OpenFile.open(fileUrl);
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    final status = await Permission.storage.request();

    if (status.isGranted) {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/$fileName');

      try {
        await Dio().download(url, file.path);
        OpenFile.open(file.path);
      } catch (e) {
        print('Error downloading file: $e');
      }
    } else {
      print('Permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.otherUserProfileImage),
            ),
            const SizedBox(width: 8),
            Text(widget.otherUserName),
            Spacer(),
            IconButton(
              icon: Icon(Icons.call),
              onPressed: _startAudioCall,
              color: Colors.green,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageWidget(index);
                  },
                ),
              ),
              if (_replyMessage != null)
                ReplyMessageWidget(
                  message: _replyMessage!,
                  senderName: _replyMessage!['senderUid'] == widget.currentUserUid
                      ? 'yourself'
                      : widget.otherUserName,
                  onCancelReply: () {
                    setState(() {
                      _replyMessage = null;
                    });
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      onPressed: startStopRecord,
                      color: Colors.deepPurple,
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file),
                      onPressed: _pickFile,
                      color: Colors.deepPurple,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Colors.deepPurpleAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
  class VoiceMessageWidget extends StatefulWidget {
  final String voiceUrl;

  const VoiceMessageWidget({Key? key, required this.voiceUrl}) : super(key: key);

  @override
  _VoiceMessageWidgetState createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _audioPlayer.setSourceUrl(widget.voiceUrl);
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() {
        _duration = d;
      });
    });
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play(UrlSource(widget.voiceUrl));
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline),
              onPressed: _playPause,
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: _duration.inSeconds.toDouble(),
                value: _position.inSeconds.toDouble(),
                onChanged: (value) {
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ],
        ),
        Text(
          '${_position.inMinutes}:${_position.inSeconds.remainder(60).toString().padLeft(2, '0')} / '
              '${_duration.inMinutes}:${_duration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}


class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;

  VideoMessageWidget({required this.videoUrl});

  @override
  _VideoMessageWidgetState createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  late VideoPlayerController _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayerController.value.isInitialized
        ? ClipRRect(
      borderRadius: BorderRadius.circular(16.0), // Adjust the radius as needed
      child: Container(
        width: MediaQuery.of(context).size.width * 0.52,
        height: MediaQuery.of(context).size.width * 0.7,
        child: Chewie(
          controller: ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: false,
            looping: false,
            aspectRatio: _videoPlayerController.value.aspectRatio,
          ),
        ),
      ),
    )
        : CircularProgressIndicator();
  }
}

class FullScreenImage extends StatelessWidget {
  final String url;

  const FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Image.network(url),
      ),
    );
  }
}


class ImageMessageWidget extends StatelessWidget {
  final String imageUrl;

  ImageMessageWidget({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0), // Adjust the radius as needed
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.5,
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
class SpinningStrokePainter extends CustomPainter {
  final double progress;
  final Color color;

  SpinningStrokePainter({
    required this.progress,
    this.color = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final double radius = size.width / 2;
    final double startAngle = -progress * 2 * 3.141592653589793;
    final double sweepAngle = 2 * 3.141592653589793 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(radius, radius), radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SpinningStrokePainter &&
        (oldDelegate.progress != progress || oldDelegate.color != color);
  }
}
