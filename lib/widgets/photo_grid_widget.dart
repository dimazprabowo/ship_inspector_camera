import 'package:flutter/material.dart';
import 'dart:io';
import '../models/inspection_photo.dart';
import '../services/database_helper.dart';
import '../widgets/add_note_dialog.dart';

class PhotoGridWidget extends StatefulWidget {
  final List<InspectionPhoto> photos;
  final Function(InspectionPhoto) onDeletePhoto;
  final Key? refreshKey; // Add refresh key to force reload
  final String? itemTitle; // Nama item inspeksi

  const PhotoGridWidget({
    super.key,
    required this.photos,
    required this.onDeletePhoto,
    this.refreshKey,
    this.itemTitle,
  });

  @override
  State<PhotoGridWidget> createState() => _PhotoGridWidgetState();
}

class _PhotoGridWidgetState extends State<PhotoGridWidget> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<int, String?> _photoNotes = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didUpdateWidget(PhotoGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload notes if photos changed OR refreshKey changed
    if (oldWidget.photos != widget.photos || oldWidget.refreshKey != widget.refreshKey) {
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    for (var photo in widget.photos) {
      if (photo.id != null) {
        final note = await _dbHelper.getPhotoNote(photo.id!);
        if (mounted) {
          setState(() {
            _photoNotes[photo.id!] = note;
          });
        }
      }
    }
  }

  void _showFullScreenImage(BuildContext context, InspectionPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(photo: photo),
      ),
    );
  }

  Future<void> _showNoteDialog(InspectionPhoto photo) async {
    final existingNote = _photoNotes[photo.id];
    
    // Find photo index
    final photoIndex = widget.photos.indexWhere((p) => p.id == photo.id);
    final photoInfo = photoIndex >= 0 
        ? 'Foto ${photoIndex + 1} dari ${widget.photos.length}'
        : null;
    
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AddNoteDialog(
        initialNote: existingNote,
        title: existingNote == null || existingNote.isEmpty ? 'Tambah Catatan' : 'Edit Catatan',
        itemTitle: widget.itemTitle,
        photoInfo: photoInfo,
      ),
    );

    if (note != null) {
      if (note.isEmpty) {
        // Delete note if empty
        await _dbHelper.deletePhotoNote(photo.id!);
        setState(() {
          _photoNotes[photo.id!] = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Catatan berhasil dihapus'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Update or insert note
        await _dbHelper.updatePhotoNote(photo.id!, note);
        setState(() {
          _photoNotes[photo.id!] = note;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existingNote == null || existingNote.isEmpty
                  ? 'Catatan berhasil ditambahkan' 
                  : 'Catatan berhasil diupdate'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final hasNote = _photoNotes[photo.id] != null && _photoNotes[photo.id]!.isNotEmpty;
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _showFullScreenImage(context, photo),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: File(photo.filePath).existsSync()
                          ? Image.file(
                              File(photo.filePath),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                ),
                // Note button (top left)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _showNoteDialog(photo),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: hasNote 
                            ? Colors.orange.withValues(alpha: 0.9)
                            : Colors.grey.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasNote ? Icons.note : Icons.note_add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Delete button (top right)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _showDeleteConfirmation(context, photo),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      photo.fileName.replaceAll('.jpg', '').replaceAll('.jpeg', '').replaceAll('.png', '').replaceAll('_', ' '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, InspectionPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto'),
        content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.onDeletePhoto(photo);
              } catch (e) {
                debugPrint('Error deleting photo: $e');
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final InspectionPhoto photo;

  const FullScreenImageViewer({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          photo.fileName.replaceAll('.jpg', '').replaceAll('.jpeg', '').replaceAll('.png', '').replaceAll('_', ' '),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: File(photo.filePath).existsSync()
              ? Image.file(
                  File(photo.filePath),
                  fit: BoxFit.contain,
                )
              : Container(
                  color: Colors.grey[800],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'File tidak ditemukan',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
