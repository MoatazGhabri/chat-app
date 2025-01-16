import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

class NotificationPage extends StatefulWidget {
  final String currentUserUid;

  NotificationPage({required this.currentUserUid});

  @override
  _NotificationPageState createState() =>
      _NotificationPageState(currentUserUid: currentUserUid);
}

class _NotificationPageState extends State<NotificationPage> {
  final String currentUserUid;
  List<Map<String, dynamic>> _friendRequests = [];

  _NotificationPageState({required this.currentUserUid});

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }

  Future<void> _fetchFriendRequests() async {
    try {
      DatabaseReference ref =
      FirebaseDatabase.instance.reference().child('invitations').child(currentUserUid);
      DatabaseEvent event = await ref.once();
      Map<String, dynamic> invitations =
      Map<String, dynamic>.from(event.snapshot.value as Map);

      List<Map<String, dynamic>> requests = [];

      for (String key in invitations.keys) {
        if (invitations[key]['status'] == 'pending') {
          String senderUid = invitations[key]['senderUid'];
          DatabaseReference userRef =
          FirebaseDatabase.instance.reference().child('users').child(senderUid);
          DatabaseEvent userEvent = await userRef.once();
          Map<String, dynamic> userData =
          Map<String, dynamic>.from(userEvent.snapshot.value as Map);

          Map<String, dynamic> request = {
            'uid': senderUid,
            'name': '${userData['firstName']} ${userData['lastName']}',
            'profileImageUrl': await _getProfileImageUrl(senderUid),
            'invitationKey': key
          };

          requests.add(request);
        }
      }

      setState(() {
        _friendRequests = requests;
      });
    } catch (e) {
      print('Error fetching friend requests: $e');
    }
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

  Future<void> _acceptFriendRequest(String invitationKey, String senderUid) async {
    try {

      // Update invitation status to accepted
      DatabaseReference ref = FirebaseDatabase.instance
          .reference()
          .child('invitations')
          .child(currentUserUid).child(invitationKey);
      await ref.update({'status': 'accepted'});

      // Refresh friend requests
      _fetchFriendRequests();
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  Future<void> _rejectFriendRequest(String senderUid) async {
    DatabaseReference invitationsRef = FirebaseDatabase.instance.reference().child('invitations').child(currentUserUid);

    invitationsRef
        .orderByChild('senderUid')
        .equalTo(senderUid)
        .once()
        .then((event) {
      DataSnapshot snapshot = event.snapshot;
      if (snapshot.value != null) {
        Map<dynamic, dynamic> invitations = snapshot.value as Map<dynamic, dynamic>;
        invitations.forEach((key, value) {
          if (value['senderUid'] == senderUid) {
            invitationsRef.child(key).remove().then((_) {
              // Update the local search results immediately
              setState(() {

              });
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Requests'),
      ),
      body: ListView.builder(
        itemCount: _friendRequests.length,
        itemBuilder: (context, index) {
          Map<String, dynamic> request = _friendRequests[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(request['profileImageUrl']),
            ),
            title: Text(request['name']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _acceptFriendRequest(
                      request['invitationKey'], request['uid']),
                ),
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectFriendRequest(request['uid']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
