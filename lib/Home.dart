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

class _DownloadItem {
  final String url;
  double? progress;
  String status = '';
  String? filePath;
  bool isDownloading = false;
  bool isDownloaded = false;

  _DownloadItem({required this.url});
}

class _HomeState extends State<Home> {
  final TextEditingController urlController = TextEditingController();
  final List<_DownloadItem> _downloadItems = [];
  bool _showActionButton = false;

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
    urlController.addListener(_updateActionButtonVisibility);
  }

  @override
  void dispose() {
    urlController.removeListener(_updateActionButtonVisibility);
    urlController.dispose();
    super.dispose();
  }

  void _updateActionButtonVisibility() {
    setState(() {
      _showActionButton = urlController.text.trim().isNotEmpty;
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

  void _addDownload() {
    final url = urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _downloadItems.add(_DownloadItem(url: url));
        urlController.clear();
        _showActionButton = false;
      });
    }
  }

  void _startDownload(int index) async {
    final item = _downloadItems[index];

    setState(() {
      item.isDownloading = true;
      item.progress = 0.0;
      item.status = '';
      item.filePath = null;
    });

    String fileName = getFileNameFromUrl(item.url);
    String dirPath = await getDownloadDirectory();
    String fullPath = '$dirPath/$fileName';

    FileDownloader.downloadFile(
      url: item.url,
      name: fileName,
      downloadDestination: DownloadDestinations.publicDownloads,
      onProgress: (name, progress) {
        setState(() {
          item.progress = progress;
        });
      },
      onDownloadCompleted: (path) {
        setState(() {
          item.progress = null;
          item.isDownloading = false;
          item.status = '';
          item.filePath = path;
          item.isDownloaded = true;
        });
      },
      onDownloadError: (errorMessage) {
        setState(() {
          item.progress = null;
          item.isDownloading = false;
          item.status = 'Download failed: $errorMessage';
          item.isDownloaded = false;
        });
      },
    );
  }

  void _startAllDownloads() {
    for (int i = 0; i < _downloadItems.length; i++) {
      if (!_downloadItems[i].isDownloading && !_downloadItems[i].isDownloaded) {
        _startDownload(i);
      }
    }
  }

  void _openFile(int index) async {
    final item = _downloadItems[index];
    if (item.filePath == null || item.filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path is empty!')),
      );
      return;
    }

    File file = File(item.filePath!);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File does not exist!')),
      );
      return;
    }

    try {
      final result = await OpenFile.open(item.filePath!);
      if (result.type != ResultType.done) {
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

  void _removeDownloadItem(int index) {
    setState(() {
      _downloadItems.removeAt(index);
    });
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
            'Multi-File Downloader',
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
          padding: const EdgeInsets.only(left: 16.0, right: 16, top: 16, bottom: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'splash',
                child: SvgPicture.asset('assets/1.svg', height: 222, width: 222),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, top: 8),
                child: Text(
                  'Download multiple files!',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 24),
                ),
              ),
              TextField(
                style: const TextStyle(color: Colors.white),
                controller: urlController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff111827).withOpacity(0.5),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      urlController.clear();
                      setState(() {
                        _showActionButton = false;
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showActionButton ? _addDownload : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Add'),
                ),
              ),
              if (_downloadItems.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _downloadItems.length,
                    itemBuilder: (context, index) {
                      final item = _downloadItems[index];
                      return Card(
                        color: const Color(0xff111827).withOpacity(0.5),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            getFileNameFromUrl(item.url),
                            style: GoogleFonts.inter(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.url,
                                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.progress != null)
                                LinearProgressIndicator(
                                  value: item.progress,
                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff2563EB)),
                                ),
                              if (item.status.isNotEmpty)
                                Text(
                                  item.status,
                                  style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!item.isDownloading && !item.isDownloaded)
                                IconButton(
                                  icon: const Icon(Icons.download, color: Color(0xff2563EB)),
                                  onPressed: () => _startDownload(index),
                                ),
                              if (item.isDownloaded)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: Colors.green),
                                  onPressed: () => _openFile(index),
                                ),
                              if (!item.isDownloading)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeDownloadItem(index),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_downloadItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: _startAllDownloads,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Download All',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _downloadItems.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}