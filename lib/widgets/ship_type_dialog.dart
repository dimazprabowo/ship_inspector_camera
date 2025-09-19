import 'package:flutter/material.dart';
import '../models/ship_type.dart';
import '../services/database_helper.dart';

class ShipTypeDialog extends StatefulWidget {
  final ShipType? shipType; // null for add, existing ship type for edit
  final int companyId;

  const ShipTypeDialog({super.key, this.shipType, required this.companyId});

  @override
  State<ShipTypeDialog> createState() => _ShipTypeDialogState();
}

class _ShipTypeDialogState extends State<ShipTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.shipType != null) {
      _nameController.text = widget.shipType!.name;
      _descriptionController.text = widget.shipType!.description ?? '';
      _selectedDate = widget.shipType!.inspectionDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveShipType() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.shipType == null) {
        // Add new ship type
        final shipType = ShipType(
          id: widget.shipType?.id,
          name: _nameController.text.trim(),
          companyId: widget.companyId,
          description: _descriptionController.text.trim(),
          inspectionDate: _selectedDate,
          createdAt: widget.shipType?.createdAt ?? DateTime.now(),
        );
        
        final shipTypeId = await _dbHelper.insertShipType(shipType);
        final savedShipType = shipType.copyWith(id: shipTypeId);
        
        if (mounted) {
          Navigator.pop(context, savedShipType);
        }
      } else {
        // Update existing ship type
        final updatedShipType = widget.shipType!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          inspectionDate: _selectedDate,
        );
        
        await _dbHelper.updateShipType(updatedShipType);
        
        if (mounted) {
          Navigator.pop(context, true); // Return true untuk menandakan berhasil update
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving ship type: $e')),
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
    final isEditing = widget.shipType != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Edit Jenis Kapal' : 'Tambah Jenis Kapal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Jenis Kapal *',
                  hintText: 'Contoh: Tugboat, Cargo Ship, Tanker',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama jenis kapal harus diisi';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Tanggal Inspeksi (Opsional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                  ),
                ),
                controller: TextEditingController(
                  text: _selectedDate != null 
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  hintText: 'Deskripsi jenis kapal',
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
          onPressed: _isLoading ? null : _saveShipType,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Simpan'),
        ),
      ],
    );
  }
}
