import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/company.dart';
import '../models/ship_type.dart';
import '../models/inspection_item.dart';
import '../models/inspection_photo.dart';
import '../models/inspection_preset.dart';
import '../models/inspection_preset_item.dart';
import '../models/parent_category.dart';
import 'master_template_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ship_inspector.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create companies table
    await db.execute('''
      CREATE TABLE companies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create ship_types table
    await db.execute('''
      CREATE TABLE ship_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company_id INTEGER NOT NULL,
        description TEXT,
        inspection_date INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    // Create inspection_items table
    await db.execute('''
      CREATE TABLE inspection_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        ship_type_id INTEGER NOT NULL,
        description TEXT,
        sort_order INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (ship_type_id) REFERENCES ship_types (id)
      )
    ''');

    // Create inspection_photos table
    await db.execute('''
      CREATE TABLE inspection_photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_item_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        captured_at INTEGER NOT NULL,
        FOREIGN KEY (inspection_item_id) REFERENCES inspection_items (id)
      )
    ''');

    // Create inspection_presets table
    await db.execute('''
      CREATE TABLE inspection_presets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        company_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    // Create inspection_preset_items table
    await db.execute('''
      CREATE TABLE inspection_preset_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (preset_id) REFERENCES inspection_presets (id)
      )
    ''');

    // Create parent_categories table
    await db.execute('''
      CREATE TABLE parent_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Add parent_id column to inspection_items table
    await db.execute('ALTER TABLE inspection_items ADD COLUMN parent_id INTEGER');
    
    // Add parent_id column to inspection_preset_items table
    await db.execute('ALTER TABLE inspection_preset_items ADD COLUMN parent_id INTEGER');

    // Create photo_notes table
    await db.execute('''
      CREATE TABLE photo_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (photo_id) REFERENCES inspection_photos (id) ON DELETE CASCADE
      )
    ''');

    // No sample data - let user create their own companies
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create inspection_presets table
      await db.execute('''
        CREATE TABLE inspection_presets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create inspection_preset_items table
      await db.execute('''
        CREATE TABLE inspection_preset_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          preset_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          sort_order INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (preset_id) REFERENCES inspection_presets (id)
        )
      ''');

      // Create Master Template for existing companies
      final companies = await db.query('companies', limit: 1);
      if (companies.isNotEmpty) {
        final companyId = companies.first['id'] as int;
        await _createMasterTemplateInTransaction(db, companyId);
      }
    }
    
    if (oldVersion < 3) {
      // Add inspection_date column to ship_types table
      await db.execute('ALTER TABLE ship_types ADD COLUMN inspection_date INTEGER');
    }
    
    if (oldVersion < 4) {
      // Add company_id column to inspection_presets table
      await db.execute('ALTER TABLE inspection_presets ADD COLUMN company_id INTEGER');
      
      // Update existing presets to belong to the first company
      final companies = await db.query('companies', limit: 1);
      if (companies.isNotEmpty) {
        final firstCompanyId = companies.first['id'];
        await db.execute('UPDATE inspection_presets SET company_id = ? WHERE company_id IS NULL', [firstCompanyId]);
      }
    }
    
    if (oldVersion < 5) {
      // Create parent_categories table
      await db.execute('''
        CREATE TABLE parent_categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      
      // Add parent_id column to inspection_items table
      await db.execute('ALTER TABLE inspection_items ADD COLUMN parent_id INTEGER');
      
      // Add parent_id column to inspection_preset_items table
      await db.execute('ALTER TABLE inspection_preset_items ADD COLUMN parent_id INTEGER');
      
      // Insert some default parent categories
      // await _insertDefaultParentCategories(db);
    }
    
    if (oldVersion < 6) {
      // Create photo_notes table
      await db.execute('''
        CREATE TABLE photo_notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          photo_id INTEGER NOT NULL,
          note TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (photo_id) REFERENCES inspection_photos (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _insertSampleData(Database db) async {
    // Insert sample company
    int companyId = await db.insert('companies', {
      'name': 'PT Pelayaran Nusantara',
      'description': 'Perusahaan pelayaran utama',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Insert sample ship type
    int shipTypeId = await db.insert('ship_types', {
      'name': 'Tugboat',
      'company_id': companyId,
      'description': 'Kapal tunda',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Insert sample inspection item
    await db.insert('inspection_items', {
      'title': 'Lambung Kapal',
      'ship_type_id': shipTypeId,
      'description': 'Foto bagian lambung kapal',
      'sort_order': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Create Master Template for the sample company using the db instance
    await _createMasterTemplateInTransaction(db, companyId);
  }


  // Company CRUD operations
  Future<int> insertCompany(Company company) async {
    final db = await database;
    return await db.insert('companies', company.toMap());
  }

  Future<List<Company>> getCompanies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('companies', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Company.fromMap(maps[i]));
  }

  Future<int> updateCompany(Company company) async {
    final db = await database;
    return await db.update('companies', company.toMap(), where: 'id = ?', whereArgs: [company.id]);
  }

  Future<int> deleteCompany(int id) async {
    final db = await database;
    return await db.delete('companies', where: 'id = ?', whereArgs: [id]);
  }

  // Ship Type CRUD operations
  Future<int> insertShipType(ShipType shipType) async {
    final db = await database;
    return await db.insert('ship_types', shipType.toMap());
  }

  Future<List<ShipType>> getShipTypesByCompany(int companyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ship_types',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => ShipType.fromMap(maps[i]));
  }

  Future<int> updateShipType(ShipType shipType) async {
    final db = await database;
    return await db.update('ship_types', shipType.toMap(), where: 'id = ?', whereArgs: [shipType.id]);
  }

  Future<int> deleteShipType(int id) async {
    final db = await database;
    return await db.delete('ship_types', where: 'id = ?', whereArgs: [id]);
  }

  // Inspection Item CRUD operations
  Future<int> insertInspectionItem(InspectionItem item) async {
    final db = await database;
    return await db.insert('inspection_items', item.toMap());
  }

  Future<List<InspectionItem>> getInspectionItemsByShipType(int shipTypeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        i.*,
        pc.name as parent_name
      FROM inspection_items i
      LEFT JOIN parent_categories pc ON i.parent_id = pc.id
      WHERE i.ship_type_id = ?
      ORDER BY i.sort_order ASC
    ''', [shipTypeId]);
    return List.generate(maps.length, (i) => InspectionItem.fromMap(maps[i]));
  }

  Future<int> updateInspectionItem(InspectionItem item) async {
    final db = await database;
    return await db.update('inspection_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteInspectionItem(int id) async {
    final db = await database;
    return await db.delete('inspection_items', where: 'id = ?', whereArgs: [id]);
  }

  // Inspection Photo CRUD operations
  Future<int> insertInspectionPhoto(InspectionPhoto photo) async {
    final db = await database;
    return await db.insert('inspection_photos', photo.toMap());
  }

  Future<List<InspectionPhoto>> getPhotosByInspectionItem(int inspectionItemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_photos',
      where: 'inspection_item_id = ?',
      whereArgs: [inspectionItemId],
      orderBy: 'captured_at ASC',
    );
    return List.generate(maps.length, (i) => InspectionPhoto.fromMap(maps[i]));
  }

  Future<int> deleteInspectionPhoto(int id) async {
    final db = await database;
    return await db.delete('inspection_photos', where: 'id = ?', whereArgs: [id]);
  }

  // Inspection Preset CRUD operations
  Future<int> insertInspectionPreset(InspectionPreset preset) async {
    final db = await database;
    return await db.insert('inspection_presets', preset.toMap());
  }

  Future<List<InspectionPreset>> getInspectionPresets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('inspection_presets', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => InspectionPreset.fromMap(maps[i]));
  }

  Future<List<InspectionPreset>> getInspectionPresetsByCompany(int companyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_presets',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => InspectionPreset.fromMap(maps[i]));
  }

  Future<int> updateInspectionPreset(InspectionPreset preset) async {
    final db = await database;
    return await db.update('inspection_presets', preset.toMap(), where: 'id = ?', whereArgs: [preset.id]);
  }

  Future<int> deleteInspectionPreset(int id) async {
    final db = await database;
    // Delete preset items first
    await db.delete('inspection_preset_items', where: 'preset_id = ?', whereArgs: [id]);
    // Then delete the preset
    return await db.delete('inspection_presets', where: 'id = ?', whereArgs: [id]);
  }

  // Inspection Preset Item CRUD operations
  Future<int> insertInspectionPresetItem(InspectionPresetItem item) async {
    final db = await database;
    return await db.insert('inspection_preset_items', item.toMap());
  }

  Future<List<InspectionPresetItem>> getInspectionPresetItems(int presetId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        ipi.*,
        pc.name as parent_name
      FROM inspection_preset_items ipi
      LEFT JOIN parent_categories pc ON ipi.parent_id = pc.id
      WHERE ipi.preset_id = ?
      ORDER BY ipi.sort_order ASC
    ''', [presetId]);
    return List.generate(maps.length, (i) => InspectionPresetItem.fromMap(maps[i]));
  }

  Future<int> updateInspectionPresetItem(InspectionPresetItem item) async {
    final db = await database;
    return await db.update('inspection_preset_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteInspectionPresetItem(int id) async {
    final db = await database;
    return await db.delete('inspection_preset_items', where: 'id = ?', whereArgs: [id]);
  }

  // Apply preset to ship type
  Future<void> applyPresetToShipType(int presetId, int shipTypeId) async {
    final presetItems = await getInspectionPresetItems(presetId);
    
    for (var presetItem in presetItems) {
      final inspectionItem = InspectionItem(
        title: presetItem.title,
        shipTypeId: shipTypeId,
        description: presetItem.description,
        sortOrder: presetItem.sortOrder,
        createdAt: DateTime.now(),
        parentId: presetItem.parentId,
        parentName: presetItem.parentName,
      );
      await insertInspectionItem(inspectionItem);
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Insert default parent categories
  // Future<void> _insertDefaultParentCategories(Database db) async {
  //   final now = DateTime.now().millisecondsSinceEpoch;
    
  //   await db.insert('parent_categories', {
  //     'name': 'Konstruksi dan Plat',
  //     'created_at': now,
  //   });

  //   await db.insert('parent_categories', {
  //     'name': 'Ruangan',
  //     'created_at': now,
  //   });
    
  // }

  // Parent Category CRUD operations
  Future<int> insertParentCategory(ParentCategory category) async {
    final db = await database;
    return await db.insert('parent_categories', category.toMap());
  }

  Future<List<ParentCategory>> getAllParentCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parent_categories',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => ParentCategory.fromMap(maps[i]));
  }

  Future<ParentCategory?> getParentCategory(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parent_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ParentCategory.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateParentCategory(ParentCategory category) async {
    final db = await database;
    return await db.update('parent_categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteParentCategory(int id) async {
    final db = await database;
    
    // First, clear parent_id from inspection_items that reference this category
    await db.update(
      'inspection_items', 
      {'parent_id': null}, 
      where: 'parent_id = ?', 
      whereArgs: [id]
    );
    
    // Clear parent_id from inspection_preset_items that reference this category
    await db.update(
      'inspection_preset_items', 
      {'parent_id': null}, 
      where: 'parent_id = ?', 
      whereArgs: [id]
    );
    
    // Then delete the parent category
    return await db.delete('parent_categories', where: 'id = ?', whereArgs: [id]);
  }

  // Photo Notes CRUD operations
  Future<int> insertPhotoNote(int photoId, String note) async {
    final db = await database;
    return await db.insert('photo_notes', {
      'photo_id': photoId,
      'note': note,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String?> getPhotoNote(int photoId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photo_notes',
      where: 'photo_id = ?',
      whereArgs: [photoId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return maps.first['note'] as String;
    }
    return null;
  }

  Future<int> updatePhotoNote(int photoId, String note) async {
    final db = await database;
    // Check if note exists
    final existing = await getPhotoNote(photoId);
    
    if (existing != null) {
      // Update existing note
      return await db.update(
        'photo_notes',
        {
          'note': note,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'photo_id = ?',
        whereArgs: [photoId],
      );
    } else {
      // Insert new note
      return await insertPhotoNote(photoId, note);
    }
  }

  Future<int> deletePhotoNote(int photoId) async {
    final db = await database;
    return await db.delete('photo_notes', where: 'photo_id = ?', whereArgs: [photoId]);
  }

  // Create Master Template for a company (default template)
  Future<int> createMasterTemplate(int companyId) async {
    final masterTemplateService = MasterTemplateService();
    
    try {
      // Load default master template from JSON
      final template = await masterTemplateService.getDefaultTemplate();
      
      return await createTemplateFromMasterTemplateObject(companyId, template);
    } catch (e) {
      throw Exception('Failed to create master template: $e');
    }
  }

  // Create Master Template within a transaction (for _onCreate)
  Future<int> _createMasterTemplateInTransaction(Database db, int companyId) async {
    final masterTemplateService = MasterTemplateService();
    
    try {
      // Load default master template from JSON
      final template = await masterTemplateService.getDefaultTemplate();
      
      // Create preset with template name and description
      final presetId = await db.insert('inspection_presets', {
        'name': template.templateName,
        'description': template.templateDescription,
        'company_id': companyId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Get or create parent categories and insert preset items
      int sortOrder = 1;
      
      for (var category in template.categories) {
        // Get or create parent category
        final parentCategory = await _getOrCreateParentCategoryInTransaction(db, category.name);
        
        // Insert subcategories as preset items
        for (var subcategory in category.subcategories) {
          await db.insert('inspection_preset_items', {
            'preset_id': presetId,
            'title': subcategory.name,
            'description': subcategory.description,
            'sort_order': sortOrder++,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'parent_id': parentCategory.id,
          });
        }
      }
      
      return presetId;
    } catch (e) {
      throw Exception('Failed to create master template in transaction: $e');
    }
  }

  // Helper function to get or create parent category within transaction
  Future<ParentCategory> _getOrCreateParentCategoryInTransaction(Database db, String categoryName) async {
    // Check if category exists
    final List<Map<String, dynamic>> maps = await db.query(
      'parent_categories',
      where: 'name = ?',
      whereArgs: [categoryName],
    );
    
    if (maps.isNotEmpty) {
      return ParentCategory.fromMap(maps.first);
    }
    
    // Create new category if not exists
    final categoryId = await db.insert('parent_categories', {
      'name': categoryName,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    return ParentCategory(
      id: categoryId,
      name: categoryName,
      createdAt: DateTime.now(),
    );
  }

  // Create template from a specific master template file
  Future<int> createTemplateFromMasterTemplate(int companyId, String templateName) async {
    final masterTemplateService = MasterTemplateService();
    
    try {
      // Load specific template by name
      final template = await masterTemplateService.getTemplateByName(templateName);
      
      if (template == null) {
        throw Exception('Template "$templateName" not found');
      }
      
      return await createTemplateFromMasterTemplateObject(companyId, template);
    } catch (e) {
      throw Exception('Failed to create template from master template: $e');
    }
  }

  // Create template from MasterTemplate object
  Future<int> createTemplateFromMasterTemplateObject(int companyId, MasterTemplate template) async {
    // Create preset with template name and description
    final preset = InspectionPreset(
      name: template.templateName,
      description: template.templateDescription,
      companyId: companyId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    
    final presetId = await insertInspectionPreset(preset);
    
    // Get or create parent categories and insert preset items
    int sortOrder = 1;
    
    for (var category in template.categories) {
      // Get or create parent category
      final parentCategory = await _getOrCreateParentCategory(category.name);
      
      // Insert subcategories as preset items
      for (var subcategory in category.subcategories) {
        final presetItem = InspectionPresetItem(
          presetId: presetId,
          title: subcategory.name,
          description: subcategory.description,
          sortOrder: sortOrder++,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          parentId: parentCategory.id,
          parentName: parentCategory.name,
        );
        
        await insertInspectionPresetItem(presetItem);
      }
    }
    
    return presetId;
  }

  // Helper function to get or create parent category
  Future<ParentCategory> _getOrCreateParentCategory(String categoryName) async {
    final db = await database;
    
    // Check if category exists
    final List<Map<String, dynamic>> maps = await db.query(
      'parent_categories',
      where: 'name = ?',
      whereArgs: [categoryName],
    );
    
    if (maps.isNotEmpty) {
      return ParentCategory.fromMap(maps.first);
    }
    
    // Create new category if not exists
    final newCategory = ParentCategory(
      name: categoryName,
      createdAt: DateTime.now(),
    );
    
    final categoryId = await insertParentCategory(newCategory);
    return newCategory.copyWith(id: categoryId);
  }

  // Copy an existing preset with all its items
  Future<int> copyInspectionPreset(int presetId) async {
    try {
      // Get the original preset
      final db = await database;
      final List<Map<String, dynamic>> presetMaps = await db.query(
        'inspection_presets',
        where: 'id = ?',
        whereArgs: [presetId],
      );
      
      if (presetMaps.isEmpty) {
        throw Exception('Preset not found');
      }
      
      final originalPreset = InspectionPreset.fromMap(presetMaps.first);
      
      // Create new preset with " - Copy" suffix
      final newPreset = InspectionPreset(
        name: '${originalPreset.name} - Copy',
        description: originalPreset.description,
        companyId: originalPreset.companyId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      final newPresetId = await insertInspectionPreset(newPreset);
      
      // Get all items from original preset
      final originalItems = await getInspectionPresetItems(presetId);
      
      // Copy all items to new preset
      for (var item in originalItems) {
        final newItem = InspectionPresetItem(
          presetId: newPresetId,
          title: item.title,
          description: item.description,
          sortOrder: item.sortOrder,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          parentId: item.parentId,
          parentName: item.parentName,
        );
        
        await insertInspectionPresetItem(newItem);
      }
      
      return newPresetId;
    } catch (e) {
      throw Exception('Failed to copy preset: $e');
    }
  }
}
