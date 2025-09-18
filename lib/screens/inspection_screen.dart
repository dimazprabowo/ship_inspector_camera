import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/company.dart';
import '../models/ship_type.dart';
import '../models/inspection_item.dart';
import '../models/inspection_photo.dart';
import '../services/database_helper.dart';
import '../services/camera_service.dart';
import '../widgets/photo_grid_widget.dart';
import '../widgets/add_inspection_item_dialog.dart';
import '../widgets/edit_inspection_item_dialog.dart';

class InspectionScreen extends StatefulWidget {
  final Company company;
  final ShipType shipType;

  const InspectionScreen({
    super.key,
    required this.company,
    required this.shipType,
  });

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CameraService _cameraService = CameraService();
  List<InspectionItem> _inspectionItems = [];
  Map<int, List<InspectionPhoto>> _itemPhotos = {};
  Map<String, bool> _categoryCollapsedState = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInspectionData();
  }

  Future<void> _loadInspectionData() async {
    try {
      final items = await _dbHelper.getInspectionItemsByShipType(widget.shipType.id!);
      Map<int, List<InspectionPhoto>> photos = {};
      
      for (var item in items) {
        final itemPhotos = await _cameraService.getPhotosForItem(item.id!);
        photos[item.id!] = itemPhotos;
      }

      setState(() {
        _inspectionItems = items;
        _itemPhotos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inspection data: $e')),
        );
      }
    }
  }

  Map<String, List<InspectionItem>> _groupItemsByCategory() {
    Map<String, List<InspectionItem>> groupedItems = {};
    List<InspectionItem> itemsWithoutCategory = [];
    
    for (var item in _inspectionItems) {
      if (item.parentName != null && item.parentName!.isNotEmpty) {
        String categoryName = item.parentName!;
        if (!groupedItems.containsKey(categoryName)) {
          groupedItems[categoryName] = [];
        }
        groupedItems[categoryName]!.add(item);
      } else {
        // Items without category will be handled separately
        itemsWithoutCategory.add(item);
      }
    }
    
    // Add items without category as a special key for separate handling
    if (itemsWithoutCategory.isNotEmpty) {
      groupedItems['__ITEMS_WITHOUT_CATEGORY__'] = itemsWithoutCategory;
    }
    
    return groupedItems;
  }

  Future<void> _capturePhoto(InspectionItem item) async {
    try {
      final photo = await _cameraService.capturePhoto(
        inspectionItemId: item.id!,
        itemTitle: item.title,
      );

      if (photo != null) {
        setState(() {
          _itemPhotos[item.id!] = [...(_itemPhotos[item.id!] ?? []), photo];
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto berhasil disimpan')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery(InspectionItem item) async {
    try {
      final photo = await _cameraService.pickImageFromGallery(
        inspectionItemId: item.id!,
        itemTitle: item.title,
      );

      if (photo != null) {
        setState(() {
          _itemPhotos[item.id!] = [...(_itemPhotos[item.id!] ?? []), photo];
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto berhasil ditambahkan')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking photo: $e')),
        );
      }
    }
  }

  void _showPhotoOptions(InspectionItem item) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _capturePhoto(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePhoto(InspectionPhoto photo, int itemId) async {
    try {
      final success = await _cameraService.deletePhoto(photo);
      if (success) {
        setState(() {
          final currentPhotos = _itemPhotos[itemId];
          if (currentPhotos != null) {
            currentPhotos.removeWhere((p) => p.id == photo.id);
            _itemPhotos[itemId] = List.from(currentPhotos);
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto berhasil dihapus')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e')),
        );
      }
    }
  }

  Future<void> _addNewInspectionItem() async {
    final result = await showDialog<InspectionItem>(
      context: context,
      builder: (context) => AddInspectionItemDialog(shipTypeId: widget.shipType.id!),
    );

    if (result != null) {
      await _loadInspectionData();
    }
  }

  Future<void> _editInspectionItem(InspectionItem item) async {
    final result = await showDialog<InspectionItem>(
      context: context,
      builder: (context) => EditInspectionItemDialog(item: item),
    );

    if (result != null) {
      _loadInspectionData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item inspeksi berhasil diupdate')),
        );
      }
    }
  }

  Future<void> _deleteInspectionItem(InspectionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Item Inspeksi'),
        content: Text('Apakah Anda yakin ingin menghapus "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteInspectionItem(item.id!);
      _loadInspectionData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item inspeksi berhasil dihapus')),
        );
      }
    }
  }

  Future<void> _exportPhotosAsZip() async {
    try {
      // Get available export paths
      final availablePaths = await _cameraService.getAvailableExportPaths();
      
      if (availablePaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada lokasi penyimpanan yang tersedia')),
          );
        }
        return;
      }

      // Show dialog to choose save location
      String? selectedPath;
      if (availablePaths.length == 1) {
        selectedPath = availablePaths.first;
      } else {
        selectedPath = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pilih Lokasi Penyimpanan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pilih format dan lokasi export:'),
                const SizedBox(height: 16),
                ...availablePaths.map((pathStr) {
                  String displayName;
                  if (pathStr.contains('Download')) {
                    displayName = 'Downloads (ZIP)';
                  } else if (pathStr.contains('Documents')) {
                    displayName = 'Documents (ZIP)';
                  } else {
                    displayName = 'ZIP Export';
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, pathStr),
                        child: Text(displayName),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                ...availablePaths.map((pathStr) {
                  String displayName;
                  if (pathStr.contains('Download')) {
                    displayName = 'Downloads (PDF)';
                  } else if (pathStr.contains('Documents')) {
                    displayName = 'Documents (PDF)';
                  } else {
                    displayName = 'PDF Export';
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, 'pdf:$pathStr'),
                        child: Text(displayName),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ],
          ),
        );
      }

      if (selectedPath == null) return;

      // Check export type
      bool isPdfExport = selectedPath.startsWith('pdf:');
      String actualPath = isPdfExport ? selectedPath.substring(4) : selectedPath;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(isPdfExport ? 'Membuat file PDF...' : 'Membuat file ZIP...'),
            ],
          ),
        ),
      );

      final String? exportPath;
      if (isPdfExport) {
        exportPath = await _cameraService.exportInspectionPhotosAsPdf(
          widget.shipType.id!,
          widget.shipType.name,
          widget.company.name,
          customPath: actualPath,
          inspectionDate: widget.shipType.inspectionDate,
        );
      } else {
        exportPath = await _cameraService.exportInspectionPhotosAsZip(
          widget.shipType.id!,
          widget.shipType.name,
          widget.company.name,
          customPath: actualPath,
        );
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (exportPath != null) {
        if (mounted) {
          // Show success dialog with file location
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Export Berhasil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPdfExport ? 'File PDF berhasil dibuat:' : 'File ZIP berhasil dibuat:'),
                  const SizedBox(height: 8),
                  Text(
                    exportPath?.split('/').last ?? 'Unknown file',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Lokasi penyimpanan:'),
                  const SizedBox(height: 4),
                  Text(
                    exportPath ?? 'Unknown path',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (exportPath?.contains('Download') ?? false)
                          ? 'File disimpan di folder Downloads/ShipInspectorExports'
                          : (exportPath?.contains('Documents') ?? false)
                              ? 'File disimpan di folder Documents/ShipInspectorExports'
                              : 'File disimpan di folder aplikasi',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      // Get ShipInspectorExports folder path instead of specific file
                      String folderPath;
                      if (Platform.isAndroid) {
                        final Directory? downloadsDir = await getExternalStorageDirectory();
                        if (downloadsDir != null) {
                          folderPath = '${downloadsDir.path}/ShipInspectorExports';
                        } else {
                          folderPath = '/storage/emulated/0/Download/ShipInspectorExports';
                        }
                      } else if (Platform.isWindows) {
                        final Directory? documentsDir = await getApplicationDocumentsDirectory();
                        if (documentsDir != null) {
                          folderPath = '${documentsDir.path}\\ShipInspectorExports';
                        } else {
                          folderPath = 'Documents\\ShipInspectorExports';
                        }
                      } else {
                        folderPath = exportPath ?? '/storage/emulated/0/Download/ShipInspectorExports'; // Fallback to original path or default
                      }
                      
                      debugPrint('Opening ShipInspectorExports folder: $folderPath');
                      
                      if (Platform.isAndroid) {
                        // Android: Use intent to open file manager
                        try {
                          const platform = MethodChannel('flutter.native/helper');
                          await platform.invokeMethod('openFileManager', {
                            'path': folderPath,
                          });
                          debugPrint('Android file manager opened successfully');
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Membuka folder ShipInspectorExports...'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Failed to open Android file manager: $e');
                          // Fallback: Show path in snackbar
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Folder ShipInspectorExports:'),
                                    const SizedBox(height: 4),
                                    Text(
                                      folderPath,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Buka file manager dan navigasi ke lokasi tersebut'),
                                  ],
                                ),
                                duration: const Duration(seconds: 8),
                              ),
                            );
                          }
                        }
                      } else if (Platform.isWindows) {
                        // Windows: Use explorer command to open ShipInspectorExports folder
                        String windowsPath = folderPath.replaceAll('/', '\\');
                        debugPrint('Windows folder path: $windowsPath');
                        
                        // Open the ShipInspectorExports folder directly
                        final result = await Process.run('cmd', ['/c', 'explorer', windowsPath]);
                        debugPrint('Explorer result: ${result.exitCode}');
                        debugPrint('Explorer stdout: ${result.stdout}');
                        debugPrint('Explorer stderr: ${result.stderr}');
                        
                        if (result.exitCode != 0) {
                          // Fallback 1: Extract directory and open it
                          final lastBackslash = windowsPath.lastIndexOf('\\');
                          String directory = lastBackslash > 0 ? windowsPath.substring(0, lastBackslash) : windowsPath;
                          debugPrint('Fallback: opening directory: $directory');
                          
                          final result2 = await Process.run('cmd', ['/c', 'explorer', directory]);
                          debugPrint('Directory explorer result: ${result2.exitCode}');
                          
                          if (result2.exitCode != 0) {
                            // Fallback 2: Use start command
                            final result3 = await Process.run('cmd', ['/c', 'start', directory]);
                            debugPrint('Start command result: ${result3.exitCode}');
                          }
                        }
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Membuka folder ShipInspectorExports...'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        // Other platforms: Show path info
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Folder ShipInspectorExports:'),
                                  const SizedBox(height: 4),
                                  Text(
                                    folderPath,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 5),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('Error opening folder: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tidak dapat membuka folder: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Buka Folder'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada foto untuk di-export')),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating ZIP: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.shipType.name} - ${widget.company.name}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportPhotosAsZip,
            tooltip: 'Export ZIP',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewInspectionItem,
            tooltip: 'Tambah Item Inspeksi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inspectionItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.checklist,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tidak ada item inspeksi',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addNewInspectionItem,
                        child: const Text('Tambah Item Inspeksi'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Inspeksi ${widget.shipType.name}:',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildGroupedInspectionItems(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGroupedInspectionItems() {
    final groupedItems = _groupItemsByCategory();
    final categories = groupedItems.keys.where((key) => key != '__ITEMS_WITHOUT_CATEGORY__').toList()..sort();
    final itemsWithoutCategory = groupedItems['__ITEMS_WITHOUT_CATEGORY__'] ?? [];

    return ListView(
      children: [
        // Display categorized items in cards
        ...categories.map((categoryName) {
          final items = groupedItems[categoryName]!;
          final isCollapsed = _categoryCollapsedState[categoryName] ?? false;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header - Now clickable
                InkWell(
                  onTap: () {
                    setState(() {
                      _categoryCollapsedState[categoryName] = !isCollapsed;
                    });
                  },
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCollapsed ? Icons.expand_more : Icons.expand_less,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.category,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length} item${items.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Items in this category - Only show if not collapsed
                if (!isCollapsed)
                  ...items.map((item) => _buildInspectionItemCard(item)),
              ],
            ),
          );
        }),
        
        // Display items without category as loose items (not in cards)
        if (itemsWithoutCategory.isNotEmpty) ...[
          if (categories.isNotEmpty) const SizedBox(height: 16),
          ...itemsWithoutCategory.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildInspectionItemCard(item),
          )),
        ],
      ],
    );
  }

  Widget _buildInspectionItemCard(InspectionItem item) {
    final photos = _itemPhotos[item.id!] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editInspectionItem(item);
                      } else if (value == 'delete') {
                        _deleteInspectionItem(item);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit Item'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus Item'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 12),
              if (photos.isNotEmpty)
                PhotoGridWidget(
                  photos: photos,
                  onDeletePhoto: (photo) => _deletePhoto(photo, item.id!),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPhotoOptions(item),
                      icon: const Icon(Icons.add_a_photo),
                      label: Text(
                        photos.isEmpty 
                            ? 'Tambah Foto' 
                            : 'Tambah Foto (${photos.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
