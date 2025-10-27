import 'package:flutter/material.dart';
import '../models/company.dart';
import '../models/ship_type.dart';
import '../models/inspection_preset.dart';
import '../services/database_helper.dart';
import '../widgets/add_ship_type_dialog.dart';
import '../widgets/ship_type_dialog.dart';
import '../widgets/add_preset_dialog.dart';
import '../widgets/edit_preset_dialog.dart';
import 'inspection_screen.dart';
import 'parent_category_management_screen.dart';
import 'preset_management_screen.dart';

class ShipTypeSelectionScreen extends StatefulWidget {
  final Company company;

  const ShipTypeSelectionScreen({super.key, required this.company});

  @override
  State<ShipTypeSelectionScreen> createState() => _ShipTypeSelectionScreenState();
}

class _ShipTypeSelectionScreenState extends State<ShipTypeSelectionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ShipType> _shipTypes = [];
  List<InspectionPreset> _presets = [];
  late Company _currentCompany;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentCompany = widget.company;
    _loadShipTypes();
  }

  Future<void> _loadShipTypes() async {
    try {
      final shipTypes = await _dbHelper.getShipTypesByCompany(widget.company.id!);
      final presets = await _dbHelper.getInspectionPresetsByCompany(widget.company.id!);
      setState(() {
        _shipTypes = shipTypes;
        _presets = presets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ship types: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToInspection(ShipType shipType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionScreen(
          company: widget.company,
          shipType: shipType,
        ),
      ),
    );
  }

  Future<void> _addShipType() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddShipTypeDialog(companyId: widget.company.id!),
    );

    if (result == true) {
      await _loadShipTypes();
    }
  }

  Future<void> _editShipType(ShipType shipType) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ShipTypeDialog(shipType: shipType, companyId: widget.company.id!),
    );

    if (result == true) {
      await _loadShipTypes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jenis kapal berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteShipType(ShipType shipType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Jenis Kapal'),
        content: Text('Apakah Anda yakin ingin menghapus "${shipType.name}"?\n\nSemua data inspeksi terkait akan ikut terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteShipType(shipType.id!);
        await _loadShipTypes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jenis kapal berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting ship type: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Preset Management Functions
  Future<void> _showAddPresetDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddPresetDialog(
        companyId: _currentCompany.id!,
        onPresetAdded: (preset) {
          setState(() {
            _presets.add(preset);
          });
        },
      ),
    );

    if (result == true) {
      _loadShipTypes();
    }
  }

  Future<void> _showEditPresetDialog(InspectionPreset preset) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditPresetDialog(
        preset: preset,
        onPresetUpdated: (updatedPreset) {
          setState(() {
            final index = _presets.indexWhere((p) => p.id == updatedPreset.id);
            if (index != -1) {
              _presets[index] = updatedPreset;
            }
          });
        },
      ),
    );

    if (result == true) {
      _loadShipTypes();
    }
  }

  Future<void> _deletePreset(InspectionPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Template'),
        content: Text('Apakah Anda yakin ingin menghapus template "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteInspectionPreset(preset.id!);
        _loadShipTypes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template "${preset.name}" berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jenis Kapal - ${widget.company.name}'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'manage_presets') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PresetManagementScreen(company: _currentCompany),
                  ),
                );
              } else if (value == 'manage_parent_categories') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ParentCategoryManagementScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_presets',
                child: ListTile(
                  leading: Icon(Icons.inventory_2),
                  title: Text('Kelola Template'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'manage_parent_categories',
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('Kelola Kategori'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shipTypes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_boat,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada jenis kapal tersedia',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
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
                        'Pilih jenis kapal untuk ${widget.company.name}:',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _shipTypes.length,
                          itemBuilder: (context, index) {
                            final shipType = _shipTypes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: const Icon(
                                    Icons.directions_boat,
                                    color: Colors.orange,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  shipType.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (shipType.inspectionDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.blue[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatIndonesianDate(shipType.inspectionDate!),
                                              style: TextStyle(
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (shipType.description != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          shipType.description!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'select',
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_forward, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Pilih'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Hapus'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'select':
                                        _navigateToInspection(shipType);
                                        break;
                                      case 'edit':
                                        _editShipType(shipType);
                                        break;
                                      case 'delete':
                                        _deleteShipType(shipType);
                                        break;
                                    }
                                  },
                                ),
                                onTap: () => _navigateToInspection(shipType),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShipType,
        tooltip: 'Tambah Jenis Kapal',
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatIndonesianDate(DateTime date) {
    const List<String> months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
