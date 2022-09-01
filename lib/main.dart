import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meetups/http/web.dart';
import 'package:meetups/screens/events_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/device.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: String.fromEnvironment("FIREBASE_APIKEY"),
          appId: String.fromEnvironment("FIREBASE_APPID"),
          messagingSenderId:
              String.fromEnvironment("FIREBASE_MESSAGINGSENDERID"),
          projectId: String.fromEnvironment("FIREBASE_PROJECTID")));

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permission granted by user: ${settings.authorizationStatus}');
    _startPushNotificationsHandler(messaging);
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print(
        'Permission (provisional) granted by user: ${settings.authorizationStatus}');
    _startPushNotificationsHandler(messaging);
  } else {
    print('Permission not granted by user');
  }

  runApp(App());
}

void showMyDialog(String message) {
  Widget okButton = OutlinedButton(
      onPressed: () => Navigator.pop(navigatorKey.currentContext!),
      child: Text('Ok!'));

  AlertDialog alert = AlertDialog(
    title: Text('Promoção Imperdível!'),
    content: Text(message),
    actions: [okButton],
  );

  showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return alert;
      });
}

void _startPushNotificationsHandler(FirebaseMessaging messaging) async {
  String? token = await messaging.getToken(
      vapidKey: String.fromEnvironment("FIREBASE_VAPIDKEY"));
  print('TOKEN: $token');
  _setPushToken(token);

  //Foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received message while on foreground');
    print('Data: ${message.data}');

    if (message.notification != null) {
      print(
          'Message has notification: ${message.notification!.title}, ${message.notification!.body}');
    }
  });

  //Background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //Terminated
  var data = await FirebaseMessaging.instance.getInitialMessage();

  if (data!.data['message'].length > 0) {
    showMyDialog(data.data['message']);
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Received message while on background');
  print('Data: ${message.data}');

  if (message.notification != null) {
    print(
        'Message has notification: ${message.notification!.title}, ${message.notification!.body}');
  }
}

void _setPushToken(String? token) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prefsToken = prefs.getString('pushToken');
  bool? prefSent = prefs.getBool('tokenSent');

  if (prefsToken != token || (prefsToken == token) && prefSent == false) {
    print('Sending token to server...');

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String? brand;
    String? model;

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Running at ${androidInfo.model}');

      model = androidInfo.model;
      brand = androidInfo.brand;
    } else {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      print('Running at ${iosInfo.utsname.machine}');

      model = iosInfo.utsname.machine;
      brand = 'Apple';
    }

    Device device = Device(brand: brand, model: model, token: token);

    sendDevice(device);
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dev meetups',
      home: EventsScreen(),
      navigatorKey: navigatorKey,
    );
  }
}
