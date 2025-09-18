import 'package:flutter/material.dart';
import '../models/inspection_item.dart';
import '../models/parent_category.dart';
import '../services/database_helper.dart';

class AddInspectionItemDialog extends StatefulWidget {
  final int shipTypeId;

  const AddInspectionItemDialog({super.key, required this.shipTypeId});

  @override
  State<AddInspectionItemDialog> createState() => _AddInspectionItemDialogState();
}

class _AddInspectionItemDialogState extends State<AddInspectionItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  List<ParentCategory> _parentCategories = [];
  ParentCategory? _selectedParentCategory;

  @override
  void initState() {
    super.initState();
    _loadParentCategories();
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveInspectionItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current items count to set sort order
      final existingItems = await _dbHelper.getInspectionItemsByShipType(widget.shipTypeId);
      
      final newItem = InspectionItem(
        title: _titleController.text.trim(),
        shipTypeId: widget.shipTypeId,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        sortOrder: existingItems.length + 1,
        createdAt: DateTime.now(),
        parentId: _selectedParentCategory?.id,
        parentName: _selectedParentCategory?.name,
      );

      final itemId = await _dbHelper.insertInspectionItem(newItem);
      final savedItem = newItem.copyWith(id: itemId);

      if (mounted) {
        Navigator.pop(context, savedItem);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Item Inspeksi'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            DropdownButtonFormField<ParentCategory?>(
              value: _selectedParentCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'Pilih kategori (opsional)',
                border: OutlineInputBorder(),
              ),
              items: [
                // const DropdownMenuItem<ParentCategory?>(
                //   value: null,
                //   child: Text('Tanpa Kategori'),
                // ),
                ..._parentCategories.map((category) {
                  return DropdownMenuItem<ParentCategory?>(
                    value: category,
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
              ],
              onChanged: (ParentCategory? value) {
                setState(() {
                  _selectedParentCategory = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Item *',
                hintText: 'Contoh: Lambung Depan',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul item harus diisi';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (Opsional)',
                hintText: 'Deskripsi detail item inspeksi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveInspectionItem,
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
