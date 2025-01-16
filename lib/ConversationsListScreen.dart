import 'package:new_app/ConversationScreen.dart';
import 'package:new_app/FirebaseApi.dart';
import 'package:new_app/Notification.dart';
import 'package:new_app/Search_friends.dart';
import 'package:new_app/recherche.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  //FirebaseMessaging.onBackgroundMessage(MyFirebaseMessagingService.firebaseMessagingBackgroundHandler);
  //await FirebaseApi().initNotifications();
  runApp(const FigmaToCodeApp());
}

class ConversationsListScreen extends StatefulWidget {
  final String currentUserUid;

  ConversationsListScreen({required this.currentUserUid});

  @override
  _ConversationsListScreenState createState() =>
      _ConversationsListScreenState(currentUserUid: currentUserUid);
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  final String currentUserUid;
  String? _currentUserProfileImageUrl;
  int _friendRequestCount = 0;

  _ConversationsListScreenState({required this.currentUserUid});

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _fetchCurrentUserProfileImage();
    _fetchFriendRequests();
    _setupListener();
  }

  Future<void> _fetchConversations() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.reference().child('conversations');
      DatabaseEvent event = await ref.once();

      Map<String, dynamic> allConversations = Map<String, dynamic>.from(event.snapshot.value as Map);

      List<Map<String, dynamic>> userConversations = [];

      for (String key in allConversations.keys) {
        if (key.contains(widget.currentUserUid)) {
          Map<String, dynamic> conversationData = Map<String, dynamic>.from(allConversations[key]);

          String otherUserUid = key.replaceAll(widget.currentUserUid, '').replaceAll('_', '');
          Map<String, dynamic> conversation = {
            'otherUserUid': otherUserUid,
            'messages': conversationData
          };

          // Fetch the other user's details
          DatabaseReference userRef = FirebaseDatabase.instance.reference().child('users').child(otherUserUid);
          DatabaseEvent userEvent = await userRef.once();
          Map<String, dynamic> userData = Map<String, dynamic>.from(userEvent.snapshot.value as Map);

          conversation['otherUserName'] = '${userData['firstName']} ${userData['lastName']}';
          conversation['profileImageUrl'] = await _getProfileImageUrl(otherUserUid);

          // Fetch the last message
          var messages = Map<String, dynamic>.from(conversationData);
          var sortedKeys = messages.keys.toList(growable: false)
            ..sort((k1, k2) => messages[k1]['timestamp'].compareTo(messages[k2]['timestamp']));

          String? lastMessageKey;
          for (String key in sortedKeys.reversed) {
            if (messages[key]['deletedFor']?[widget.currentUserUid] != true) {
              lastMessageKey = key;
              break;
            }
          }

          if (lastMessageKey != null) {
            Map<String, dynamic> lastMessage = Map<String, dynamic>.from(messages[lastMessageKey]);

            conversation['lastMessage'] = lastMessage['message'];
            conversation['timestamp'] = lastMessage['timestamp'];
            conversation['seen'] = lastMessage['seen'];
            conversation['senderUid'] = lastMessage['senderUid'];
          } else {
            continue;
          }

          userConversations.add(conversation);
        }
      }

      setState(() {
        _conversations = userConversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  String _generateConversationKey(String uid1, String uid2) {
    List<String> sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }
  Future<void> _refreshConversations() async {
    await _fetchConversations();
  }

  void _setupListener() {
    DatabaseReference ref = FirebaseDatabase.instance.reference().child('conversations');
    ref.onChildChanged.listen((event) {
      String changedKey = event.snapshot.key!;
      Map<String, dynamic> changedData = Map<String, dynamic>.from(event.snapshot.value as Map);

      if (changedKey.contains(widget.currentUserUid)) {
        String otherUserUid = changedKey.replaceAll(widget.currentUserUid, '').replaceAll('_', '');

        // Update the existing conversation
        setState(() {
          _conversations = _conversations.map((conversation) {
            if (conversation['otherUserUid'] == otherUserUid) {
              var messages = Map<String, dynamic>.from(changedData);
              var sortedKeys = messages.keys.toList(growable: false)
                ..sort((k1, k2) => messages[k1]['timestamp'].compareTo(messages[k2]['timestamp']));

              String? lastMessageKey;
              for (String key in sortedKeys.reversed) {
                if (messages[key]['deletedFor']?[widget.currentUserUid] != true) {
                  lastMessageKey = key;
                  break;
                }
              }

              if (lastMessageKey != null) {
                Map<String, dynamic> lastMessage = Map<String, dynamic>.from(messages[lastMessageKey]);

                conversation['lastMessage'] = lastMessage['message'];
                conversation['timestamp'] = lastMessage['timestamp'];
                conversation['seen'] = lastMessage['seen'];
                conversation['senderUid'] = lastMessage['senderUid'];
              } else {
                conversation['lastMessage'] = 'No messages yet';
                conversation['timestamp'] = DateTime.now().millisecondsSinceEpoch;
                conversation['seen'] = false;
                conversation['senderUid'] = '';
              }
            }
            return conversation;
          }).toList();
        });
      }
    });
  }

  Future<String> _getProfileImageUrl(String uid) async {
    try {
      Reference ref =
      FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
      String url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error fetching profile image URL: $e');
      return '';
    }
  }

  Future<void> _fetchCurrentUserProfileImage() async {
    try {
      String url = await _getProfileImageUrl(currentUserUid);
      setState(() {
        _currentUserProfileImageUrl = url;
      });
    } catch (e) {
      print('Error fetching current user profile image URL: $e');
    }
  }

  String _formatTimestamp(int timestamp) {
    DateTime now = DateTime.now();
    DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (now.difference(messageTime).inDays >= 7) {
      var format = DateFormat('MMM dd, yyyy-hh:mm a');
      return format.format(messageTime);
    } else if (now.day == messageTime.day &&
        now.month == messageTime.month &&
        now.year == messageTime.year) {
      var format = DateFormat('hh:mm a');
      return format.format(messageTime);
    } else {
      var format = DateFormat('EEEE');
      String dayOfWeek = format.format(messageTime);
      return '$dayOfWeek - ${messageTime.day}/${messageTime.month}';
    }
  }

  Future<void> _fetchFriendRequests() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance
          .reference()
          .child('invitations')
          .child(currentUserUid);

      DatabaseEvent event = await ref.once();
      if (event.snapshot.value != null) {
        Map<String, dynamic> invitations =
        Map<String, dynamic>.from(event.snapshot.value as Map);

        int pendingRequests = invitations.values
            .where((invitation) => invitation['status'] == 'pending')
            .length;
        setState(() {
          _friendRequestCount = pendingRequests;
        });
      }
    } catch (e) {
      print('Error fetching friend requests: $e');
    }
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
      // Current screen is Conversations, do nothing
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => Recherche(currentUserUid: currentUserUid)),
        ).then((_) {
          setState(() {
            _selectedIndex = 0; // Update the selected index to Conversations
          });
        });
        break;
    // Add more cases for other bottom navigation items if needed
    }
  }
  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return false; // Prevents the default back action
    }
    return true; // Allows the default back action
  }
  void _showOptionsBottomSheet(Map<String, dynamic> conversation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be scrollable
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Conversation'),
                onTap: () {
                  Navigator.of(context).pop(); // Close the bottom sheet
                  _showDeleteConfirmationDialog(conversation['otherUserUid']);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.black),
                title: Text('Block User'),
                onTap: () {
                  // Handle block user logic here
                  Navigator.of(context).pop(); // Close the bottom sheet
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String otherUserUid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this conversation?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
                _deleteConversation(otherUserUid); // Proceed with deletion
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConversation(String otherUserUid) async {

    String conversationKey = _generateConversationKey(widget.currentUserUid, otherUserUid);

    DatabaseReference ref =
    FirebaseDatabase.instance.reference().child('conversations').child(conversationKey);

    DatabaseEvent event = await ref.once();
    Map<String, dynamic>? messages = event.snapshot.value != null
        ? Map<String, dynamic>.from(event.snapshot.value as Map)
        : null;

    if (messages != null) {
      messages.forEach((key, value) {
        value['deletedFor'] ??= {};
        value['deletedFor'][widget.currentUserUid] = true;
      });

      await ref.update(messages);
    }

    _refreshConversations(); // Refresh the conversation list
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Conversations'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.group),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            NotificationPage(currentUserUid: currentUserUid)),
                  );
                },
              ),
              if (_friendRequestCount > 0)
                Positioned(
                  right: 5,
                  top: 11,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '$_friendRequestCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        SearchFriends(currentUserUid: currentUserUid)),
              );
            },
          ),
          if (_currentUserProfileImageUrl != null)
            CircleAvatar(
              backgroundImage: NetworkImage(_currentUserProfileImageUrl!),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _refreshConversations,
            child: ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> conversation =
                _conversations[index];
                String formattedTimestamp =
                _formatTimestamp(conversation['timestamp']);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                        conversation['profileImageUrl']),
                  ),
                  title: Text(conversation['otherUserName'] ?? ''),
                  subtitle: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation['lastMessage'] ??
                              'No messages yet',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTimestamp,
                        style: TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                      if (conversation['senderUid'] ==
                          widget.currentUserUid)
                        Icon(
                          conversation['seen']
                              ? Icons.done_all
                              : Icons.done,
                          color: conversation['seen']
                              ? Colors.blue
                              : Colors.grey,
                          size: 16,
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConversationScreen(
                          otherUserUid:
                          conversation['otherUserUid'],
                          currentUserUid:
                          widget.currentUserUid,
                          otherUserProfileImage:
                          conversation['profileImageUrl'],
                          otherUserName:
                          conversation['otherUserName'],
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    _showOptionsBottomSheet(conversation);
                  },
                );
              },
            ),
          ),
        ],
      ),
        bottomNavigationBar: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'images/chat.png',
                    height: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'images/matchmaker.png',
                    height: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'images/add.png',
                    height: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'images/groups.png',
                    height: 24,
                  ),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'images/settings.png',
                    height: 24,
                  ),
                  label: '',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.purple[600],
              unselectedItemColor: Colors.grey,
              elevation: 50,
              onTap: _onItemTapped,
            ),
            Positioned(
              bottom: 10,
              left:(MediaQuery.of(context).size.width / 5 * _selectedIndex) +
                  (MediaQuery.of(context).size.width / 10) - 10,
              child: Container(
                width: 45,
                height: 5,
                color: Colors.purple[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
