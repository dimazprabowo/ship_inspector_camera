import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/database_helper.dart';
import '../services/master_template_service.dart';
import 'template_selection_dialog.dart';

class CompanyDialog extends StatefulWidget {
  final Company? company; // null for add, existing company for edit

  const CompanyDialog({super.key, this.company});

  @override
  State<CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<CompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  List<MasterTemplate> _selectedTemplates = [];

  @override
  void initState() {
    super.initState();
    if (widget.company != null) {
      _nameController.text = widget.company!.name;
      _descriptionController.text = widget.company!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.company == null) {
        // Add new company
        final newCompany = Company(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          createdAt: DateTime.now(),
        );
        
        final companyId = await _dbHelper.insertCompany(newCompany);
        final savedCompany = newCompany.copyWith(id: companyId);
        
        // Create templates for the new company
        try {
          if (_selectedTemplates.isNotEmpty) {
            // Create templates from selected master templates
            for (var template in _selectedTemplates) {
              await _dbHelper.createTemplateFromMasterTemplateObject(companyId, template);
            }
          } else {
            // Create default Master Template
            await _dbHelper.createMasterTemplate(companyId);
          }
        } catch (e) {
          // Log error but don't block company creation
          debugPrint('Warning: Failed to create template: $e');
        }
        
        if (mounted) {
          Navigator.pop(context, savedCompany);
        }
      } else {
        // Update existing company
        final updatedCompany = widget.company!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
        );
        
        await _dbHelper.updateCompany(updatedCompany);
        
        if (mounted) {
          Navigator.pop(context, updatedCompany);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving company: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTemplate() async {
    final templates = await showDialog<List<MasterTemplate>>(
      context: context,
      builder: (context) => const TemplateSelectionDialog(),
    );
    
    if (templates != null && templates.isNotEmpty) {
      setState(() {
        _selectedTemplates = templates;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.company != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Edit Perusahaan' : 'Tambah Perusahaan'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Perusahaan *',
                hintText: 'Contoh: PT. Pelayaran Indonesia',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama perusahaan harus diisi';
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
                hintText: 'Deskripsi perusahaan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (!isEditing) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.list_alt,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Template',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedTemplates.isNotEmpty
                          ? _selectedTemplates.length == 1
                              ? _selectedTemplates.first.templateName
                              : '${_selectedTemplates.length} template dipilih'
                          : 'Master Template (Default)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_selectedTemplates.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedTemplates.length == 1
                            ? _selectedTemplates.first.templateDescription
                            : _selectedTemplates.map((t) => t.templateName).join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _selectTemplate,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Pilih Template'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          onPressed: _isLoading ? null : _saveCompany,
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
