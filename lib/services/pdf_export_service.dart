import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../models/inspection_item.dart';
import 'database_helper.dart';
import 'file_service.dart';

class PdfExportService {
  static final PdfExportService _instance = PdfExportService._internal();
  factory PdfExportService() => _instance;
  PdfExportService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FileService _fileService = FileService();
  
  /// Compress image untuk PDF (max 1024px, quality 85%)
  Future<Uint8List> _compressImageForPdf(Uint8List imageBytes) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      // Resize jika terlalu besar (max 1024px untuk sisi terpanjang)
      img.Image resized;
      if (image.width > 1024 || image.height > 1024) {
        if (image.width > image.height) {
          resized = img.copyResize(image, width: 1024);
        } else {
          resized = img.copyResize(image, height: 1024);
        }
      } else {
        resized = image;
      }
      
      // Encode dengan quality 85% (balance antara size dan quality)
      final compressed = img.encodeJpg(resized, quality: 85);
      
      debugPrint('Image compressed: ${imageBytes.length} → ${compressed.length} bytes (${((1 - compressed.length / imageBytes.length) * 100).toStringAsFixed(1)}% reduction)');
      
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes; // Return original jika error
    }
  }

  /// Export inspection photos as PDF
  Future<String?> exportInspectionPhotosAsPdf(
    int shipTypeId, 
    String shipTypeName, 
    String companyName, {
    String? customPath, 
    DateTime? inspectionDate
  }) async {
    try {
      // Get all inspection items for this ship type
      final inspectionItems = await _dbHelper.getInspectionItemsByShipType(shipTypeId);
      
      if (inspectionItems.isEmpty) {
        return null;
      }

      // Create PDF document
      final pdf = pw.Document();
      
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
              
              // Compress image untuk PDF
              final compressedBytes = await _compressImageForPdf(imageBytes);
              
              final photoName = photo.fileName
                  .replaceAll('.jpg', '')
                  .replaceAll('.jpeg', '')
                  .replaceAll('.png', '')
                  .replaceAll('_', ' ');
              
              itemPhotos.add({
                'name': photoName,
                'image': compressedBytes, // Gunakan compressed image
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
          margin: const pw.EdgeInsets.only(
            left: 20,
            right: 20,
            top: 100, // Space untuk kop/header (80px lebih banyak)
            bottom: 20,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Space untuk kop/header di atas (bisa diisi manual)
                pw.SizedBox(height: 10),
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
              margin: const pw.EdgeInsets.only(
                left: 20,
                right: 20,
                top: 100, // Space untuk kop/header (80px lebih banyak)
                bottom: 20,
              ),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Space untuk kop/header di atas (bisa diisi manual)
                    pw.SizedBox(height: 10),
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
                            _buildPhotoCell(rowPhotos[0]),
                            // Second photo cell (or empty cell)
                            rowPhotos.length > 1 
                                ? _buildPhotoCell(rowPhotos[1])
                                : pw.Container(
                                    height: 170, // Same height as _buildPhotoCell
                                    padding: const pw.EdgeInsets.all(8),
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
        exportDir = await _fileService.getExportDirectory();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfFileName = _fileService.generateSafeFileName('${companyName}_${shipTypeName}_inspection_$timestamp') + '.pdf';
      
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

  /// Capitalize setiap kata
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Build photo cell for PDF table
  pw.Widget _buildPhotoCell(Map<String, dynamic> photoData) {
    // Capitalize nama foto
    final photoName = _capitalizeWords(photoData['name'] ?? 'Unknown Photo');
    
    return pw.Container(
      height: 170, // Reduced height karena tidak ada item title
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // Photo (tanpa item title)
          pw.Container(
            width: 150,
            height: 120,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
            ),
            child: photoData['image'] != null 
                ? pw.ClipRect(
                    child: pw.Image(
                      pw.MemoryImage(photoData['image']),
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
          // Photo name (capitalized)
          pw.Container(
            width: 150,
            child: pw.Text(
              photoName,
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}