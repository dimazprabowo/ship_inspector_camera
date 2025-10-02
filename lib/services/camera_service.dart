import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/inspection_photo.dart';
import 'database_helper.dart';
import 'file_service.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FileService _fileService = FileService();
  
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

  /// Generate filename with proper numbering
  Future<String> _generateFileName(String itemTitle, int inspectionItemId) async {
    // Clean the title to make it file-system safe - keep the complete title
    String cleanTitle = _fileService.generateSafeFileName(itemTitle);
    
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

  /// Capture photo using camera
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
      String appDir = await _fileService.getAppDirectory();
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

  /// Pick image from gallery
  Future<InspectionPhoto?> pickImageFromGallery({
    required int inspectionItemId,
    required String itemTitle,
  }) async {
    try {
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
      String appDir = await _fileService.getAppDirectory();
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

  /// Delete photo
  Future<bool> deletePhoto(InspectionPhoto photo) async {
    try {
      // Delete from database
      await _dbHelper.deleteInspectionPhoto(photo.id!);
      
      // Delete physical file
      await _fileService.deleteFile(photo.filePath);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  /// Get photos for inspection item
  Future<List<InspectionPhoto>> getPhotosForItem(int inspectionItemId) async {
    return await _dbHelper.getPhotosByInspectionItem(inspectionItemId);
  }

  /// Check if photo file exists
  bool doesPhotoFileExist(String filePath) {
    return _fileService.doesFileExist(filePath);
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
}