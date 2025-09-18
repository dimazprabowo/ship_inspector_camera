import 'package:flutter/material.dart';
import '../models/inspection_item.dart';
import '../models/parent_category.dart';
import '../services/database_helper.dart';

class EditInspectionItemDialog extends StatefulWidget {
  final InspectionItem item;

  const EditInspectionItemDialog({super.key, required this.item});

  @override
  State<EditInspectionItemDialog> createState() => _EditInspectionItemDialogState();
}

class _EditInspectionItemDialogState extends State<EditInspectionItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ParentCategory> _parentCategories = [];
  ParentCategory? _selectedParentCategory;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _loadParentCategories();
  }

  Future<void> _loadParentCategories() async {
    try {
      final categories = await _dbHelper.getAllParentCategories();
      setState(() {
        _parentCategories = categories;
        // Set selected category if item has one and it still exists
        if (widget.item.parentId != null) {
          try {
            _selectedParentCategory = categories.firstWhere(
              (cat) => cat.id == widget.item.parentId,
            );
          } catch (e) {
            // Parent category was deleted, so we don't select any category
            _selectedParentCategory = null;
          }
        }
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

  Future<void> _updateItem() async {
    if (_formKey.currentState!.validate()) {
      final updatedItem = widget.item.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        parentId: _selectedParentCategory?.id,
        parentName: _selectedParentCategory?.name,
      );

      await _dbHelper.updateInspectionItem(updatedItem);
      
      if (mounted) {
        Navigator.pop(context, updatedItem);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item Inspeksi'),
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
                labelText: 'Judul Item',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul item tidak boleh kosong';
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
              maxLines: 3,
            ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _updateItem,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
