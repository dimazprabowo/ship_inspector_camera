import 'package:flutter/material.dart';
import '../models/ship_type.dart';
import '../models/inspection_preset.dart';
import '../services/database_helper.dart';

class AddShipTypeDialog extends StatefulWidget {
  final int companyId;

  const AddShipTypeDialog({super.key, required this.companyId});

  @override
  _AddShipTypeDialogState createState() => _AddShipTypeDialogState();
}

class _AddShipTypeDialogState extends State<AddShipTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<InspectionPreset> _presets = [];
  InspectionPreset? _selectedPreset;
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await _dbHelper.getInspectionPresetsByCompany(widget.companyId);
      setState(() {
        _presets = presets;
      });
    } catch (e) {
      debugPrint('Error loading presets: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveShipType() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final shipType = ShipType(
          name: _nameController.text,
          companyId: widget.companyId,
          description: _descriptionController.text.trim(),
          inspectionDate: _selectedDate,
          createdAt: DateTime.now(),
        );

        final shipTypeId = await _dbHelper.insertShipType(shipType);

        // Apply preset if selected
        if (_selectedPreset != null) {
          await _dbHelper.applyPresetToShipType(_selectedPreset!.id!, shipTypeId);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_selectedPreset != null 
                  ? 'Jenis kapal berhasil ditambahkan dengan preset ${_selectedPreset!.name}'
                  : 'Jenis kapal berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Jenis Kapal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Jenis Kapal',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama jenis kapal tidak boleh kosong';
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
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Pilih Template Inspeksi (Opsional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Template akan otomatis menambahkan item inspeksi standar',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InspectionPreset>(
                initialValue: _selectedPreset,
                decoration: const InputDecoration(
                  labelText: 'Template Inspeksi',
                  border: OutlineInputBorder(),
                ),
                selectedItemBuilder: (BuildContext context) {
                  return [
                    const Text('Tanpa Template'),
                    ..._presets.map((preset) => Text(
                      preset.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    )),
                  ];
                },
                items: [
                  const DropdownMenuItem<InspectionPreset>(
                    value: null,
                    child: Text('Tanpa Template'),
                  ),
                  ..._presets.map((preset) => DropdownMenuItem<InspectionPreset>(
                    value: preset,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.name, 
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description, 
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                onChanged: (preset) {
                  setState(() {
                    _selectedPreset = preset;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
