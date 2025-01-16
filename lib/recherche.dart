import 'package:new_app/ConversationsListScreen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
class Recherche extends StatefulWidget {
  final String currentUserUid;
  //final String imageUrl;

  const Recherche({
    Key? key,
    required   this.currentUserUid, //required this.imageUrl,
  }) : super(key: key);

  @override
  _SearchFriendsState createState() => _SearchFriendsState();
}

class _SearchFriendsState extends State<Recherche> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  DatabaseReference _databaseRef = FirebaseDatabase.instance.reference();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isLoading = false; // Reset loading state
      });
      return;
    }
    setState(() {
      _isLoading = true; // Set loading state when searching starts
    });

    _databaseRef.child('users').onValue.listen((event) async {
      DataSnapshot snapshot = event.snapshot;
      if (snapshot.value != null) {
        Map<dynamic, dynamic>? users = snapshot.value as Map<dynamic, dynamic>?;

        if (users != null) {
          List<Map<String, dynamic>> results = [];
          for (var key in users.keys) {
            if (key == widget.currentUserUid) {
              continue;
            }
            String firstName = users[key]['firstName'].toString().toLowerCase();
            String lastName = users[key]['lastName'].toString().toLowerCase();
            if (firstName.contains(query) || lastName.contains(query)) {
              String profileImageUrl = await _getProfileImageUrl(key);
              String invitationStatus = await _checkIfInvited(key);

              results.add({
                'uid': key,
                'firstName': users[key]['firstName'],
                'lastName': users[key]['lastName'],
                'profileImageUrl': profileImageUrl,
                'invitationStatus': invitationStatus,
              });
            }
          }
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _searchResults.clear();
          _isLoading = false;
        });
      }
    }, onError: (Object error) {
      print('Error fetching data: $error');
      setState(() {
        _isLoading = false; // Clear loading state on error
      });
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

  Future<String> _checkIfInvited(String uid) async {
    try {
      // Check if the current user has invited the searched user
      DatabaseReference invitationsRef = _databaseRef.child('invitations').child(widget.currentUserUid);
      DatabaseEvent event = await invitationsRef.once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic> invitations = snapshot.value as Map<dynamic, dynamic>;
        for (var invitation in invitations.values) {
          if (invitation['senderUid'] == uid) {
            return invitation['status'];
          }
        }
      }

      // Check if the searched user has invited the current user
      DatabaseReference invitationsRefCrr = _databaseRef.child('invitations').child(uid);
      DatabaseEvent event1 = await invitationsRefCrr.once();
      DataSnapshot snapshot1 = event1.snapshot;

      if (snapshot1.value != null) {
        Map<dynamic, dynamic> invitations = snapshot1.value as Map<dynamic, dynamic>;
        for (var invitation in invitations.values) {
          if (invitation['senderUid'] == widget.currentUserUid) {
            return invitation['status'];
          }
        }
      }
    } catch (e) {
      print('Error checking invitations: $e');
    }
    return 'notInvited';
  }


  void _sendInvitation(String invitedUid)  async{
    DatabaseReference invitationsRef = _databaseRef.child('invitations').child(invitedUid);
    DatabaseReference notificationsRef = _databaseRef.child('notifications').child(invitedUid);
    DatabaseReference userRef = _databaseRef.child('users').child(invitedUid);

    userRef.child('fcmToken').once().then((DatabaseEvent event) async {
      String? fcmToken = event.snapshot.value as String?;

      if (fcmToken != null) {
        invitationsRef.push().set({
          'invitedUid': invitedUid,
          'senderUid': widget.currentUserUid,
          'status': 'pending',
        }).then((_)  async{
          String senderName = await _getUserName(widget.currentUserUid);

          notificationsRef.push().set({
            'title': 'New Friend Invitation',
            'body': 'You have received a new friend invitation.',
            'timestamp': ServerValue.timestamp,
          }).then((_) {
            _sendPushNotification(fcmToken, 'Friend Request', '$senderName');
            setState(() {
              for (var result in _searchResults) {
                if (result['uid'] == invitedUid) {
                  result['invitationStatus'] = 'pending';
                  break;
                }
              }
            });
          });
        });
      }
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
  static Future<String> getAccessToken() async{
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
   List<String> scopes = [
     servicecontrol.ServiceControlApi.cloudPlatformScope,
   ];

   var authClient = await auth.clientViaServiceAccount(accountCredentials, scopes);
   var accessToken = (await authClient.credentials).accessToken;
   return accessToken.data;
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
  void _deleteInvitation(String invitedUid) {
    DatabaseReference invitationsRef =
    _databaseRef.child('invitations').child(invitedUid);

    invitationsRef
        .orderByChild('senderUid')
        .equalTo(widget.currentUserUid)
        .once()
        .then((event) {
      DataSnapshot snapshot = event.snapshot;
      if (snapshot.value != null) {
        Map<dynamic, dynamic> invitations = snapshot.value as Map<dynamic, dynamic>;
        invitations.forEach((key, value) {
          if (value['invitedUid'] == invitedUid) {
            invitationsRef.child(key).remove().then((_) {
              // Update the local search results immediately
              setState(() {
                for (var result in _searchResults) {
                  if (result['uid'] == invitedUid) {
                    result['invitationStatus'] = 'notInvited';
                    break;
                  }
                }
              });
            });
          }
        });
      }
    });
  }
  void _showDeleteConfirmationDialog(String invitedUid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Invitation'),
          content: Text('Do you want to delete the invitation?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                _deleteInvitation(invitedUid);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ConversationsListScreen(currentUserUid: widget.currentUserUid)),
        );
      // Current screen is Conversations, do nothing
        break;

      case 2:

        break;
    // Add more cases for other bottom navigation items if needed
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white10,
        elevation: 0, // Remove shadow
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back, color: Colors.black),
        //   onPressed: () {
        //     Navigator.pop(context);
        //   },
        // ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search friends...',
            fillColor: Color(0x22000000),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50.0),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.black),
            contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 25.0),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(), // Display loading indicator
      )
          :  Positioned(
        left: 0,
        top: 133,
        right: 0,
        bottom: 0,
        child: ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            IconData iconData;
            Color iconColor;

            if (_searchResults[index]['invitationStatus'] == 'pending') {
              iconData = Icons.pending;
              iconColor = Colors.deepOrangeAccent;
            } else if (_searchResults[index]['invitationStatus'] == 'accepted') {
              iconData = Icons.check_circle;
              iconColor = Colors.green;
            }
            else {
              iconData = Icons.person_add;
              iconColor = Colors.cyan;
            }


            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(_searchResults[index]['profileImageUrl']),
              ),
              title: Text('${_searchResults[index]['firstName']} ${_searchResults[index]['lastName']}'),
              trailing: IconButton(
                icon: Icon(iconData, color: iconColor),
                onPressed: () {
                  if (_searchResults[index]['invitationStatus'] == 'pending') {
                    _showDeleteConfirmationDialog(_searchResults[index]['uid']);
                  } else if (_searchResults[index]['invitationStatus'] == 'notInvited') {
                    _sendInvitation(_searchResults[index]['uid']);
                  }
                },
              ),
            );
          },
        ),
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
                (MediaQuery.of(context).size.width / 10) - 22,
            child: Container(
              width: 45,
              height: 5,
              color: Colors.purple[600],
            ),
          ),
        ],
      ),
    );
  }
}

