import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../models/inspection_photo.dart';
import '../models/inspection_item.dart';
import 'database_helper.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Target file size in bytes (200KB)
  static const int _targetFileSize = 200 * 1024;
  
  /// Fast compress image to target size with smart estimation
  Future<Uint8List> _compressImageToTargetSize(Uint8List imageBytes, {int targetSize = _targetFileSize}) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      final originalSize = imageBytes.length;
      
      // Quick return if already small enough
      if (originalSize <= targetSize) {
        debugPrint('Image already under target size: ${(originalSize / 1024).round()}KB');
        return imageBytes;
      }
      
      // Smart initial estimation based on file size ratio
      final compressionRatio = targetSize / originalSize;
      
      // Estimate initial quality based on compression needed
      int estimatedQuality;
      if (compressionRatio > 0.7) {
        estimatedQuality = 85; // Light compression needed
      } else if (compressionRatio > 0.4) {
        estimatedQuality = 65; // Medium compression needed
      } else if (compressionRatio > 0.2) {
        estimatedQuality = 45; // Heavy compression needed
      } else {
        estimatedQuality = 25; // Very heavy compression needed
      }
      
      // Try estimated quality first
      Uint8List compressedBytes = img.encodeJpg(image, quality: estimatedQuality);
      debugPrint('Smart compression: estimated quality=$estimatedQuality, size=${compressedBytes.length} bytes');
      
      // Fine-tune if needed (max 2 additional attempts)
      if (compressedBytes.length > targetSize) {
        // Too big, reduce quality more aggressively
        int adjustedQuality = (estimatedQuality * 0.7).round().clamp(15, 95);
        compressedBytes = img.encodeJpg(image, quality: adjustedQuality);
        debugPrint('Adjustment 1: quality=$adjustedQuality, size=${compressedBytes.length} bytes');
        
        // If still too big, resize image
        if (compressedBytes.length > targetSize) {
          double scaleFactor = (targetSize / compressedBytes.length * 0.9).clamp(0.4, 1.0);
          int newWidth = (image.width * scaleFactor).round();
          int newHeight = (image.height * scaleFactor).round();
          
          img.Image resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
          compressedBytes = img.encodeJpg(resizedImage, quality: adjustedQuality);
          debugPrint('Final resize: scale=$scaleFactor, dimensions=${newWidth}x${newHeight}, size=${compressedBytes.length} bytes');
        }
      } else if (compressedBytes.length < targetSize * 0.6) {
        // Too small, we can increase quality a bit
        int betterQuality = (estimatedQuality * 1.2).round().clamp(15, 95);
        Uint8List betterBytes = img.encodeJpg(image, quality: betterQuality);
        if (betterBytes.length <= targetSize) {
          compressedBytes = betterBytes;
          debugPrint('Quality improvement: quality=$betterQuality, size=${compressedBytes.length} bytes');
        }
      }
      
      final finalSizeKB = (compressedBytes.length / 1024).round();
      debugPrint('Fast compression complete: ${finalSizeKB}KB (target: ${targetSize / 1024}KB)');
      
      return compressedBytes;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  Future<String> _getAppDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final Directory shipInspectorDir = Directory('$appDocPath/ship_inspector_photos');
    
    if (!await shipInspectorDir.exists()) {
      await shipInspectorDir.create(recursive: true);
    }
    
    return shipInspectorDir.path;
  }

  Future<String> _getZipExportDirectory() async {
    try {
      // Try to get Downloads directory first (most accessible)
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final Directory zipExportDir = Directory('${downloadsDir.path}/ShipInspectorExports');
        if (!await zipExportDir.exists()) {
          await zipExportDir.create(recursive: true);
        }
        return zipExportDir.path;
      }
    } catch (e) {
      debugPrint('Could not access Downloads directory: $e');
    }

    try {
      // Try external storage directory
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Try to access public Documents folder
        final List<String> pathParts = externalDir.path.split('/');
        final int androidIndex = pathParts.indexOf('Android');
        if (androidIndex > 0) {
          final String publicPath = pathParts.sublist(0, androidIndex).join('/');
          final Directory documentsDir = Directory('$publicPath/Documents/ShipInspectorExports');
          
          try {
            if (!await documentsDir.exists()) {
              await documentsDir.create(recursive: true);
            }
            return documentsDir.path;
          } catch (e) {
            debugPrint('Could not create Documents folder: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Could not access external storage: $e');
    }
    
    // Fallback to app documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final Directory zipExportDir = Directory('$appDocPath/ship_inspector_exports');
    
    if (!await zipExportDir.exists()) {
      await zipExportDir.create(recursive: true);
    }
    
    return zipExportDir.path;
  }

  Future<String> _generateFileName(String itemTitle, int inspectionItemId) async {
    // Clean the title to make it file-system safe - keep the complete title
    String cleanTitle = itemTitle
        .replaceAll(RegExp(r'[^\w\s-]'), '')  // Remove special characters except word chars, spaces, hyphens
        .replaceAll(RegExp(r'\s+'), '_')      // Replace spaces with underscores
        .toLowerCase();                       // Convert to lowercase
    
    // Get existing photos to find the next available number
    List<InspectionPhoto> existingPhotos = await _dbHelper.getPhotosByInspectionItem(inspectionItemId);
    
    // Extract existing numbers from filenames
    Set<int> usedNumbers = {};
    for (var photo in existingPhotos) {
      final match = RegExp(r'_(\d+)\.jpg$').firstMatch(photo.fileName);
      if (match != null) {
        usedNumbers.add(int.parse(match.group(1)!));
      }
    }
    
    // Find the next available number (starting from 1)
    int nextNumber = 1;
    while (usedNumbers.contains(nextNumber)) {
      nextNumber++;
    }
    
    String suffix = '_$nextNumber';
    
    return '$cleanTitle$suffix.jpg';
  }

  Future<InspectionPhoto?> capturePhoto({
    required int inspectionItemId,
    required String itemTitle,
  }) async {
    try {
      // Capture image using camera with optimized settings
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, // Start higher, we'll compress smartly
        maxWidth: 1920,   // Limit initial size for faster processing
        maxHeight: 1920,
      );

      if (image == null) return null;

      // Generate filename with proper numbering
      String fileName = await _generateFileName(itemTitle, inspectionItemId);
      
      // Get app directory
      String appDir = await _getAppDirectory();
      String filePath = path.join(appDir, fileName);

      // Process image to make it square using image package (faster)
      File sourceFile = File(image.path);
      final imageBytes = await sourceFile.readAsBytes();
      
      // Use image package for faster processing
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception('Failed to decode image');
      
      // Calculate square size (use smaller dimension)
      final squareSize = originalImage.width < originalImage.height ? originalImage.width : originalImage.height;
      
      // Calculate crop offsets to center the square
      final xOffset = (originalImage.width - squareSize) ~/ 2;
      final yOffset = (originalImage.height - squareSize) ~/ 2;
      
      // Crop to square using image package (much faster)
      img.Image squareImage = img.copyCrop(
        originalImage,
        x: xOffset,
        y: yOffset,
        width: squareSize,
        height: squareSize,
      );
      
      // Convert to bytes and compress in one step
      Uint8List finalImageBytes = img.encodeJpg(squareImage, quality: 90);
      finalImageBytes = await _compressImageToTargetSize(finalImageBytes);
      
      // Save the compressed square image
      File destinationFile = File(filePath);
      await destinationFile.writeAsBytes(finalImageBytes);

      // Create InspectionPhoto object
      InspectionPhoto photo = InspectionPhoto(
        inspectionItemId: inspectionItemId,
        fileName: fileName,
        filePath: filePath,
        capturedAt: DateTime.now(),
      );

      // Save to database
      int photoId = await _dbHelper.insertInspectionPhoto(photo);
      
      return photo.copyWith(id: photoId);
    } catch (e) {
      // Log error for debugging
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  Future<InspectionPhoto?> pickImageFromGallery({
    required int inspectionItemId,
    required String itemTitle,
  }) async {
    try {
      // Get existing photos count for this item
      List<InspectionPhoto> existingPhotos = await _dbHelper.getPhotosByInspectionItem(inspectionItemId);
      
      // Pick image from gallery with size limits for faster processing
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90, // Good quality, we'll compress smartly
        maxWidth: 2048,   // Limit size for faster processing
        maxHeight: 2048,
      );

      if (image == null) return null;

      // Generate filename
      String fileName = await _generateFileName(itemTitle, inspectionItemId);
      
      // Get app directory
      String appDir = await _getAppDirectory();
      String filePath = path.join(appDir, fileName);

      // Read and compress the selected image
      File sourceFile = File(image.path);
      final imageBytes = await sourceFile.readAsBytes();
      
      // Compress image to target size (200KB)
      final compressedBytes = await _compressImageToTargetSize(imageBytes);
      
      // Save compressed image
      File destinationFile = File(filePath);
      await destinationFile.writeAsBytes(compressedBytes);

      // Create InspectionPhoto object
      InspectionPhoto photo = InspectionPhoto(
        inspectionItemId: inspectionItemId,
        fileName: fileName,
        filePath: filePath,
        capturedAt: DateTime.now(),
      );

      // Save to database
      int photoId = await _dbHelper.insertInspectionPhoto(photo);
      
      return photo.copyWith(id: photoId);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  Future<bool> deletePhoto(InspectionPhoto photo) async {
    try {
      // Delete from database
      await _dbHelper.deleteInspectionPhoto(photo.id!);
      
      // Delete physical file
      File file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  Future<List<InspectionPhoto>> getPhotosForItem(int inspectionItemId) async {
    return await _dbHelper.getPhotosByInspectionItem(inspectionItemId);
  }

  bool doesPhotoFileExist(String filePath) {
    return File(filePath).existsSync();
  }

  /// Compress existing photo file to target size
  Future<bool> compressExistingPhoto(String filePath, {int targetSize = _targetFileSize}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final originalBytes = await file.readAsBytes();
      final originalSizeKB = (originalBytes.length / 1024).round();
      
      // Skip compression if already under target size
      if (originalBytes.length <= targetSize) {
        debugPrint('Photo already under target size: ${originalSizeKB}KB');
        return true;
      }
      
      debugPrint('Compressing existing photo: ${originalSizeKB}KB -> target: ${targetSize / 1024}KB');
      
      final compressedBytes = await _compressImageToTargetSize(originalBytes, targetSize: targetSize);
      
      // Only save if compression was successful and reduced size
      if (compressedBytes.length < originalBytes.length) {
        await file.writeAsBytes(compressedBytes);
        final newSizeKB = (compressedBytes.length / 1024).round();
        debugPrint('Photo compressed successfully: ${originalSizeKB}KB -> ${newSizeKB}KB');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error compressing existing photo: $e');
      return false;
    }
  }

  Future<List<String>> getAvailableExportPaths() async {
    List<String> paths = [];
    
    try {
      // Add Downloads directory
      if (Platform.isAndroid) {
        final Directory downloadsDir = Directory('/storage/emulated/0/Download');
        if (downloadsDir != null && await downloadsDir.exists()) {
          final exportDir = Directory(path.join(downloadsDir.path, 'ShipInspectorExports'));
          if (!await exportDir.exists()) {
            await exportDir.create(recursive: true);
          }
          paths.add(exportDir.path);
        }
      }
      
      // Add Documents directory
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final exportDir = Directory(path.join(documentsDir.path, 'ShipInspectorExports'));
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        paths.add(exportDir.path);
      } catch (e) {
        debugPrint('Could not access documents directory: $e');
      }
      
      // Skip external storage - removed as requested
      
    } catch (e) {
      debugPrint('Error getting export paths: $e');
    }
    
    return paths;
  }

  Future<String?> exportInspectionPhotosAsZip(int shipTypeId, String shipTypeName, String companyName, {String? customPath}) async {
    try {
      // Get all inspection items for this ship type
      final inspectionItems = await _dbHelper.getInspectionItemsByShipType(shipTypeId);
      
      if (inspectionItems.isEmpty) {
        return null;
      }

      // Create archive
      final archive = Archive();
      bool hasPhotos = false;

      // Group items by parent category
      Map<String, List<InspectionItem>> itemsByParent = {};
      for (var item in inspectionItems) {
        final parentKey = item.parentName ?? 'Uncategorized';
        if (!itemsByParent.containsKey(parentKey)) {
          itemsByParent[parentKey] = [];
        }
        itemsByParent[parentKey]!.add(item);
      }

      // Add photos for each parent category
      for (var parentCategory in itemsByParent.keys) {
        final items = itemsByParent[parentCategory]!;
        
        for (var item in items) {
          final photos = await _dbHelper.getPhotosByInspectionItem(item.id!);
          
          for (var photo in photos) {
            final file = File(photo.filePath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              // Create folder structure: ParentCategory/ItemTitle/photo.jpg
              final folderPath = '$parentCategory/${item.title}/${photo.fileName}';
              final archiveFile = ArchiveFile(folderPath, bytes.length, bytes);
              archive.addFile(archiveFile);
              hasPhotos = true;
            }
          }
        }
      }

      if (!hasPhotos) {
        return null;
      }

      // Use custom path if provided, otherwise use default directory
      final String exportDir;
      if (customPath != null && customPath.isNotEmpty) {
        exportDir = customPath;
      } else {
        exportDir = await _getZipExportDirectory();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = '${'${companyName}_${shipTypeName}_inspection_$timestamp'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase()}.zip';
      
      final zipPath = path.join(exportDir, zipFileName);
      final zipFile = File(zipPath);
      
      // Encode and save ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        await zipFile.writeAsBytes(zipData);
        return zipPath;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error creating ZIP export: $e');
      return null;
    }
  }

  Future<String?> exportInspectionPhotosAsPdf(int shipTypeId, String shipTypeName, String companyName, {String? customPath, DateTime? inspectionDate}) async {
    try {
      // Get all inspection items for this ship type
      final inspectionItems = await _dbHelper.getInspectionItemsByShipType(shipTypeId);
      
      if (inspectionItems.isEmpty) {
        return null;
      }

      // Create PDF document
      final pdf = pw.Document();
      
      // Collect all photos
      List<Map<String, dynamic>> photoData = [];
      
      for (var item in inspectionItems) {
        final photos = await _dbHelper.getPhotosByInspectionItem(item.id!);
        
        for (var photo in photos) {
          final file = File(photo.filePath);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final photoName = photo.fileName
                .replaceAll('.jpg', '')
                .replaceAll('.jpeg', '')
                .replaceAll('.png', '')
                .replaceAll('_', ' ');
            
            photoData.add({
              'name': photoName,
              'image': imageBytes,
            });
          }
        }
      }

      if (photoData.isEmpty) {
        return null;
      }

      // Group photos by parent category first, then by inspection item
      Map<String, Map<String, List<Map<String, dynamic>>>> photosByParentAndItem = {};
      
      debugPrint('Starting to group ${inspectionItems.length} inspection items by parent category');
      
      for (var item in inspectionItems) {
        debugPrint('Processing item: ${item.title} (Parent: ${item.parentName ?? 'Uncategorized'})');
        
        final photos = await _dbHelper.getPhotosByInspectionItem(item.id!);
        debugPrint('  Found ${photos.length} photos for item ${item.title}');
        
        if (photos.isNotEmpty) {
          List<Map<String, dynamic>> itemPhotos = [];
          
          // Sort photos by numeric value in filename (natural sorting)
          photos.sort((a, b) {
            // Extract numbers from filenames for proper numeric sorting
            final RegExp numberRegex = RegExp(r'_(\d+)\.jpg$');
            final Match? matchA = numberRegex.firstMatch(a.fileName);
            final Match? matchB = numberRegex.firstMatch(b.fileName);
            
            if (matchA != null && matchB != null) {
              final int numA = int.parse(matchA.group(1)!);
              final int numB = int.parse(matchB.group(1)!);
              return numA.compareTo(numB);
            }
            
            // Fallback to alphabetical sorting if no numbers found
            return a.fileName.compareTo(b.fileName);
          });
          
          for (var photo in photos) {
            final file = File(photo.filePath);
            if (await file.exists()) {
              final imageBytes = await file.readAsBytes();
              final photoName = photo.fileName
                  .replaceAll('.jpg', '')
                  .replaceAll('.jpeg', '')
                  .replaceAll('.png', '')
                  .replaceAll('_', ' ');
              
              itemPhotos.add({
                'name': photoName,
                'image': imageBytes,
                'fileName': photo.fileName, // Keep original filename for sorting reference
              });
            }
          }
          
          if (itemPhotos.isNotEmpty) {
            final parentKey = item.parentName ?? 'Uncategorized';
            if (!photosByParentAndItem.containsKey(parentKey)) {
              photosByParentAndItem[parentKey] = {};
            }
            photosByParentAndItem[parentKey]![item.title] = itemPhotos;
            debugPrint('  Added ${itemPhotos.length} photos to category "$parentKey" for item "${item.title}"');
          }
        }
      }
      
      debugPrint('Final grouping result: ${photosByParentAndItem.length} categories');
      for (var entry in photosByParentAndItem.entries) {
        debugPrint('  Category "${entry.key}": ${entry.value.length} items');
        for (var itemEntry in entry.value.entries) {
          debugPrint('    Item "${itemEntry.key}": ${itemEntry.value.length} photos');
        }
      }

      if (photosByParentAndItem.isEmpty) {
        return null;
      }

      // Create PDF with header
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'LAPORAN INSPEKSI KAPAL - Ship Inspector Camera',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Perusahaan: $companyName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Jenis Kapal: $shipTypeName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Tanggal Inspeksi: ${inspectionDate?.toString().split(' ')[0] ?? DateTime.now().toString().split(' ')[0]}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('DOKUMENTASI FOTO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            );
          },
        ),
      );

      // Create pages grouped by parent category - all items in same category on same pages
      for (var entry in photosByParentAndItem.entries) {
        final parentCategory = entry.key;
        final itemsMap = entry.value;
        
        // Debug log to check what we're processing
        debugPrint('Processing category: $parentCategory with ${itemsMap.length} items');
        
        // Collect all photos from all items in this category
        List<Map<String, dynamic>> allCategoryPhotos = [];
        
        for (var itemEntry in itemsMap.entries) {
          final itemTitle = itemEntry.key;
          final photos = itemEntry.value;
          
          debugPrint('  Item: $itemTitle has ${photos.length} photos');
          
          // Add item title as metadata to each photo
          for (var photo in photos) {
            allCategoryPhotos.add({
              ...photo,
              'itemTitle': itemTitle,
            });
          }
        }
        
        debugPrint('Total photos for category $parentCategory: ${allCategoryPhotos.length}');
        
        if (allCategoryPhotos.isEmpty) {
          debugPrint('Skipping empty category: $parentCategory');
          continue;
        }
        
        // Process all category photos in chunks of 6 per page
        for (int pageStart = 0; pageStart < allCategoryPhotos.length; pageStart += 6) {
          final pagePhotos = allCategoryPhotos.skip(pageStart).take(6).toList();
          
          debugPrint('Page ${(pageStart ~/ 6) + 1}: Processing ${pagePhotos.length} photos (from index $pageStart)');
          for (int i = 0; i < pagePhotos.length; i++) {
            debugPrint('  Photo ${i + 1}: ${pagePhotos[i]['name']} (Item: ${pagePhotos[i]['itemTitle']})');
          }
          
          // Create chunks of 2 photos per row
          final photoChunks = <List<Map<String, dynamic>>>[];
          for (int i = 0; i < pagePhotos.length; i += 2) {
            photoChunks.add(pagePhotos.skip(i).take(2).toList());
          }
          
          debugPrint('Created ${photoChunks.length} photo chunks for this page');

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Category header
                    pw.Center(
                      child: pw.Text(
                        'KATEGORI: ${parentCategory.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    // Photo table with proper borders
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(275),
                        1: const pw.FixedColumnWidth(275),
                      },
                      children: photoChunks.asMap().entries.map((entry) {
                        final chunkIndex = entry.key;
                        final rowPhotos = entry.value;
                        debugPrint('Rendering chunk $chunkIndex with ${rowPhotos.length} photos');
                        
                        return pw.TableRow(
                          children: [
                            // First photo cell
                            pw.Container(
                              height: 200,
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.start,
                                children: [
                                  // Item title
                                  pw.Container(
                                    width: double.infinity,
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.blue50,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      rowPhotos[0]['itemTitle'] ?? 'Unknown Item',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blue800,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Photo
                                  pw.Container(
                                    width: 150,
                                    height: 120,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                                    ),
                                    child: rowPhotos[0]['image'] != null 
                                        ? pw.ClipRect(
                                            child: pw.Image(
                                              pw.MemoryImage(rowPhotos[0]['image']),
                                              fit: pw.BoxFit.cover,
                                              width: 150,
                                              height: 120,
                                            ),
                                          )
                                        : pw.Center(
                                            child: pw.Text(
                                              'No Image',
                                              style: pw.TextStyle(color: PdfColors.red),
                                            ),
                                          ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Photo name
                                  pw.Container(
                                    width: 150,
                                    child: pw.Text(
                                      rowPhotos[0]['name'] ?? 'Unknown Photo',
                                      style: const pw.TextStyle(fontSize: 9),
                                      textAlign: pw.TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Second photo cell (or empty cell)
                            pw.Container(
                              height: 200,
                              padding: const pw.EdgeInsets.all(8),
                              child: rowPhotos.length > 1
                                  ? pw.Column(
                                      mainAxisAlignment: pw.MainAxisAlignment.start,
                                      children: [
                                        // Item title
                                        pw.Container(
                                          width: double.infinity,
                                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          decoration: pw.BoxDecoration(
                                            color: PdfColors.blue50,
                                            borderRadius: pw.BorderRadius.circular(4),
                                          ),
                                          child: pw.Text(
                                            rowPhotos[1]['itemTitle'] ?? 'Unknown Item',
                                            style: pw.TextStyle(
                                              fontSize: 10,
                                              fontWeight: pw.FontWeight.bold,
                                              color: PdfColors.blue800,
                                            ),
                                            textAlign: pw.TextAlign.center,
                                            maxLines: 1,
                                          ),
                                        ),
                                        pw.SizedBox(height: 8),
                                        // Photo
                                        pw.Container(
                                          width: 150,
                                          height: 120,
                                          decoration: pw.BoxDecoration(
                                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                                          ),
                                          child: rowPhotos[1]['image'] != null
                                              ? pw.ClipRect(
                                                  child: pw.Image(
                                                    pw.MemoryImage(rowPhotos[1]['image']),
                                                    fit: pw.BoxFit.cover,
                                                    width: 150,
                                                    height: 120,
                                                  ),
                                                )
                                              : pw.Center(
                                                  child: pw.Text(
                                                    'No Image',
                                                    style: pw.TextStyle(color: PdfColors.red),
                                                  ),
                                                ),
                                        ),
                                        pw.SizedBox(height: 8),
                                        // Photo name
                                        pw.Container(
                                          width: 150,
                                          child: pw.Text(
                                            rowPhotos[1]['name'] ?? 'Unknown Photo',
                                            style: const pw.TextStyle(fontSize: 9),
                                            textAlign: pw.TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ],
                                    )
                                  : pw.Container(), // Empty cell if no second photo
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      // Use custom path if provided, otherwise use default directory
      final String exportDir;
      if (customPath != null && customPath.isNotEmpty) {
        exportDir = customPath;
      } else {
        exportDir = await _getZipExportDirectory();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfFileName = '${'${companyName}_${shipTypeName}_inspection_$timestamp'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase()}.pdf';
      
      final pdfPath = path.join(exportDir, pdfFileName);
      final pdfFile = File(pdfPath);
      
      // Save PDF
      await pdfFile.writeAsBytes(await pdf.save());
      return pdfPath;
      
    } catch (e) {
      debugPrint('Error creating PDF export: $e');
      return null;
    }
  }


}
