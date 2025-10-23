import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/inspection_item.dart';
import 'database_helper.dart';
import 'file_service.dart';

class ZipExportService {
  static final ZipExportService _instance = ZipExportService._internal();
  factory ZipExportService() => _instance;
  ZipExportService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FileService _fileService = FileService();
  
  /// Compress image untuk ZIP (max 1920px, quality 90%)
  Future<Uint8List> _compressImageForZip(Uint8List imageBytes) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      // Resize jika terlalu besar (max 1920px untuk sisi terpanjang)
      // ZIP bisa lebih besar dari PDF karena untuk archiving
      img.Image resized;
      if (image.width > 1920 || image.height > 1920) {
        if (image.width > image.height) {
          resized = img.copyResize(image, width: 1920);
        } else {
          resized = img.copyResize(image, height: 1920);
        }
      } else {
        resized = image;
      }
      
      // Encode dengan quality 90% (lebih tinggi untuk ZIP)
      final compressed = img.encodeJpg(resized, quality: 90);
      
      debugPrint('Image compressed for ZIP: ${imageBytes.length} → ${compressed.length} bytes (${((1 - compressed.length / imageBytes.length) * 100).toStringAsFixed(1)}% reduction)');
      
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('Error compressing image for ZIP: $e');
      return imageBytes; // Return original jika error
    }
  }

  /// Export inspection photos as ZIP
  Future<String?> exportInspectionPhotosAsZip(
    int shipTypeId, 
    String shipTypeName, 
    String companyName, {
    String? customPath
  }) async {
    try {
      // Get all inspection items for this ship type
      final inspectionItems = await _dbHelper.getInspectionItemsByShipType(shipTypeId);
      
      if (inspectionItems.isEmpty) {
        return null;
      }

      // Create archive
      final archive = Archive();
      
      // Group photos by parent category
      Map<String, List<InspectionItem>> itemsByParent = {};
      
      for (var item in inspectionItems) {
        final parentKey = item.parentName ?? 'Uncategorized';
        if (!itemsByParent.containsKey(parentKey)) {
          itemsByParent[parentKey] = [];
        }
        itemsByParent[parentKey]!.add(item);
      }

      bool hasPhotos = false;

      // Process each parent category
      for (var entry in itemsByParent.entries) {
        final parentName = entry.key;
        final items = entry.value;
        
        // Create safe folder name for parent category
        final safeFolderName = _fileService.generateSafeFileName(parentName);
        
        for (var item in items) {
          final photos = await _dbHelper.getPhotosByInspectionItem(item.id!);
          
          if (photos.isNotEmpty) {
            hasPhotos = true;
            
            // Create safe folder name for inspection item
            final safeItemName = _fileService.generateSafeFileName(item.title);
            
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
                
                // Compress image untuk ZIP
                final compressedBytes = await _compressImageForZip(imageBytes);
                
                // Create file path in ZIP: ParentCategory/ItemName/photo.jpg
                final zipFilePath = '$safeFolderName/$safeItemName/${photo.fileName}';
                
                // Add compressed file to archive
                final archiveFile = ArchiveFile(zipFilePath, compressedBytes.length, compressedBytes);
                archive.addFile(archiveFile);
                
                debugPrint('Added to ZIP: $zipFilePath (${compressedBytes.length} bytes)');
              }
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
        exportDir = await _fileService.getZipExportDirectory();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = _fileService.generateSafeFileName('${companyName}_${shipTypeName}_photos_$timestamp') + '.zip';
      
      final zipPath = path.join(exportDir, zipFileName);
      
      // Encode archive to ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData != null) {
        final zipFile = File(zipPath);
        await zipFile.writeAsBytes(zipData);
        return zipPath;
      }
      
      return null;
      
    } catch (e) {
      debugPrint('Error creating ZIP export: $e');
      return null;
    }
  }
}