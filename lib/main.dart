import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detection/realtime/live_camera.dart';
List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(
    MaterialApp(
      home: MyApp(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
    )
  );
}
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Object Detector App"),
      ),
      body: Container(
        child:Center(
          child: SizedBox.expand(
            child: ElevatedButton(
              child: Text("START"),
              onPressed:() {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => LiveFeed(cameras),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}