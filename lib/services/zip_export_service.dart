import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/inspection_item.dart';
import 'database_helper.dart';
import 'file_service.dart';

class ZipExportService {
  static final ZipExportService _instance = ZipExportService._internal();
  factory ZipExportService() => _instance;
  ZipExportService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FileService _fileService = FileService();

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
                
                // Create file path in ZIP: ParentCategory/ItemName/photo.jpg
                final zipFilePath = '$safeFolderName/$safeItemName/${photo.fileName}';
                
                // Add file to archive
                final archiveFile = ArchiveFile(zipFilePath, imageBytes.length, imageBytes);
                archive.addFile(archiveFile);
                
                debugPrint('Added to ZIP: $zipFilePath');
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