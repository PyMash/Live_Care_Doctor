import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'booked_doctor.dart';

class UserAppointmentDetails {
  final String documentId;
  final String userId;
  final String currentStatus;
  final DateTime dateTime;
  final UserDetails? userDetails;

  UserAppointmentDetails(this.documentId, this.userId, this.currentStatus,
      this.dateTime, this.userDetails);
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

String generateInitials(String name) {
  List<String> nameParts =
      name.split(' ').where((part) => part.isNotEmpty).toList();
  String initials = '';

  if (nameParts.isNotEmpty) {
    for (int i = 0; i < nameParts.length; i++) {
      initials += nameParts[i][0];
    }
  }

  return initials.toUpperCase();
}

class _HomePageState extends State<HomePage> {
  // Function to fetch featured doctors
  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('doctors')
        .where('rated', isEqualTo: '5')
        .get();

    return querySnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  String getGreeting() {
    DateTime now = DateTime.now();
    int hour = now.hour;

    if (hour >= 6 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserDetails?> fetchUserDetails(String userId) async {
    try {
      CollectionReference usersCollection = _firestore.collection('users');

      DocumentSnapshot userSnapshot = await usersCollection.doc(userId).get();

      if (userSnapshot.exists) {
        Map<String, dynamic>? data =
            userSnapshot.data() as Map<String, dynamic>?;

        if (data != null) {
          String name = data['Name'] as String? ?? '';
          String profilePicture = data['profilePicture'] as String? ?? '';

          return UserDetails(name, profilePicture);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching User Details: $e');
      return null;
    }
  }

  late String profilePictureUrl = '';
  late String displayName = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchAppointments(); // Add this line to fetch appointments
  }

  Future<void> _fetchAppointments() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final appointments = await fetchDoctorAppointments(user.uid);
        setState(() {
          this.appointments = appointments;
        });
      }
    } catch (e) {
      print('Error fetching appointments: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    final User? user = _auth.currentUser;
    print(user);

    if (user != null) {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('doctors').doc(user.uid).get();

      if (userDoc.exists) {
        final fetchedUrl = userDoc['profilePicture'] ?? '';
        print('Fetched Profile Picture URL: $fetchedUrl'); // Debug print
        // print(userDoc['Name']);
        setState(() {
          profilePictureUrl = fetchedUrl ?? ''; // Ensure it's not null
          displayName = userDoc['Name'] ?? '';
        });
      }
    }
  }

  List<UserAppointmentDetails> appointments = [];

  // Function to generate initials from the name
  Future<List<UserAppointmentDetails>> fetchDoctorAppointments(
      String doctorUid) async {
    List<UserAppointmentDetails> appointments = [];

    try {
      CollectionReference doctorCollection = _firestore.collection('doctors');
      CollectionReference appointmentCollection =
          doctorCollection.doc(doctorUid).collection('BookedAppointment');

      QuerySnapshot querySnapshot = await appointmentCollection.get();

      for (QueryDocumentSnapshot<Object?> docSnapshot in querySnapshot.docs) {
        if (docSnapshot.exists) {
          String documentId = docSnapshot.id;
          Map<String, dynamic>? data =
              docSnapshot.data() as Map<String, dynamic>?;

          if (data != null) {
            String userId = data['PatientId'] as String? ?? '';
            String currentStatus = data['CurrentStatus'] as String? ?? '';

            UserDetails? userDetails = await fetchUserDetails(userId);

            UserAppointmentDetails userAppointmentDetails =
                UserAppointmentDetails(documentId, userId, currentStatus,
                    DateTime.now(), userDetails);
            appointments.add(userAppointmentDetails);
          }
        }
      }

      return appointments;
    } catch (e) {
      print('Error fetching Doctor Appointments: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.cyan.shade300,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${getGreeting()},',
                              style: GoogleFonts.redHatDisplay(
                                letterSpacing: 1,
                                color: Colors.white,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.04,
                              ),
                            ),
                            Text(
                              "Dr. " + displayName,
                              style: GoogleFonts.redHatDisplay(
                                letterSpacing: 1,
                                color: Colors.white,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.05,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 22,
                            backgroundImage: (profilePictureUrl.isNotEmpty)
                                ? NetworkImage(profilePictureUrl)
                                    as ImageProvider<Object>?
                                : null, // Don't specify any image here
                            child: (profilePictureUrl.isEmpty)
                                ? Text(
                                    generateInitials(displayName),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.black,
                                      letterSpacing: 1,
                                    ),
                                  )
                                : null, // Show initials only if there's no image
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        Text(
                          'Current Status: ',
                          style: GoogleFonts.redHatDisplay(
                              letterSpacing: 1,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                        Text(
                          'Online',
                          style: GoogleFonts.redHatDisplay(
                              letterSpacing: 1,
                              fontWeight: FontWeight.w500,
                              color: Colors.black),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: 25,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Let\'s Make',
                              style: GoogleFonts.montserrat(
                                letterSpacing: 0.5,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.04,
                              ),
                            ),
                            Text(
                              'Someones life better',
                              style: GoogleFonts.montserrat(
                                letterSpacing: 1.0,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white, // Set background color to white
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              child: Text(
                                'Your Appointments',
                                style: GoogleFonts.poppins(
                                  letterSpacing: 0.5,
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: appointments.isEmpty
                                      ? Center(
                                          child: Text('No appointments found'),
                                        )
                                      : ListView.builder(
                                          itemCount: appointments.length,
                                          itemBuilder: (context, index) {
                                            var appointment =
                                                appointments[index];
                                            var userName =
                                                appointment.userDetails?.name ??
                                                    '';
                                            var dateTime = appointment.dateTime;

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          DoctorAppointments(),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5)),
                                                  alignment: Alignment.center,
                                                  child: ListTile(
                                                    title: Text(
                                                      userName.toUpperCase(),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    subtitle: Text(
                                                      '${DateFormat('dd MMM yyyy').format(dateTime)} at ${DateFormat('HH:mm').format(dateTime)}',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Text(
                          "**For more information, tap the patient's name",
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            letterSpacing: 1,
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            // fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
