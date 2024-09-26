
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime_type/mime_type.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          onPrimary: Colors.white,
          secondary: Colors.deepPurpleAccent,
          onSecondary: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.deepPurple.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple,
          ),
        ),
      ),
      home: const MyHomePage(title: 'Registration and ListView Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final UserFormData _userFormData = UserFormData();
  final List<String> _cities = ['City 1', 'City 2', 'City 3', 'City 4'];
  final List<String> _books = ['Book 1', 'Book 2', 'Book 3', 'Book 4', 'Book 5'];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _userFormData.currentPosition = position;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _userFormData.profilePhoto = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_userFormData.currentPosition != null &&
          _isWithinLocation(
              _userFormData.currentPosition!.latitude,
              _userFormData.currentPosition!.longitude)) {

        final uri = Uri.parse('https://www.yourapiendpoint.com/submit'); // Replace with your API endpoint
        final request = http.MultipartRequest('POST', uri);

        // Add form fields
        request.fields['name'] = _userFormData.name ?? '';
        request.fields['gender'] = _userFormData.gender ?? '';
        request.fields['city'] = _userFormData.city ?? '';
        request.fields['email'] = _userFormData.email ?? '';
        request.fields['mobileNumber'] = _userFormData.mobileNumber ?? '';
        if (_userFormData.dateOfBirth != null) {
          request.fields['dateOfBirth'] = _userFormData.dateOfBirth!.toIso8601String();
        }

        // Add image file (Web uses a different approach)
        if (_userFormData.profilePhoto != null) {
          if (kIsWeb) {
            // For web
            final mimeType = mime(_userFormData.profilePhoto!.path) ?? 'application/octet-stream';
            final bytes = await _userFormData.profilePhoto!.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'profilePhoto',
              bytes,
              filename: _userFormData.profilePhoto!.path.split('/').last,
              contentType: MediaType.parse(mimeType),
            ));
          } else {
            // For Android & iOS
            final mimeType = mime(_userFormData.profilePhoto!.path) ?? 'application/octet-stream';
            final imageFile = await http.MultipartFile.fromPath(
              'profilePhoto',
              _userFormData.profilePhoto!.path,
              contentType: MediaType.parse(mimeType),
            );
            request.files.add(imageFile);
          }
        }

        // Send the request
        try {
          final response = await request.send();
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Form submitted successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to submit form')),
            );
          }
        } catch (e) {
          print(e);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error occurred during submission')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not within the allowed location')),
        );
      }
    }
  }

  bool _isWithinLocation(double lat, double lng) {
    const double predefinedLat = 37.422;
    const double predefinedLng = -122.084;
    const double maxDistanceInMeters = 500;

    double distance = Geolocator.distanceBetween(lat, lng, predefinedLat, predefinedLng);
    return distance <= maxDistanceInMeters;
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _userFormData.dateOfBirth = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    onSaved: (value) => _userFormData.name = value,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => _userFormData.gender = value,
                    validator: (value) => value == null ? 'Please select your gender' : null,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'City'),
                    items: _cities.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (value) => _userFormData.city = value,
                    validator: (value) => value == null ? 'Please select your city' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onSaved: (value) => _userFormData.email = value,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      } else if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                    onSaved: (value) => _userFormData.mobileNumber = value,
                  ),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date of Birth'),
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Text(
                        _userFormData.dateOfBirth == null
                            ? 'Select Date'
                            : _userFormData.dateOfBirth!.toLocal().toString().split(' ')[0],
                        style: TextStyle(
                          color: _userFormData.dateOfBirth == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Upload Profile Photo'),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Submit'),
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            // ListView section
            Text('Book List:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10.0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _books.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Text(_books[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UserFormData {
  String? name;
  String? gender;
  String? city;
  String? email;
  String? mobileNumber;
  DateTime? dateOfBirth;
  Position? currentPosition;
  File? profilePhoto;
}
