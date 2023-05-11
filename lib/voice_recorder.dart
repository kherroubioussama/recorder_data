import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({Key? key}) : super(key: key);

  @override
  _RecorderPageState createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  late String _selectedLanguage;
  late String _inputWord;

  @override
  void initState() {
    super.initState();
    initRecoder();
    _selectedLanguage = 'en'; // Default language
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future initRecoder() async {
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      throw 'Microphone permission not granted';
    }
    await _recorder.openRecorder();
  }

  Future record() async {
    await _recorder.startRecorder(toFile: 'audio');
  }

  Future stop() async {
    await _recorder.stopRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            DropdownButton<String>(
              value: _selectedLanguage,
              items: const [
                DropdownMenuItem(
                  value: 'ar',
                  child: Text('العربية'),
                ),
                DropdownMenuItem(
                  value: 'fr',
                  child: Text('Français'),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Enter word to record',
              ),
              onChanged: (value) {
                _inputWord = value.trim();
              },
            ),
            const SizedBox(height: 16),
            _isRecording
                ? const Text('Recording...')
                : const Text('Tap to start recording'),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isRecording = !_isRecording;
                  _toggleRecording();
                });
              },
              child:
                  _isRecording ? const Icon(Icons.stop) : const Icon(Icons.mic),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await record();
    } else {
      await stop();
      //await _recorder!.closeRecorder();
      await _uploadToDrive();
    }
  }
  Future<AuthClient> obtainAuthenticatedClient() async {

  AuthClient client = await clientViaMetadataServer();

  return client; // Remember to close the client when you are finished with it.
}
Future<File> _getLocalFile() async {
  final directory = await getApplicationDocumentsDirectory();
  final filename = '${DateTime.now().millisecondsSinceEpoch}.m4a';
  return File('${directory.path}/$filename');
}

  Future<void> _uploadToDrive() async {
    final scopes = [drive.DriveApi.driveScope];
    final account = await GoogleSignIn().signIn();
    final authHeaders = await account!.authHeaders;
    final httpcl = http.Client();
    final client = await obtainAuthenticatedClient();
    final driveApi = drive.DriveApi(client);
    final file = await _getLocalFile();
    final media = drive.Media(file.openRead(), file.lengthSync());

    // Create language folder if it doesn't exist
    final languageFolderName = _getLanguageName(_selectedLanguage);
    final languageFolder =
        await _createFolderIfNotExists(driveApi, languageFolderName);

    // Create word sub-folder if it doesn't exist
    final wordFolderName = _inputWord.toLowerCase().replaceAll(' ', '-');
    final wordFolder = await _createFolderIfNotExists(driveApi, wordFolderName,
        parents: [languageFolder.id!]);

    try {
      // Upload file to the word folder
      final driveFile = drive.File()
        ..name = _getFileName()
        ..parents = [wordFolder.id!];
      await driveApi.files.create(driveFile, uploadMedia: media);
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      debugPrint('Error uploading to Google Drive: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }
  Future<drive.File> _createFolderIfNotExists(drive.DriveApi driveApi, String name, {List<String>? parents}) async {
  final query = "mimeType='application/vnd.google-apps.folder' and trashed=false and name='$name'";
  final existingFolders = await driveApi.files.list(q: query);
  if (existingFolders.files!.isNotEmpty) {
    return existingFolders.files!.first;
  } else {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parents;
    return await driveApi.files.create(folder);
  }
}

String _getLanguageName(String languageCode) {
  switch (languageCode) {
    case 'ar':
      return 'Arabic';
    case 'fr':
      return 'French';
    default:
      return 'English';
  }
}

String _getFileName() {
  final now = DateTime.now();
  return '${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}.m4a';
}

}
