import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:flutter/material.dart';
// Dart client
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'http_requests.dart';

void main() {
  runApp(const MyApp());
}

late CameraController _controller;
bool initialized = false;

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() {
    return _MyAppState();
  }
}
List<CameraDescription> cameras = List.empty(growable: true);
String url = "";
class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeCamera();
  }

  _initializeCamera() async {
    await availableCameras().then((value) {
      cameras = value;
      print("Values are: " + value.toString());
    });

    _controller = CameraController(cameras[1], ResolutionPreset.max);
    _controller.initialize().then((value) {
      setState(() {
        initialized = true;
      });
    });

  }

  bool muteYUVProcessing = false;
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _controller.dispose();
  }

  static const shift = (0xFF << 24);
  Future<List<int>?> convertYUV420toImageColor(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int? uvPixelStride = image.planes[1].bytesPerPixel;

      print("uvRowStride: " + uvRowStride.toString());
      print("uvPixelStride: " + uvPixelStride.toString());

      // imgLib -> Image package from https://pub.dartlang.org/packages/image
      var img = imglib.Image(width, height); // Create Image buffer
      // Fill image buffer with plane[0] from YUV420_888
      for(int x=0; x < width; x++) {
        for(int y=0; y < height; y++) {
          final int uvIndex = uvPixelStride! * (x/2).floor() + uvRowStride*(y/2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          // Calculate pixel color
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 -vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          // color: 0x FF  FF  FF  FF
          //           A   B   G   R
          img.data[index] = shift | (b << 16) | (g << 8) | r;
        }
      }
      imglib.PngEncoder pngEncoder = new imglib.PngEncoder(level: 0, filter: 0);
      List<int> png = pngEncoder.encodeImage(img);
      muteYUVProcessing = false;
      return png;
    } catch (e) {
      print(">>>>>>>>>>>> ERROR:" + e.toString());
    }
    return null;
  }

  bool got=false;
  // late Uint8List a;
  String status = "None";
  bool stopped = false;
  List<CameraImage> frames = new List.empty(growable: true);
  int responses=0;


  start_requests() async
  {
    Iterator<CameraImage> it = frames.iterator;
    while(it.moveNext())
      {
            List<int>? i = await convertYUV420toImageColor(it.current);
            if(i != null)
            {
              String a = base64Encode(i);
              final response = await sendFile(a, url);
              print("Response: " + response.body);
              if(response.body == "Commands Executed")
                {
                  responses++;
                  setState(() {
                    status = "Generating Result..." + (responses*100/35).toString() + "%";
                  });
                }
              else if(response.body == "hello" || response.body == "thanks" || response.body == "I love you")
                {
                  setState(() {
                    status = "Result: " + response.body;
                  });
                }
            }
      }
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        home: Scaffold(
          appBar: AppBar(
            title: Text("Camera Stream"),
          ),
          body: Column(
            children: [
              Center(
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: initialized ? CameraPreview(_controller) : SizedBox(),
                ),
              ),
              Center(
                child: MaterialButton(
                  onPressed: (){
                    _controller.startImageStream((image) async {
                          if(frames.length < 35)
                          {
                            frames.add(image);
                            setState(() {
                              status = "Capturing";
                            });
                          }
                          else if(frames.length == 35)
                            {
                              if(!stopped)
                                {
                                  start_requests();
                                  setState(() {
                                    status = "Generating result .... 0%";
                                  });
                                  stopped = true;
                                  await _controller.stopImageStream();
                                  print("Stopped Stream");
                                  print(frames.length.toString());
                                }
                            }
                      // if(!sent)
                      //   {
                      //     sent = true;
                      //     Future<List<int>?> i = convertYUV420toImageColor(image);
                      //     i.then((value) async {
                      //       if(value != null)
                      //       {
                      //         print("3");
                      //         String a = base64Encode(value);
                      //         print(a);
                      //         final response = await sendFile(a, url);
                      //         Timer.periodic(Duration(seconds: 2), (timer){
                      //           sent = false;
                      //         });
                      //         print("Response: " + response.body);
                      //       }
                      //     });
                      //   }
                    });
                    // _controller.prepareForVideoRecording().then((value){
                    //   _controller.startVideoRecording();
                    // });
                  },
                  child: Text("Start"),
                ),
              ),
              Center(
                child: MaterialButton(
                  onPressed: () async {
                    _controller.stopImageStream();
                    // _controller.stopVideoRecording().then((value) {
                    //   value.readAsBytes().then((value) async {
                    //     print("Bytes: " + value.toString());
                    //     String base64string = base64Encode(value);
                    //     print("Base64: " + base64string);
                    //     final response = await sendFile(base64string);
                    //     print("Response: " + response.body);
                    //   });
                    // });
                  },
                  child: Text("Stop"),
                ),
              ),
              TextFormField(
                onChanged: (val) {
                  url = val;
                },
              ),
              SizedBox(height: 20,),
              Center(
                child: Text(status, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),),
              ),
              Center(
                child: status != "None" || status.contains("Generating") || status.contains("Capturing") ? CircularProgressIndicator() : SizedBox(),
              )
              // Center(
              //   child: Container(
              //     color: Colors.grey,
              //     height: 100,
              //     width: 100,
              //     child: a == null || a.isEmpty ? SizedBox() : Image.memory(a),
              //   ),
              // )
            ],
          ),
        )
    );
  }
}
