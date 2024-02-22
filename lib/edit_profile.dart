import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'mainPage.dart';
import 'profilePage.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late User? _user;
  late String profilePicture = '';
  late String Name = '';
  late String Email = '';
  File? _imageFile;
  bool _isLoadingImage = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  void initState() {
    _fetchUserProfile();
    // TODO: implement initState
    super.initState();
  }

  Future<void> _fetchUserProfile() async {
    final User? user = _auth.currentUser;
    print(user);

    if (user != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString('profilePicture') ?? '';
      final cachedName = prefs.getString('Name') ?? '';
      final cachedEmail = prefs.getString('Email') ?? '';

      // Fetch the user data from Firestore
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('doctors').doc(user.uid).get();

      if (userDoc.exists) {
        final fetchedUrl = userDoc['profilePicture'] ?? '';
        final fetchedName = userDoc['Name'] ?? '';
        final fetchedEmail = userDoc['Email'] ?? '';
        print('Fetched Profile Picture URL: $fetchedUrl'); // Debug print
        print('Fetched Name: $fetchedName'); // Debug print
        print('Fetched Email: $fetchedEmail'); // Debug print

        // Check if the cached URL matches the fetched URL
        if (cachedUrl != fetchedUrl) {
          // Cache the fetched URL locally
          prefs.setString('profilePicture', fetchedUrl);
        }

        // Check if the cached name matches the fetched name
        if (cachedName != fetchedName) {
          // Cache the fetched name locally
          prefs.setString('Name', fetchedName);
        }

        // Check if the cached Email matches the fetched Email
        if (cachedEmail != fetchedEmail) {
          // Cache the fetched Email locally
          prefs.setString('Email', fetchedEmail);
        }

        setState(() {
          profilePicture = fetchedUrl ?? ''; // Ensure it's not null
          Name = fetchedName ?? '';
          Email = fetchedEmail ?? '';
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    await _pickImage();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _imageFile != null) {
      try {
        // Show circular progress indicator
        showDialog(
          context: context,
          barrierDismissible: false, // To prevent tapping outside to dismiss
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('Profile Picture')
            .child(user.uid)
            .child('image.jpg');
        final uploadTask = storageRef.putFile(_imageFile!);
        final storageSnapshot = await uploadTask.whenComplete(() => null);
        final downloadUrl = await storageSnapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .update({'profilePicture': downloadUrl});

        // Hide circular progress indicator
        Navigator.pop(context);

        // Navigate to ProfilePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage()),
        );
      } catch (error) {
        print('Error uploading image: $error');
        // Hide circular progress indicator
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image')),
        );
      }
    }
  }

  Future _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  Future<void> _saveEditedName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .update({'Name': Name});

        // No need for the delay here

        Navigator.pop(context);

        // Navigate to ProfilePage after the update is complete
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Name updated successfully',
              textAlign: TextAlign.center,
            ),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (error) {
        print('Error updating name: $error');

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating name'),
          ),
        );
      }
    }
  }

  void _openEditNameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Name'),
          content: TextFormField(
            initialValue: Name,
            onChanged: (value) {
              setState(() {
                Name = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'New Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveEditedName();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  //For Password
  void _openEditPasswordDialog() {
    String currentPassword = '';
    String newPassword = '';
    String confirmPassword = '';
    bool passwordMismatch = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current Password
                  TextFormField(
                    obscureText: true,
                    onChanged: (value) {
                      currentPassword = value;
                      if (passwordMismatch &&
                          currentPassword.length == confirmPassword.length) {
                        setState(() {
                          passwordMismatch = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                    ),
                  ),
                  SizedBox(height: 10),

                  // New Password
                  TextFormField(
                    obscureText: true,
                    onChanged: (value) {
                      newPassword = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'New Password',
                    ),
                  ),
                  SizedBox(height: 10),

                  // Confirm Password
                  TextFormField(
                    obscureText: true,
                    onChanged: (value) {
                      confirmPassword = value;
                      if (currentPassword.length == confirmPassword.length &&
                          currentPassword != confirmPassword) {
                        setState(() {
                          passwordMismatch = true;
                        });
                      } else {
                        setState(() {
                          passwordMismatch = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      errorText:
                          passwordMismatch ? 'Passwords do not match' : null,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Validate the form before saving
                Navigator.pop(context);
                if (!passwordMismatch) {
                  // Save the edited password and close the dialog
                  _changePassword(currentPassword, newPassword);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Show circular progress indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // Reauthenticate user before changing password
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // Update password in Firebase Authentication
        await user.updatePassword(newPassword);

        // Hide circular progress indicator
        Navigator.pop(context);

        // Navigate to ProfilePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully'),
          ),
        );
      } catch (error) {
        print('Error changing password: $error');
        String errorMessage = 'Error changing password';

        if (error is FirebaseAuthException) {
          switch (error.code) {
            case 'wrong-password':
              errorMessage = 'Current password is incorrect';
              break;
            case 'requires-recent-login':
              errorMessage =
                  'This operation is sensitive and requires recent authentication. Please log in again before changing the password.';
              break;
            default:
              errorMessage = 'An error occurred while changing the password';
          }
        }

        // Hide circular progress indicator after the delay
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
              color: Colors.black, fontSize: 18, letterSpacing: 1),
        ),
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 42,
                      backgroundImage: (profilePicture.isNotEmpty)
                          ? NetworkImage(profilePicture)
                              as ImageProvider<Object>?
                          : null, // Don't specify any image here
                      child: (profilePicture.isEmpty)
                          ? Text(
                              generateInitials(Name),
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  color: Colors.white,
                                  letterSpacing: 1),
                            )
                          : null, // Show initials only if there's no image
                    ),
                    const SizedBox(height: 11),
                    Text(
                      Name,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Text(
                      Email,
                      softWrap: true,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.7),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Divider(
                  color: Colors.grey,
                  height: MediaQuery.of(context).size.height / 28,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildOptionTile('Edit Name', Icons.edit, () {
                      _openEditNameDialog();
                    }),
                    _buildOptionTile('Change Password', Icons.lock, () {
                      _openEditPasswordDialog();
                    }),
                    _buildOptionTile('Change Profile Picture', Icons.image, () {
                      _uploadImage();
                    }),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height / 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(String title, IconData icon, Function() onTap) {
    return ListTile(
      title: Text(title),
      trailing: Icon(
        icon,
        size: 18,
        // color: Colors.green.shade900,
      ),
      onTap: onTap,
    );
  }
}
