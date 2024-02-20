import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:live_care/chat_screen.dart';

class DoctorAppointments extends StatefulWidget {
  const DoctorAppointments({Key? key}) : super(key: key);

  @override
  _DoctorAppointmentsState createState() => _DoctorAppointmentsState();
}

class UserAppointmentDetails {
  final String documentId;
  final String userId;
  final String currentStatus;
  final DateTime dateTime;
  UserDetails? userDetails;

  UserAppointmentDetails(this.documentId, this.userId, this.currentStatus,
      this.dateTime, this.userDetails);
}

class UserDetails {
  final String name;
  final String profilePicture;

  UserDetails(this.name, this.profilePicture);
}

class _DoctorAppointmentsState extends State<DoctorAppointments> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserAppointmentDetails> userAppointmentsWithDetails = [];

  @override
  void initState() {
    super.initState();
    fetchDD();
  }

  Future<void> fetchDD() async {
    try {
      final User? user = _auth.currentUser;
      List<UserAppointmentDetails> userAppointmentDetailsList =
          await fetchBookedAppointmentsWithUserDetails(user!.uid);

      setState(() {
        userAppointmentsWithDetails = userAppointmentDetailsList;
      });
    } catch (e) {
      // Handle errors here (print or throw)
      print('Error fetching Booked Appointments with User Details: $e');
    }
  }

  Future<List<UserAppointmentDetails>> fetchBookedAppointmentsWithUserDetails(
      String doctorUid) async {
    List<UserAppointmentDetails> userAppointmentDetailsList = [];

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
            String dateString = data['DateTime'] as String? ?? '';

            DateTime dateTime = dateString.isNotEmpty
                ? DateFormat('yyyy-MM-dd HH:mm').parse(dateString)
                : DateTime(0);
            UserDetails? userDetails = await fetchUserDetails(userId);

            UserAppointmentDetails userAppointmentDetails =
                UserAppointmentDetails(
                    documentId, userId, currentStatus, dateTime, userDetails);
            userAppointmentDetailsList.add(userAppointmentDetails);
          }
        }
      }

      return userAppointmentDetailsList;
    } catch (e) {
      print('Error fetching Booked Appointments with User Details: $e');
      return [];
    }
  }

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

  Future<void> updateAppointmentStatus(String doctorUid, String userId,
      String appointmentId, String status) async {
    try {
      CollectionReference doctorCollection = _firestore.collection('doctors');
      CollectionReference userCollection = _firestore.collection('users');

      // Update status on doctor side
      await doctorCollection
          .doc(doctorUid)
          .collection('BookedAppointment')
          .doc(appointmentId)
          .update({'CurrentStatus': status});

      // Update status on user side
      await userCollection
          .doc(userId)
          .collection('BookedAppointment')
          .doc(doctorUid)
          .update({'CurrentStatus': status});

      // Refresh the appointment list
      await fetchDD();
    } catch (e) {
      print('Error updating appointment status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Appointments',
          style: GoogleFonts.poppins(letterSpacing: 1),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ListView.builder(
          itemCount: userAppointmentsWithDetails.length,
          itemBuilder: (context, index) {
            var userAppointmentDetails = userAppointmentsWithDetails[index];
            var userName = userAppointmentDetails.userDetails?.name ?? '';
            var profilePictureUrl =
                userAppointmentDetails.userDetails?.profilePicture ?? '';
            var dateTime = userAppointmentDetails.dateTime;
            var currentStatus = userAppointmentDetails.currentStatus;

            // Determine the button text and functionality based on the current status
            Widget actionButton;
            if (currentStatus == 'Requested') {
              actionButton = Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Accept appointment
                      updateAppointmentStatus(
                          _auth.currentUser!.uid, // Doctor UID
                          userAppointmentDetails.userId,
                          userAppointmentDetails.documentId,
                          'Accepted');
                    },
                    child: Text(
                      'Accept',
                      style: GoogleFonts.poppins(
                          letterSpacing: 1, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Reject appointment
                      updateAppointmentStatus(
                          _auth.currentUser!.uid, // Doctor UID
                          userAppointmentDetails.userId,
                          userAppointmentDetails.documentId,
                          'Rejected');
                    },
                    child: Text(
                      'Reject',
                      style: GoogleFonts.poppins(
                          letterSpacing: 1, color: Colors.black),
                    ),
                  ),
                ],
              );
            } else if (currentStatus == 'Accepted') {
              actionButton = ElevatedButton(
                onPressed: () {
                  String chatid = userAppointmentDetails.userId.toString();
                  chatid += _auth.currentUser!.uid.toString();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatPage(chatDocumentId: chatid,name: userName,),
                    ),
                  );
                  // Action to start chat with patient
                  // Add your logic here
                },
                child: Text(
                  'Chat with Patient',
                  style: GoogleFonts.poppins(
                      letterSpacing: 1, color: Colors.black),
                ),
              );
            } else {
              // For status 'Rejected'
              actionButton = SizedBox(); // No button needed for rejected status
            }

            // Determine the card color based on the current status
            Color cardColor =
                currentStatus == 'Rejected' ? Colors.red : Colors.cyan.shade300;

            return Card(
              color: cardColor,
              margin: EdgeInsets.all(8.0),
              child: Container(
                height: 180,
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Patient Name: ${userName.toUpperCase()}",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                            letterSpacing: 1,
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Appointment Time: ${DateFormat('HH:mm').format(dateTime)}',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Appointment Date: ${DateFormat('dd MMM yyyy').format(dateTime)}',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Current Status: $currentStatus',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        actionButton,
                      ],
                    ),
                    SizedBox(
                      width: 20,
                    ),
                    profilePictureUrl.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(profilePictureUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        : SizedBox(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
