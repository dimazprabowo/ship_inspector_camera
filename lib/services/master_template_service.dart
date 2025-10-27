import 'dart:convert';
import 'package:flutter/services.dart';

class MasterTemplate {
  final String templateName;
  final String templateDescription;
  final List<MasterTemplateCategory> categories;

  MasterTemplate({
    required this.templateName,
    required this.templateDescription,
    required this.categories,
  });

  factory MasterTemplate.fromJson(Map<String, dynamic> json) {
    return MasterTemplate(
      templateName: json['template_name'] as String,
      templateDescription: json['template_description'] as String,
      categories: (json['categories'] as List)
          .map((cat) => MasterTemplateCategory.fromJson(cat))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template_name': templateName,
      'template_description': templateDescription,
      'categories': categories.map((cat) => cat.toJson()).toList(),
    };
  }
}

class MasterTemplateCategory {
  final String name;
  final List<MasterTemplateSubcategory> subcategories;

  MasterTemplateCategory({
    required this.name,
    required this.subcategories,
  });

  factory MasterTemplateCategory.fromJson(Map<String, dynamic> json) {
    return MasterTemplateCategory(
      name: json['name'] as String,
      subcategories: (json['subcategories'] as List)
          .map((sub) => MasterTemplateSubcategory.fromJson(sub))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'subcategories': subcategories.map((sub) => sub.toJson()).toList(),
    };
  }
}

class MasterTemplateSubcategory {
  final String name;
  final String description;

  MasterTemplateSubcategory({
    required this.name,
    required this.description,
  });

  factory MasterTemplateSubcategory.fromJson(Map<String, dynamic> json) {
    return MasterTemplateSubcategory(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

class MasterTemplateService {
  static final MasterTemplateService _instance = MasterTemplateService._internal();
  factory MasterTemplateService() => _instance;
  MasterTemplateService._internal();

  Map<String, MasterTemplate> _cachedTemplates = {};

  // List of available template files
  static const List<String> _templateFiles = [
    'assets/master_templates/master_template.json',
    'assets/master_templates/kapal_penumpang.json',
    'assets/master_templates/kapal_tugboat.json',
    'assets/master_templates/kapal_kargo.json',
  ];

  /// Load a specific template from JSON file
  Future<MasterTemplate> loadTemplate(String filePath) async {
    // Return cached data if available
    if (_cachedTemplates.containsKey(filePath)) {
      return _cachedTemplates[filePath]!;
    }

    try {
      // Load JSON file from assets
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      // Parse template
      final template = MasterTemplate.fromJson(jsonData);
      _cachedTemplates[filePath] = template;
      
      return template;
    } catch (e) {
      throw Exception('Failed to load template from $filePath: $e');
    }
  }

  /// Load all available templates
  Future<List<MasterTemplate>> loadAllTemplates() async {
    final List<MasterTemplate> templates = [];
    
    for (final filePath in _templateFiles) {
      try {
        final template = await loadTemplate(filePath);
        templates.add(template);
      } catch (e) {
        // Log error but continue loading other templates
        print('Warning: Failed to load template $filePath: $e');
      }
    }
    
    return templates;
  }

  /// Get template by name
  Future<MasterTemplate?> getTemplateByName(String templateName) async {
    final templates = await loadAllTemplates();
    try {
      return templates.firstWhere(
        (template) => template.templateName == templateName,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get default template (Master Template)
  Future<MasterTemplate> getDefaultTemplate() async {
    return await loadTemplate('assets/master_templates/master_template.json');
  }

  /// Get all available template names
  Future<List<String>> getAvailableTemplateNames() async {
    final templates = await loadAllTemplates();
    return templates.map((t) => t.templateName).toList();
  }

  /// Clear cache (useful for testing or if JSON file is updated)
  void clearCache() {
    _cachedTemplates.clear();
  }
}
