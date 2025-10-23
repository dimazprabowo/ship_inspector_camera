import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AddNoteDialog extends StatefulWidget {
  final String? initialNote;
  final String title;
  final String? photoInfo; // Info foto (e.g., "Foto 1 dari 5")
  final String? itemTitle; // Nama item inspeksi

  const AddNoteDialog({
    super.key,
    this.initialNote,
    this.title = 'Tambah Catatan',
    this.photoInfo,
    this.itemTitle,
  });

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  late TextEditingController _controller;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  String _textBeforeSpeech = ''; // Store text before speech starts
  Timer? _silenceTimer; // Timer for auto-off when no speech detected

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          setState(() => _isListening = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.errorMsg}')),
            );
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      print('Speech init error: $e');
    }
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening) {
        _stopListening();
      }
    });
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      // Request microphone permission
      final status = await Permission.microphone.request();
      
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin mikrofon diperlukan untuk voice input'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Save current text before starting speech
      _textBeforeSpeech = _controller.text;
      setState(() => _isListening = true);
      
      // Start silence timer
      _startSilenceTimer();
      
      await _speech.listen(
        onResult: (result) {
          // Reset silence timer on each result
          _startSilenceTimer();
          
          setState(() {
            _lastWords = result.recognizedWords;
            // Combine text before speech with new recognized words
            if (_textBeforeSpeech.isEmpty) {
              _controller.text = _lastWords;
            } else {
              _controller.text = '$_textBeforeSpeech $_lastWords';
            }
            // Auto-scroll to end (show new text)
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          
          // Ensure cursor is visible after text update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller.text.isNotEmpty) {
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            }
          });
        },
        localeId: 'id_ID', // Indonesian
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
        listenFor: const Duration(seconds: 30), // Max 30 seconds per session
        pauseFor: const Duration(seconds: 3), // Auto-stop after 3 seconds silence
      );
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title),
          if (widget.itemTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.itemTitle!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (widget.photoInfo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.photoInfo!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140, // Fixed height untuk 5 lines
              child: Stack(
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ketik atau gunakan voice input...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.fromLTRB(12, 12, 50, 12),
                    ),
                    maxLines: 5,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {}); // Refresh to show/hide clear button
                    },
                  ),
                  // Icon column di pojok kanan
                  Positioned(
                    right: 4,
                    top: 4,
                    bottom: 4,
                    child: SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Clear button (pojok kanan atas)
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _controller.clear();
                                });
                              },
                              tooltip: 'Hapus teks',
                            )
                          else
                            const SizedBox(height: 36),
                          // Microphone button (pojok kanan bawah)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : (_speechAvailable ? Colors.blue : Colors.grey),
                              size: 20,
                            ),
                            onPressed: _speechAvailable ? _toggleListening : null,
                            tooltip: _isListening ? 'Stop Recording' : 'Voice Input',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isListening)
              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mendengarkan... ${_lastWords.isNotEmpty ? '"$_lastWords"' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (!_isListening)
              Text(
                _speechAvailable
                    ? 'Klik icon mikrofon untuk voice input. Catatan bisa dikosongkan untuk menghapus.'
                    : 'Voice input tidak tersedia. Pastikan ada koneksi internet.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        // if (widget.initialNote != null && widget.initialNote!.isNotEmpty)
        //   TextButton(
        //     onPressed: () => Navigator.pop(context, ''),
        //     style: TextButton.styleFrom(foregroundColor: Colors.red),
        //     child: const Text('Hapus Catatan'),
        //   ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
