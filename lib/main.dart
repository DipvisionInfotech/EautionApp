import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/about_us_page.dart';
import 'pages/auction_page.dart';
import 'pages/classified_page.dart';
import 'pages/contact_us_page.dart';
import 'pages/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seal The Deal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardPage(),
        '/about-us': (context) => const AboutUsPage(),
        '/auction': (context) => const AuctionPage(),
        '/classified': (context) => const ClassifiedPage(),
        '/contact-us': (context) => const ContactUsPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}
