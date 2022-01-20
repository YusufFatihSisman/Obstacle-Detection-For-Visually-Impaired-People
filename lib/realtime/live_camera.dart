import 'dart:async';
import 'dart:math';
import 'package:async/async.dart';
import 'package:aeyrium_sensor/aeyrium_sensor.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detection/realtime/bounding_box.dart';
import 'package:object_detection/realtime/camera.dart';
import 'dart:math' as math;
import 'package:tflite/tflite.dart';

double stop = 0.3;
double person = 1.7;
double bicycle = 1.05;
double bus = 3.5;
double truct = 4.5;
double car = 1.5;
double motorbike = 1.12;
double cone = 0.4;
double bin = 1.4;
double dog = 0.6;
double tricycle = 1.6;
double fire = 1;

double warning = 0.2;
double sphere = 0.3;
double pole = 0.2;


class LiveFeed extends StatefulWidget {
  final List<CameraDescription> cameras;
  LiveFeed(this.cameras);
  @override
  _LiveFeedState createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  List<dynamic> _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;

  StreamSubscription<dynamic> _sensor;
  RestartableTimer _timer;
  double _height;
  double _width; 
  double _pitch;
  AudioCache _audioCache = AudioCache();
  //final assetsAudioPlayer = AssetsAudioPlayer();


  initCameras() async {

  }
  loadTfModel() async {
    await Tflite.loadModel(
      model: "assets/models/yolov2-tiny_custom.tflite",
      labels: "assets/models/classes.txt",
    );
  }
  /* 
  The set recognitions function assigns the values of recognitions, imageHeight and width to the variables defined here as callback
  */
  setRecognitions(recognitions, imageHeight, imageWidth) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  List<dynamic> obstaclesInFront(){
    List<dynamic> obstacles = [];
    double leftBorder = _width/3;
    double rightBorder = leftBorder*2;
    double objLeft;
    double objRight;
    for(int i = 0; i < _recognitions.length; i++){
      objLeft = _recognitions[i]["rect"]["x"]*_width;
      objRight = objLeft + _recognitions[i]["rect"]["w"]*_width;
      if(!(objLeft > rightBorder || objRight < leftBorder)){
        obstacles.add(_recognitions[i]);
      }
    }
    return obstacles;
  }

  int closestObstacle(List<dynamic> obstacles){
    int minIndex = 0;
    double minValue;
    double comparedValue;
    minValue = obstacles[minIndex]["rect"]["y"]*_height;
    minValue += obstacles[minIndex]["rect"]["h"]*_height;
    for(int i = 1; i < obstacles.length; i++){
      comparedValue = obstacles[i]["rect"]["y"]*_height;
      comparedValue += obstacles[i]["rect"]["h"]*_height;
      if(minValue < comparedValue){
        minIndex = i;
        minValue = comparedValue;
      }
    }
    return minIndex;
  }

  double realDiff(double difference, dynamic obstacle){
    double realSize = 0;
    if(obstacle["detectedClass"] == "warning_column" 
    || obstacle["detectedClass"] == "spherical_roadblock" 
    || obstacle["detectedClass"] == "pole"){
      if(obstacle["detectedClass"] == "warning_column")
        realSize = warning;
      else if(obstacle["detectedClass"] == "pole")
        realSize = pole;
      else
        realSize = sphere;
      return difference * (realSize / (obstacle["rect"]["w"]*_width));
    }else{
      if(obstacle["detectedClass"] == "person")
        realSize = person;
      else if(obstacle["detectedClass"] == "car")
        realSize = car;
      else if(obstacle["detectedClass"] == "stop_sign")
        realSize = stop;
      else if(obstacle["detectedClass"] == "bicycle")
        realSize = bicycle;
      else if(obstacle["detectedClass"] == "bus")
        realSize = bus;
      else if(obstacle["detectedClass"] == "truck")
        realSize = truct;
      else if(obstacle["detectedClass"] == "motorbike")
        realSize = motorbike;
      else if(obstacle["detectedClass"] == "reflective_cone")
        realSize = cone;
      else if(obstacle["detectedClass"] == "ashcan")
        realSize = bin;
      else if(obstacle["detectedClass"] == "dog")
        realSize = dog;
      else if(obstacle["detectedClass"] == "tricycle")
        realSize = tricycle;
      else if(obstacle["detectedClass"] == "fire_hydrant")
        realSize = fire;
      return difference * (realSize / (obstacle["rect"]["h"]*_height));
    }
  }

  int calculateDistance(dynamic obstacle, double angle){
    double bottomObstacle = obstacle["rect"]["y"]*_height;
    bottomObstacle += obstacle["rect"]["h"]*_height;
    double difference;

    if(bottomObstacle < _height/2 + _height/10 && bottomObstacle > _height/2 - _height/10){
      difference = _height/2 - bottomObstacle;
      difference = realDiff(difference, obstacle);
      print("difference : " + difference.toString());
      return ((1.5 + difference) * tan(angle)).round();
    }
    return -1;
  }

  bool isMoving(String type){
    if(type == "car" || type == "person" || type == "bicycle" || type == "bust" 
    || type == "truck" || type == "motorbike" || type == "dog" || type == "tricycle"){
      return true;
    }
    return false;
  }

  void control(){
    List<dynamic> obstacles = obstaclesInFront();
    double ang = 1.57 + _pitch;
    int closest;
    int distance = -1;
    if(obstacles.length != 0){
      closest = closestObstacle(obstacles);
      if(_pitch <= 0 && _pitch >= -1.5){
        distance = calculateDistance(obstacles[closest], ang);
      }
      if(distance != -1){
        playSoundDistance(distance);
      }else{
        playSoundKind(isMoving(obstacles[closest]["detectedClass"]));
      }
    }
  }

  int roundDistance(int distance){
    int ones = distance % 10;
    if(ones == 1 || ones == 2){
      return distance - ones;
    }else if(ones == 3 || ones == 4){
      return distance + (5 - ones);
    }else{
      return distance;
    }
  }

  void playSoundDistance(int distance){
    if(distance > 10)
      distance = roundDistance(distance);
    _audioCache.play("audio/" + distance.toString() + "m.mp3");
  }

  void playSoundKind(bool moving){
    if(moving)
      _audioCache.play("audio/movingobject.mp3");
    else
      _audioCache.play("audio/obstacle.mp3");
  }

  @override
  void initState() { 
    super.initState();
    loadTfModel();
    _sensor = AeyriumSensor.sensorEvents.listen((event) {
      _pitch = event.pitch; 
    });
    _timer = RestartableTimer(Duration(seconds:4), (){
      if(_recognitions != null){
        control();
      }
      _timer.reset();
    });
  }
  
  @override
  void dispose(){
    _sensor?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    _height = screen.height;
    _width = screen.width;
    return Scaffold(
      body: GestureDetector(
        child : Stack(
          children: <Widget>[
            CameraFeed(widget.cameras, setRecognitions),
            BoundingBox(
              _recognitions == null ? [] : _recognitions,
              math.max(_imageHeight, _imageWidth),
              math.min(_imageHeight, _imageWidth),
              screen.height,
              screen.width,
            ),
          ],
        ),
        onTap: () {
          control();
          _timer.reset();
        },
      ),
    );
  }
}