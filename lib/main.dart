import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final List<File> images = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        backgroundColor: const Color.fromARGB(255, 216, 243, 255),
        appBar: AppBar(
          title: const Text('Polaroid Camera App',style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.blue.shade700,
        ),
        body: images.isEmpty
            ? const Center(child: Text('Tap the camera icon to take a picture',style: TextStyle(color: Color.fromARGB(255, 80, 41, 255)),))

           :GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 100 / 150, 
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: 80 / 100, 
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.file(
                            images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          width: double.infinity,
                          color: Colors.white,
                                    ),)
                                  ],
                                ),
                              );
                            },
                          ),
        floatingActionButton: Builder(
          builder: (context) =>               FloatingActionButton(
                backgroundColor: Colors.blue.shade700,
                onPressed: () async {
                  if (await _requestPermissions()) {
                    if (!mounted) return;
                    Future.microtask(() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras)),
                      ).then((image) async {
                        if (image != null) {
                          final File savedImage = await _saveImage(image);
                          if (mounted) {
                            setState(() {
                              images.add(savedImage);
                            });
                          }
                        }
                      });
                    });
                  }
                },
                child: const Icon(Icons.camera_alt, color: Colors.white),
                        ),
        ),
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission is required")),
      );
      return false;
    }
    return true;
  }

  Future<File> _saveImage(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final String imagePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File newImage = File(imagePath);
    return File(image.path).copy(newImage.path);
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Future<void> _initializeControllerFuture;
  int cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera(widget.cameras[cameraIndex]);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    if (await Permission.camera.request().isGranted) {
      try {
        controller = CameraController(camera, ResolutionPreset.medium);
        _initializeControllerFuture = controller.initialize();
        await _initializeControllerFuture;
        if (mounted) setState(() {});
      } catch (e) {
        print("Error initializing camera: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission is required")),
      );
    }
  }

  void _switchCamera() async {
    if (!controller.value.isInitialized) return;
    await controller.dispose();
    cameraIndex = (cameraIndex + 1) % widget.cameras.length;
    _initCamera(widget.cameras[cameraIndex]);
  }

  @override
  void dispose() {
    if (controller.value.isInitialized) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade100,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.blue.shade600,
            onPressed: _switchCamera,
            child: const Icon(Icons.switch_camera, color: Colors.white),
          ),
          FloatingActionButton(
            backgroundColor: Colors.blue.shade700,
            onPressed: () async {
              if (!controller.value.isInitialized) return;
              try {
                await _initializeControllerFuture;
                final image = await controller.takePicture();
                Navigator.pop(context, image);
              } catch (e) {
                print("Error capturing image: $e");
              }
            },
            child: const Icon(Icons.camera, color: Colors.white),
          ),
        ],
      ),
    );
  }
}