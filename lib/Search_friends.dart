import 'package:new_app/ConversationScreen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class SearchFriends extends StatefulWidget {
  final String currentUserUid;
  //final String imageUrl;

  const SearchFriends({
    Key? key,
    required   this.currentUserUid, //required this.imageUrl,
  }) : super(key: key);

  @override
  _SearchFriendsState createState() => _SearchFriendsState();
}

class _SearchFriendsState extends State<SearchFriends> {
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

    _databaseRef.child('users').once().then((event) async {
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic>? users = snapshot.value as Map<dynamic, dynamic>?;

        if (users != null) {
          List<Map<String, dynamic>> results = [];
          for (var key in users.keys) {
            String firstName = users[key]['firstName'].toString().toLowerCase();
            String lastName = users[key]['lastName'].toString().toLowerCase();
            if (firstName.contains(query) || lastName.contains(query)) {
              String profileImageUrl = await _getProfileImageUrl(key);
              String invitationStatus = await _checkIfInvited(key);
              if (invitationStatus == 'accepted') {
                results.add({
                  'uid': key,
                  'firstName': users[key]['firstName'],
                  'lastName': users[key]['lastName'],
                  'profileImageUrl': profileImageUrl,
                  'invitationStatus': invitationStatus,
                });
              }
            }
          }
          setState(() {
            _searchResults = results;
            _isLoading = false; // Clear loading state when search results are updated
          });
        }
      } else {
        setState(() {
          _searchResults.clear();
          _isLoading = false; // Clear loading state when search results are updated
        });
      }
    }).catchError((error) {
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
      DatabaseReference invitationsRef =
      _databaseRef.child('invitations').child(widget.currentUserUid);
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
    } catch (e) {
      print('Error checking invitations: $e');
    }
    return 'notInvited';
  }

  void _navigateToConversation(String uid) {
    final user = _searchResults.firstWhere((user) => user['uid'] == uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          currentUserUid: widget.currentUserUid,
          otherUserUid: uid,
          otherUserName: '${user['firstName']} ${user['lastName']}',
          otherUserProfileImage: user['profileImageUrl'],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white10,
        elevation: 0, // Remove shadow
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search friends...',
            fillColor: Color(0x12000000),
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
          : ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(_searchResults[index]['profileImageUrl']),
            ),
            title: Text(
                '${_searchResults[index]['firstName']} ${_searchResults[index]['lastName']}'),
            onTap: () {
              _navigateToConversation(_searchResults[index]['uid']);
            },
          );
        },
      ),
    );
  }
}

// // Example ConversationScreen class for reference
// class ConversationScreen extends StatelessWidget {
//   final String currentUserUid;
//   final String otherUserUid;
//   final String otherUserName;
//
//   const ConversationScreen({
//     Key? key,
//     required this.currentUserUid,
//     required this.otherUserUid,
//     required this.otherUserName,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     // Implement your conversation UI here
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(otherUserName),
//         // Add any other necessary UI elements
//       ),
//       body: Center(
//         child: Text('Conversation between $currentUserUid and $otherUserUid'),
//         // Implement conversation display
//       ),
//     );
//   }
// }
