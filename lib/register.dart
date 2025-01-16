import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(RegisterA());
}

class RegisterA extends StatelessWidget {
  const RegisterA({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple)
      ),
      home: Scaffold(
        backgroundColor: Color(0xFFC2BCE3),

        body:
            Register(),

      ),
    );
  }
}

class Register extends StatefulWidget {
  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _genderController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _profileImage;
  bool _isLoading = false;
  double _passwordStrength = 0;
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      } else {
        Fluttertoast.showToast(
          msg: "No image selected",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    });
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        DatabaseReference ref = FirebaseDatabase.instance
            .reference()
            .child('users')
            .child(userCredential.user!.uid);

        await ref.set({
          'uid':userCredential.user!.uid,
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'email': _emailController.text,
          'gender': _genderController.text,
          'birthday': _birthdayController.text,
        });

        // Upload profile image or use default image
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userCredential.user!.uid)
            .child('profile.jpg');

        if (_profileImage != null) {
          await storageRef.putFile(_profileImage!);
        } else {
          // Set default image based on gender
          String defaultImage = _getDefaultImage();
          ByteData imageData = await rootBundle.load(defaultImage);
          Uint8List byteData = imageData.buffer.asUint8List();
          await storageRef.putData(byteData);
        }

        Fluttertoast.showToast(
          msg: "Registration Successful",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
        );

        // Navigate to the next screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FigmaToCodeApp()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = "Registration failed";
        if (e.code == 'weak-password') {
          errorMessage = "The password provided is too weak.";
        } else if (e.code == 'email-already-in-use') {
          errorMessage = "The account already exists for that email.";
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        Fluttertoast.showToast(
          msg: errorMessage,
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
      }
      finally {
        setState(() {
          _isLoading = false; // Set loading state back to false
        });
      }
    }
  }


  void _nextStep() {
    if (_currentStep == 4 && _passwordStrength < 0.75) {
      // Show an error message if password strength is not sufficient
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password is weak.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      } else {
        _register();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _genderController.dispose();
    _birthdayController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  double _calculatePasswordStrength(String password) {
    double strength = 0;

    if (password.isEmpty) {
      return strength;
    }

    if (password.length >= 8) {
      strength += 0.25;
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      strength += 0.25;
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      strength += 0.25;
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      strength += 0.125;
    }

    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength += 0.125;
    }

    return strength;
  }
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          SizedBox(height: 40),
          LinearProgressIndicator(

            value: (_currentStep + 1) / 4,
          ),
          Expanded(

            //color: Color(0xFFC2BCE3),
            child: PageView(

              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [

                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        SizedBox(height: 35),
        Text(
          'Register',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text("Step 1: Basic Information"),
        SizedBox(height: 20),
        _buildTextField(_firstNameController, "First Name", Icons.person, false),
        _buildTextField(_lastNameController, "Last Name", Icons.person, false),
        _buildTextField(_emailController, "Email", Icons.email, false),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

            _buildHoverButton( "Next", Icons.arrow_circle_right_rounded, _nextStep, iconOnRight: true),
          ],
        ),
        SizedBox(height: 40),

        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FigmaToCodeApp()),
              );
            },
            child: Container(
              width: 234,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: Color(0xFF8478CC),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 11,
                    offset: Offset(4, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'You have an account ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  String? currentGender; // Define a variable to hold the current selected gender

  Widget _buildStep2() {
    return Column(
      children: [
        SizedBox(height: 40),
        Text('Register',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text("Step 2: Personal Information"),
        SizedBox(height: 20),
        _buildGenderDropdown(),
        _buildBirthdayPicker(),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildHoverButton("Back", Icons.arrow_circle_left, _previousStep),

            _buildHoverButton( "Next", Icons.arrow_circle_right_rounded, _nextStep, iconOnRight: true),
          ],
        ),
      ],
    );
  }


  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: DropdownButtonFormField<String>(
        value: currentGender,
        decoration: InputDecoration(
          labelText: "Gender",
          labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
          prefixIcon: Icon(Icons.wc, color: Colors.black.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          setState(() {
            currentGender = value;
            _genderController.text = currentGender!;
          });
        },
        items: ["Male", "Female"]
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(

            value: value,
            child: Text(value),
          );
        }).toList(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select your gender';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildBirthdayPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime(2006),
            firstDate: DateTime(1900),
            lastDate: DateTime(2006),
          );
          if (pickedDate != null) {
            setState(() {
              _birthdayController.text =
              "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
            });
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: _birthdayController,
            decoration: InputDecoration(
              labelText: "Birthday",
              labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
              prefixIcon: Icon(Icons.cake, color: Colors.black.withOpacity(0.6)),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your birthday';
              }
              return null;
            },

          ),
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        SizedBox(height: 40),
        Text(
          'Register',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text("Step 3: Profile Image"),
        SizedBox(height: 20),
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : AssetImage(_getDefaultImage()) as ImageProvider,
            child: _profileImage == null
                ? Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                : null,
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _profileImage = null;
            });
          },
          child: Text("Ignore"),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildHoverButton("Back", Icons.arrow_circle_left, _previousStep),

            _buildHoverButton( "Next", Icons.arrow_circle_right_rounded, _nextStep, iconOnRight: true),
          ],
        ),
      ],
    );
  }
  String _getDefaultImage() {
    String defaultImage = currentGender?.toLowerCase() == 'male' ? 'male.png' : 'female.png';
    return "images/$defaultImage";
  }



  Widget _buildStep4() {
    return Column(
      children: [
        SizedBox(height: 40),
        Text(
          'Register',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text("Step 4: Set Password"),
        SizedBox(height: 20),
        _buildPassField(_passwordController, "Password", Icons.lock, true),
        SizedBox(
         width: 300,
        child: LinearProgressIndicator(
          value: _passwordStrength,
          backgroundColor: Colors.grey[300],

          valueColor: AlwaysStoppedAnimation<Color>(
            _passwordStrength <= 0.25
                ? Colors.red
                : _passwordStrength <= 0.5
                ? Colors.orange
                : _passwordStrength <= 0.75
                ? Colors.yellow
                : Colors.green,
          ),
        ),
        ),
        SizedBox(height: 20),

        _buildPassField(_confirmPasswordController, "Confirm Password", Icons.lock, true),
        SizedBox(height: 20),
        _isLoading
            ? CircularProgressIndicator()
        : Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildHoverButton("Back", Icons.arrow_circle_left, _previousStep),

            _buildHoverButton( "Confirm", Icons.check_circle, _nextStep, iconOnRight: true),
          ],
        ),
      ],
    );
  }
  bool _obscurePassword = true; // Initial state

  Widget _buildPassField(TextEditingController controller, String labelText,
      IconData icon, bool obscureText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: TextFormField(
        controller: controller,
        onChanged: (value) {
          if (labelText == "Password") {
            setState(() {
              _passwordStrength = _calculatePasswordStrength(value);
            });
          }
        },
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.6)),
          suffixIcon:
          IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.black.withOpacity(0.6),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        obscureText: _obscurePassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $labelText';
          }
          if (labelText == "Confirm Password" &&
              value != _passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      IconData icon, bool obscureText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your $labelText';
            }
            return null;
          },
      ),
    );
  }
  Widget _buildHoverButton(String text, IconData icon, VoidCallback onPressed, {bool iconOnRight = false}) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        // Custom hover effect
      }),
      onExit: (_) => setState(() {
        // Revert hover effect
      }),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF8478CC), // Background color
          foregroundColor: Colors.white, // Text color
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: TextStyle(fontSize: 16),
          elevation: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconOnRight
              ? [
            Text(text),
            SizedBox(width: 8), // Space between text and icon
            Icon(icon),
          ]
              : [
            Icon(icon),
            SizedBox(width: 8), // Space between icon and text
            Text(text),
          ],
        ),
      ),
    );
  }

  double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
}
