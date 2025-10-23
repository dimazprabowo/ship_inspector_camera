import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Get application directory for storing photos
  Future<String> getAppDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final Directory shipInspectorDir = Directory('$appDocPath/ship_inspector_photos');
    
    if (!await shipInspectorDir.exists()) {
      await shipInspectorDir.create(recursive: true);
    }
    
    return shipInspectorDir.path;
  }

  /// Get directory for ZIP and PDF exports
  Future<String> getExportDirectory() async {
    try {
      // Try to get Downloads directory first (most accessible)
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final Directory exportDir = Directory('${downloadsDir.path}/ShipInspectorExports');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        return exportDir.path;
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
    final Directory exportDir = Directory('$appDocPath/ship_inspector_exports');
    
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    
    return exportDir.path;
  }

  /// Get list of available export paths
  Future<List<String>> getAvailableExportPaths() async {
    List<String> paths = [];
    
    try {
      // Add Downloads directory
      if (Platform.isAndroid) {
        final Directory downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
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
      
    } catch (e) {
      debugPrint('Error getting export paths: $e');
    }
    
    return paths;
  }

  /// Get directory for ZIP exports (same as general export directory)
  Future<String> getZipExportDirectory() async {
    return await getExportDirectory();
  }

  /// Check if file exists
  bool doesFileExist(String filePath) {
    return File(filePath).existsSync();
  }

  /// Delete a file
  Future<bool> deleteFile(String filePath) async {
    try {
      File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  /// Generate safe filename for file system
  String generateSafeFileName(String name) {
    // Remove special characters
    String cleaned = name.replaceAll(RegExp(r'[^\w\s-]'), '');
    
    // Capitalize setiap kata
    String capitalized = cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    // Replace spaces with underscores
    return capitalized.replaceAll(RegExp(r'\s+'), '_');
  }

  /// Create directory if it doesn't exist
  Future<bool> createDirectory(String dirPath) async {
    try {
      final Directory dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error creating directory: $e');
      return false;
    }
  }
}