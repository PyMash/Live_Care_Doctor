import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_care/Auth/main_page_auth.dart';
import 'package:live_care/doctor_details._page.dart';
import 'package:live_care/home_page.dart';
import 'package:live_care/login_page.dart';
import 'package:live_care/mainPage.dart';

import 'signup_doctor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageAuth(),
    );
  }
}
