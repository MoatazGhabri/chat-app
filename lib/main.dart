import 'package:new_app/CallAcceptDeclinePage.dart';
import 'package:new_app/ConversationsListScreen.dart';
import 'package:new_app/FirebaseApi.dart';
//import 'package:chat_app/MyFirebaseMessagingService.dart';
import 'package:new_app/register.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'enums.dart';
import 'firebase_options.dart';
import 'user.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await Firebase.initializeApp();
  //FirebaseMessaging.onBackgroundMessage(MyFirebaseMessagingService.firebaseMessagingBackgroundHandler);
  //await FirebaseApi().initNotifications();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  NotificationService notificationService = NotificationService();
  await notificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const FigmaToCodeApp());
}
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}
class FigmaToCodeApp extends StatelessWidget {
  const FigmaToCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          // If the user is logged in, navigate to the ConversationsListScreen
          return ConversationsListScreen(currentUserUid: snapshot.data!.uid);
        } else {
          // If the user is not logged in, navigate to the Login screen
          return Scaffold(
            body: Login(),
          );
        }
      },
    );
  }
}

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  DatabaseReference _databaseRef = FirebaseDatabase.instance.reference();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  //late MyFirebaseMessagingService _firebaseMessagingService; // Define the variable
  final NotificationService _notificationService = NotificationService();

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      DatabaseReference ref = FirebaseDatabase.instance.reference().child('users').child(userCredential.user!.uid);

      DatabaseEvent event = await ref.once();
      FirebaseMessaging.instance.getToken().then((String? token) {
        assert(token != null);
        ref.child('fcmToken').set(token);
      });

      if (event.snapshot.value != null) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Retrieve profile image URL from Firebase Storage
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userCredential.user!.uid)
            .child('profile.jpg');

        String imageUrl = await storageRef.getDownloadURL();

        Fluttertoast.showToast(
          msg: "Login Successful",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        await _notificationService.saveFCMToken(userCredential.user!.uid);

        // Navigate to the next screen and pass the user data and image URL
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ConversationsListScreen(currentUserUid: userCredential.user!.uid)),
        );
      } else {
        Fluttertoast.showToast(
          msg: "User data not found",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(
        msg: e.message ?? "Login failed",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString(),
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false; // Set loading state back to false
      });
    }
  }

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (message.data['type'] == 'CALL') {
        String callerUid = message.data['callerUid'];
        String calleeUid = message.data['calleeUid'];
        String callerName = await _getUserName(callerUid);
        String callerImageUrl = await _getProfileImageUrl(callerUid);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallAcceptDeclinePage(
              user: Users(
                uid: callerUid,
                name: callerName,
                picture: callerImageUrl,
              ),
              callStatus: DuringCallStatus.ringing,
              roomId: null,
            ),
          ),
        );
      }
    });

    // _firebaseMessagingService = MyFirebaseMessagingService();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: getWidth(context),
      height: getHeight(context),
      decoration: BoxDecoration(color: Color(0xFFC2BCE3)),
      child: Stack(
        children: [
          Positioned(
            left: -133,
            top: -141,
            child: Container(
              width: 270,
              height: 270,
              decoration: ShapeDecoration(
                color: Color(0xFF8478CC),
                shape: OvalBorder(),
                shadows: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 13,
                    offset: Offset(7, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            left: -105,
            top: -214,
            child: Container(
              width: 270,
              height: 270,
              decoration: ShapeDecoration(
                color: Color(0xFF8B7BE8),
                shape: OvalBorder(),
                shadows: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 13,
                    offset: Offset(7, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            left: 506.04,
            top: 880.92,
            child: Transform(
              transform: Matrix4.identity()..translate(0.0, 0.0)..rotateZ(-3.11),
              child: Container(
                width: 270,
                height: 270,
                decoration: ShapeDecoration(
                  color: Color(0xFF8478CC),
                  shape: OvalBorder(),
                  shadows: [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 13,
                      offset: Offset(-13, 4),
                      spreadRadius: 0,
                    )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 475.88,
            top: 953.05,
            child: Transform(
              transform: Matrix4.identity()..translate(0.0, 0.0)..rotateZ(-3.11),
              child: Container(
                width: 270,
                height: 270,
                decoration: ShapeDecoration(
                  color: Color(0xFF8B7BE8),
                  shape: OvalBorder(),
                  shadows: [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 13,
                      offset: Offset(-13, 4),
                      spreadRadius: 0,
                    )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 137,
            top: 200,
            child: SizedBox(
              width: 122,
              height: 53,
              child: Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  height: 0,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 324,
            child: SizedBox(
              width: 304,
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.email, color: Colors.black.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.only(topRight: Radius.circular(40)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 390,
            child: SizedBox(
              width: 304,
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword, // Use _obscurePassword here
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.lock, color: Colors.black.withOpacity(0.6)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,

                      color: Colors.black.withOpacity(0.6),
                    ),
                    onPressed: _togglePasswordVisibility, // Toggle function
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(40)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 274,
            top: 365,
            child: GestureDetector(
              onTap: _login,

              child:
              _isLoading
                  ? CircularProgressIndicator()
                  :Container(
                width: 45,
                height: 45,
                decoration: ShapeDecoration(
                  color: Color(0xFFC2BCE3),
                  shape: OvalBorder(),
                  shadows: [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 13,
                      offset: Offset(-13, 4),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Icon(
                  Icons.arrow_circle_right_rounded,
                  size: 30,
                  color: Colors.deepPurple,
                ),

              ),
            ),
          ),
          Positioned(
            left: 199,
            top: 480,
            child: SizedBox(
              width: 190,
              height: 36,
              child: Text(
                'Forget password?',
                style: TextStyle(
                  color: Color(0xFF2D0DE5),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  height: 0,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 546,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterA()),
                );
              },
              child: Container(
                width: 265,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: ShapeDecoration(
                  color: Color(0xFF8478CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 11,
                      offset: Offset(4, 4),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    Text(
                      "You don't have an account?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 0,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_ios_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NextScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String imageUrl;

  const NextScreen({required this.userData, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Next Screen'),
      ),
      body: Center(
        child: Column(
          children: [
            Image.network(imageUrl),
            Text('User Data: ${userData.toString()}'),
          ],
        ),
      ),
    );
  }
}

double getWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

double getHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}
