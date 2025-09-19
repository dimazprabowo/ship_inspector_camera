import 'package:flutter/material.dart';
import '../models/inspection_preset.dart';
import '../models/inspection_preset_item.dart';
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
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
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
          SnackBar(
            content: Text('Error loading presets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPresetItems(InspectionPreset preset) async {
    try {
      final items = await _dbHelper.getInspectionPresetItems(preset.id!);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => PresetItemsDialog(
            preset: preset,
            items: items,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading preset items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Template Management - ${widget.company.name}'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPresetDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? _buildEmptyState()
              : _buildPresetsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.list_alt_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No templates found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first inspection template',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPresetDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _presets.length,
      itemBuilder: (context, index) {
        final preset = _presets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.list_alt,
                color: Colors.blue.shade600,
                size: 28,
              ),
            ),
            title: Text(
              preset.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: preset.description != null && preset.description!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      preset.description!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
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
                    _showDeleteConfirmation(preset);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('View Items'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onTap: () => _showPresetItems(preset),
          ),
        );
      },
    );
  }

  void _showAddPresetDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPresetDialog(
        companyId: widget.company.id!,
        onPresetAdded: (preset) {
          _loadPresets();
        },
      ),
    );
  }

  void _showEditPresetDialog(InspectionPreset preset) {
    showDialog(
      context: context,
      builder: (context) => EditPresetDialog(
        preset: preset,
        onPresetUpdated: (updatedPreset) {
          _loadPresets();
        },
      ),
    );
  }

  void _showDeleteConfirmation(InspectionPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deletePreset(preset);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePreset(InspectionPreset preset) async {
    try {
      await _dbHelper.deleteInspectionPreset(preset.id!);
      _loadPresets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${preset.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Separate StatefulWidget for the preset items dialog
class PresetItemsDialog extends StatefulWidget {
  final InspectionPreset preset;
  final List<InspectionPresetItem> items;

  const PresetItemsDialog({
    super.key,
    required this.preset,
    required this.items,
  });

  @override
  State<PresetItemsDialog> createState() => _PresetItemsDialogState();
}

class _PresetItemsDialogState extends State<PresetItemsDialog> {
  Map<String, bool> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.list_alt,
            color: Colors.blue.shade600,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Template: ${widget.preset.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: widget.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada item dalam template ini',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : _buildGroupedPresetItems(widget.items),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Tutup'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedPresetItems(List<InspectionPresetItem> items) {
    // Group items by category
    final Map<String, List<InspectionPresetItem>> groupedItems = {};
    
    for (final item in items) {
      final categoryName = item.parentName ?? 'Tanpa Kategori';
      if (!groupedItems.containsKey(categoryName)) {
        groupedItems[categoryName] = [];
      }
      groupedItems[categoryName]!.add(item);
    }

    // Sort categories, with "Tanpa Kategori" at the end
    final sortedCategories = groupedItems.keys.toList()..sort((a, b) {
      if (a == 'Tanpa Kategori') return 1;
      if (b == 'Tanpa Kategori') return -1;
      return a.compareTo(b);
    });

    // Initialize expanded state for categories
    for (final category in sortedCategories) {
      _expandedCategories[category] ??= true; // Default to expanded
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${items.length} item dalam ${groupedItems.length} kategori',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                // Expand/Collapse all button
                TextButton.icon(
                  onPressed: () {
                    final allExpanded = _expandedCategories.values.every((expanded) => expanded);
                    setState(() {
                      for (final category in sortedCategories) {
                        _expandedCategories[category] = !allExpanded;
                      }
                    });
                  },
                  icon: Icon(
                    _expandedCategories.values.every((expanded) => expanded)
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _expandedCategories.values.every((expanded) => expanded)
                        ? 'Tutup Semua'
                        : 'Buka Semua',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          
          // Category sections
          ...sortedCategories.map((categoryName) {
            final categoryItems = groupedItems[categoryName]!;
            final isExpanded = _expandedCategories[categoryName] ?? true;
            final isUncategorized = categoryName == 'Tanpa Kategori';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUncategorized ? Colors.orange.shade200 : Colors.blue.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header with expand/collapse functionality
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedCategories[categoryName] = !isExpanded;
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
                        gradient: LinearGradient(
                          colors: isUncategorized 
                              ? [Colors.orange.shade100, Colors.orange.shade200]
                              : [Colors.blue.shade100, Colors.blue.shade200],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isExpanded ? Radius.zero : const Radius.circular(12),
                          bottomRight: isExpanded ? Radius.zero : const Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isUncategorized ? Colors.orange.shade300 : Colors.blue.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isUncategorized ? Icons.help_outline : Icons.category,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isUncategorized ? Colors.orange.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${categoryItems.length} item${categoryItems.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isUncategorized ? Colors.orange.shade700 : Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Expand/Collapse icon
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.expand_more,
                              color: isUncategorized ? Colors.orange.shade700 : Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Category items with animation
                  if (isExpanded)
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: categoryItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isLastItem = index == categoryItems.length - 1;

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: isLastItem 
                                    ? BorderSide.none 
                                    : BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 0.5,
                                      ),
                              ),
                              borderRadius: isLastItem 
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.sortOrder}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: item.description != null && item.description!.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.description!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,

                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
