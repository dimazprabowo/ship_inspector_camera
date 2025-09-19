import 'package:flutter/material.dart';
import '../models/inspection_preset.dart';
import '../models/inspection_preset_item.dart';
import '../models/parent_category.dart';
import '../services/database_helper.dart';

class PresetItemData {
  final int? id;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  int sortOrder;
  ParentCategory? selectedParentCategory;

  PresetItemData({
    this.id,
    required this.titleController,
    required this.descriptionController,
    required this.sortOrder,
    this.selectedParentCategory,
  });
}

class EditPresetDialog extends StatefulWidget {
  final InspectionPreset preset;
  final Function(InspectionPreset) onPresetUpdated;

  const EditPresetDialog({
    super.key,
    required this.preset,
    required this.onPresetUpdated,
  });

  @override
  _EditPresetDialogState createState() => _EditPresetDialogState();
}

class _EditPresetDialogState extends State<EditPresetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<PresetItemData> _items = [];
  List<ParentCategory> _parentCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.preset.name;
    _descriptionController.text = widget.preset.description;
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadParentCategories();
    await _loadPresetItems();
  }

  Future<void> _loadParentCategories() async {
    try {
      final categories = await _dbHelper.getAllParentCategories();
      setState(() {
        _parentCategories = categories;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _loadPresetItems() async {
    try {
      final items = await _dbHelper.getInspectionPresetItems(widget.preset.id!);
      setState(() {
        _items = items.map((item) {
          ParentCategory? selectedCategory;
          if (item.parentId != null) {
            try {
              selectedCategory = _parentCategories.firstWhere(
                (cat) => cat.id == item.parentId,
              );
            } catch (e) {
              // Category not found in current list, create a placeholder
              selectedCategory = null;
            }
          }
          
          return PresetItemData(
            id: item.id,
            titleController: TextEditingController(text: item.title),
            descriptionController: TextEditingController(text: item.description),
            sortOrder: item.sortOrder,
            selectedParentCategory: selectedCategory,
          );
        }).toList();
      });
      
      if (_items.isEmpty) {
        _addNewItem();
      }
    } catch (e) {
      debugPrint('Error loading preset items: $e');
      _addNewItem();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var item in _items) {
      item.titleController.dispose();
      item.descriptionController.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _items.add(PresetItemData(
        titleController: TextEditingController(),
        descriptionController: TextEditingController(),
        sortOrder: _items.length + 1,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].titleController.dispose();
        _items[index].descriptionController.dispose();
        _items.removeAt(index);
        // Update sort orders
        for (int i = 0; i < _items.length; i++) {
          _items[i].sortOrder = i + 1;
        }
      });
    }
  }

  Future<void> _savePreset() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Update preset
        final updatedPreset = InspectionPreset(
          id: widget.preset.id,
          name: _nameController.text,
          description: _descriptionController.text,
          companyId: widget.preset.companyId,
          createdAt: widget.preset.createdAt,
        );

        await _dbHelper.updateInspectionPreset(updatedPreset);

        // Delete existing items first
        final existingItems = await _dbHelper.getInspectionPresetItems(widget.preset.id!);
        for (var item in existingItems) {
          await _dbHelper.deleteInspectionPresetItem(item.id!);
        }

        // Save new preset items
        for (var itemData in _items) {
          if (itemData.titleController.text.trim().isNotEmpty) {
            final presetItem = InspectionPresetItem(
              presetId: widget.preset.id!,
              title: itemData.titleController.text.trim(),
              description: itemData.descriptionController.text.trim(),
              parentId: itemData.selectedParentCategory?.id,
              parentName: itemData.selectedParentCategory?.name,
              sortOrder: itemData.sortOrder,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            );
            await _dbHelper.insertInspectionPresetItem(presetItem);
          }
        }

        widget.onPresetUpdated(updatedPreset);

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template "${updatedPreset.name}" berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Template Inspeksi'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Template',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama template tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Item Inspeksi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Parent Category Dropdown
                            DropdownButtonFormField<ParentCategory?>(
                              value: item.selectedParentCategory,
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _parentCategories.map((category) {
                                return DropdownMenuItem<ParentCategory?>(
                                  value: category,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (ParentCategory? newValue) {
                                setState(() {
                                  item.selectedParentCategory = newValue;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  child: Text('${item.sortOrder}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: item.titleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Judul Item',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Judul tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (_items.length > 1)
                                  IconButton(
                                    onPressed: () => _removeItem(index),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: item.descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Deskripsi (Opsional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addNewItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Item'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePreset,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
