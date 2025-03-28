import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController url = TextEditingController();
  double? _progress;
  bool _isDownloading = false;
  String _status = '';
  String? _filePath;
  bool _showActionButton = false;
  bool _isDownloaded = false;

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    url.addListener(_updateActionButtonVisibility);
  }

  @override
  void dispose() {
    url.removeListener(_updateActionButtonVisibility);
    url.dispose();
    super.dispose();
  }

  void _updateActionButtonVisibility() {
    setState(() {
      _showActionButton = url.text.trim().isNotEmpty;
    });
  }

  String getFileNameFromUrl(String url) {
    Uri uri = Uri.parse(url);
    String fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : "downloaded_file";
    if (!fileName.contains('.')) {
      fileName += '.pdf';
    }
    return fileName;
  }

  Future<String> getDownloadDirectory() async {
    Directory? directory = await getExternalStorageDirectory();
    if (directory != null) {
      return directory.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xff17202E),
        appBar: AppBar(
          backgroundColor: const Color(0xff17202E),
          title: Text(
            'File Downloader',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16, top: 56, bottom: 32),
          child: Column(
            children: [
              Hero(
                tag: 'splash',
                child: SvgPicture.asset('assets/1.svg', height: 222, width: 222),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0, top: 20),
                child: Text(
                  'Download any file!',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 30),
                ),
              ),
              TextField(
                style: const TextStyle(color: Colors.white),
                controller: url,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff111827).withOpacity(0.5),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      url.clear();
                      setState(() {
                        _progress = null;
                        _status = '';
                        _filePath = null;
                        _showActionButton = false;
                        _isDownloaded = false;
                      });
                    },
                    child: const Icon(Icons.clear, color: Color(0xff9CA2AE)),
                  ),
                  hintText: 'Enter URL here',
                  hintStyle: const TextStyle(color: Color(0xff9CA2AE)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff384150)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff384150)),
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 40),
              const Spacer(),

              if (_progress != null)
                Column(
                  children: [
                    CircularProgressIndicator(value: _progress),
                    const SizedBox(height: 10),
                    Text(
                      'Downloading: ${(_progress! * 100).clamp(1, 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ],
                ),
              const SizedBox(height: 30),

              if (_showActionButton)
                GestureDetector(
                  onTap: !_isDownloading && !_isDownloaded ? _startDownload : (_isDownloaded ? _openFile : null),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xff2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _isDownloaded ? 'Open File' : 'Download',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              if (_status.isNotEmpty)
                Text(
                  _status,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _status = '';
      _filePath = null;
    });

    String fileName = getFileNameFromUrl(url.text.trim());
    String dirPath = await getDownloadDirectory();
    String fullPath = '$dirPath/$fileName';

    FileDownloader.downloadFile(
      url: url.text.trim(),
      name: fileName,
      downloadDestination: DownloadDestinations.publicDownloads,
      onProgress: (name, progress) {
        setState(() {
          _progress = progress;
        });
      },
      onDownloadCompleted: (path) {
        setState(() {
          _progress = null;
          _isDownloading = false;
          _status = '';
          _filePath = path;
          _isDownloaded = true;
        });
      },
      onDownloadError: (errorMessage) {
        setState(() {
          _progress = null;
          _isDownloading = false;
          _status = 'Download failed: $errorMessage';
          _isDownloaded = false;
        });
      },
    );
  }

  void _openFile() async {
    if (_filePath == null || _filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path is empty!')),
      );
      return;
    }

    File file = File(_filePath!);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File does not exist!')),
      );
      return;
    }

    try {
      final result = await OpenFile.open(_filePath!);
      if (result.type == ResultType.done) {
        setState(() {
          url.clear();
          _isDownloaded = false;
          _filePath = null;
          _showActionButton = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open file: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }
}