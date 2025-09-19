import 'package:flutter/material.dart';
import '../models/inspection_preset.dart';
import '../models/company.dart';
import '../services/database_helper.dart';
import '../widgets/add_preset_dialog.dart';
import '../widgets/edit_preset_dialog.dart';

class PresetManagementScreen extends StatefulWidget {
  final Company company;
  
  const PresetManagementScreen({
    super.key,
    required this.company,
  });

  @override
  _PresetManagementScreenState createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<InspectionPreset> _presets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final presets = await _dbHelper.getInspectionPresetsByCompany(widget.company.id!);
      setState(() {
        _presets = presets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading presets: $e')),
        );
      }
    }
  }

  Future<void> _showAddPresetDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddPresetDialog(
        companyId: widget.company.id!,
        onPresetAdded: (preset) {
          // Preset added callback
        },
      ),
    );

    if (result == true) {
      _loadPresets();
    }
  }

  Future<void> _showEditPresetDialog(InspectionPreset preset) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditPresetDialog(
        preset: preset,
        onPresetUpdated: (updatedPreset) {
          // Preset updated callback
        },
      ),
    );

    if (result == true) {
      _loadPresets();
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
        _loadPresets();
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

  Future<void> _showPresetItems(InspectionPreset preset) async {
    try {
      final items = await _dbHelper.getInspectionPresetItems(preset.id!);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Item Template: ${preset.name}'),
            content: SizedBox(
              width: double.maxFinite,
              child: items.isEmpty
                  ? const Text('Tidak ada item dalam template ini')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${item.sortOrder}'),
                          ),
                          title: Text(item.title),
                          subtitle: item.description.isNotEmpty 
                              ? Text(item.description)
                              : null,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preset items: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Template - ${widget.company.name}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPresetDialog,
            tooltip: 'Tambah Template',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada template inspeksi',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap tombol + untuk menambah template baru',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _presets.length,
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.inventory_2, color: Colors.white),
                        ),
                        title: Text(
                          preset.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: preset.description.isNotEmpty
                            ? Text(preset.description)
                            : Text(
                                'Dibuat: ${DateTime.fromMillisecondsSinceEpoch(preset.createdAt).toString().split(' ')[0]}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _showPresetItems(preset);
                                break;
                              case 'edit':
                                _showEditPresetDialog(preset);
                                break;
                              case 'delete':
                                _deletePreset(preset);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Lihat Item'),
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
                        ),
                        onTap: () => _showPresetItems(preset),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPresetDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
