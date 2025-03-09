Codex知识库模块详细设计
1. 模块概述
Codex知识库模块是小说创作的核心辅助系统，用于管理小说中的人物、地点、物品、背景故事等元素。它不仅提供结构化存储这些信息的能力，还与AI集成，可以自动生成、扩展和关联这些元素，帮助作者保持小说世界的一致性和丰富性。

## Codex知识库模块详细设计（续）

### 2. 数据模型（续）

```dart
// 知识库基类
abstract class CodexEntry {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String novelId;
  final List<String> tags;
  final List<Relationship> relationships;
  final Map<String, dynamic> attributes;
  
  const CodexEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.novelId,
    this.tags = const [],
    this.relationships = const [],
    this.attributes = const {},
  });
}

// 角色条目
class Character extends CodexEntry {
  final String? profileImageUrl;
  final String? age;
  final String? gender;
  final String? occupation;
  final String? background;
  final String? personality;
  final String? goals;
  final String? conflicts;
  
  Character({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required super.updatedAt,
    required super.novelId,
    super.tags,
    super.relationships,
    super.attributes,
    this.profileImageUrl,
    this.age,
    this.gender,
    this.occupation,
    this.background,
    this.personality,
    this.goals,
    this.conflicts,
  });
  
  factory Character.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 地点条目
class Location extends CodexEntry {
  final String? mapImageUrl;
  final String? type;
  final String? climate;
  final String? culture;
  final String? significance;
  final String? history;
  
  Location({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required super.updatedAt,
    required super.novelId,
    super.tags,
    super.relationships,
    super.attributes,
    this.mapImageUrl,
    this.type,
    this.climate,
    this.culture,
    this.significance,
    this.history,
  });
  
  factory Location.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 物品条目
class Item extends CodexEntry {
  final String? imageUrl;
  final String? type;
  final String? origin;
  final String? properties;
  final String? significance;
  final String? currentLocation;
  
  Item({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required super.updatedAt,
    required super.novelId,
    super.tags,
    super.relationships,
    super.attributes,
    this.imageUrl,
    this.type,
    this.origin,
    this.properties,
    this.significance,
    this.currentLocation,
  });
  
  factory Item.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 背景故事/设定条目
class Lore extends CodexEntry {
  final String? category;
  final String? historicalPeriod;
  final String? culturalContext;
  
  Lore({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required super.updatedAt,
    required super.novelId,
    super.tags,
    super.relationships,
    super.attributes,
    this.category,
    this.historicalPeriod,
    this.culturalContext,
  });
  
  factory Lore.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 情节线索
class Subplot extends CodexEntry {
  final String? plotType;
  final String? resolution;
  final String? relatedCharacters;
  final String? climax;
  
  Subplot({
    required super.id,
    required super.title,
    required super.description,
    required super.createdAt,
    required super.updatedAt,
    required super.novelId,
    super.tags,
    super.relationships,
    super.attributes,
    this.plotType,
    this.resolution,
    this.relatedCharacters,
    this.climax,
  });
  
  factory Subplot.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 关系模型
class Relationship {
  final String sourceId;
  final String targetId;
  final RelationshipType type;
  final String? description;
  
  Relationship({
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.description,
  });
  
  factory Relationship.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

// 关系类型
enum RelationshipType {
  familial,      // 家庭关系
  romantic,      // 恋爱关系
  professional,  // 职业关系
  antagonistic,  // 敌对关系
  friendly,      // 友好关系
  ownership,     // 所有关系
  location,      // 位置关系
  historical,    // 历史关系
  custom,        // 自定义关系
}
```

### 3. 状态管理

```dart
// Codex状态管理
class CodexBloc extends Bloc<CodexEvent, CodexState> {
  final CodexRepository repository;
  
  CodexBloc({required this.repository}) : super(CodexInitial()) {
    on<LoadCodexEntries>(_onLoadEntries);
    on<CreateCodexEntry>(_onCreateEntry);
    on<UpdateCodexEntry>(_onUpdateEntry);
    on<DeleteCodexEntry>(_onDeleteEntry);
    on<SearchCodexEntries>(_onSearchEntries);
    on<FilterCodexEntries>(_onFilterEntries);
    on<GenerateEntryWithAI>(_onGenerateWithAI);
    on<LinkCodexEntries>(_onLinkEntries);
    on<ImportCodexEntries>(_onImportEntries);
    on<ExportCodexEntries>(_onExportEntries);
  }
  
  Future<void> _onLoadEntries(LoadCodexEntries event, Emitter<CodexState> emit) async {
    emit(CodexLoading());
    
    try {
      final entries = await repository.getCodexEntries(
        novelId: event.novelId,
        entryType: event.entryType,
      );
      
      emit(CodexLoaded(entries: entries));
    } catch (e) {
      emit(CodexError(message: '加载知识库条目失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onCreateEntry(CreateCodexEntry event, Emitter<CodexState> emit) async {
    try {
      final newEntry = await repository.createCodexEntry(
        novelId: event.novelId,
        entryType: event.entryType,
        title: event.title,
        description: event.description,
        attributes: event.attributes,
      );
      
      if (state is CodexLoaded) {
        final currentState = state as CodexLoaded;
        emit(CodexLoaded(entries: [...currentState.entries, newEntry]));
      }
      
      emit(EntryCreated(entry: newEntry));
    } catch (e) {
      emit(CodexError(message: '创建知识库条目失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onGenerateWithAI(GenerateEntryWithAI event, Emitter<CodexState> emit) async {
    emit(GeneratingEntry());
    
    try {
      final generatedEntry = await repository.generateEntryWithAI(
        novelId: event.novelId,
        entryType: event.entryType,
        prompt: event.prompt,
        existingEntries: event.existingEntries,
      );
      
      emit(EntryGenerated(entry: generatedEntry));
      
      if (state is CodexLoaded) {
        final currentState = state as CodexLoaded;
        emit(CodexLoaded(entries: [...currentState.entries, generatedEntry]));
      }
    } catch (e) {
      emit(CodexError(message: 'AI生成知识库条目失败: ${e.toString()}'));
    }
  }
  
  // 其他事件处理方法...
}

// 事件定义
abstract class CodexEvent {}

class LoadCodexEntries extends CodexEvent {
  final String novelId;
  final String? entryType;
  
  LoadCodexEntries({required this.novelId, this.entryType});
}

class CreateCodexEntry extends CodexEvent {
  final String novelId;
  final String entryType;
  final String title;
  final String description;
  final Map<String, dynamic>? attributes;
  
  CreateCodexEntry({
    required this.novelId,
    required this.entryType,
    required this.title,
    required this.description,
    this.attributes,
  });
}

// 其他事件类...

// 状态定义
abstract class CodexState {}

class CodexInitial extends CodexState {}
class CodexLoading extends CodexState {}
class CodexLoaded extends CodexState {
  final List<CodexEntry> entries;
  
  CodexLoaded({required this.entries});
}
class CodexError extends CodexState {
  final String message;
  
  CodexError({required this.message});
}
class GeneratingEntry extends CodexState {}
class EntryGenerated extends CodexState {
  final CodexEntry entry;
  
  EntryGenerated({required this.entry});
}
class EntryCreated extends CodexState {
  final CodexEntry entry;
  
  EntryCreated({required this.entry});
}
// 其他状态类...
```

### 4. UI组件结构

```
CodexScreen
├── CodexHeader
│   ├── BackButton
│   ├── ScreenTitle
│   ├── FilterDropdown
│   └── SearchField
├── EntryTypeSelector
│   ├── CharactersTab
│   ├── LocationsTab
│   ├── ItemsTab
│   ├── LoreTab
│   └── SubplotsTab
├── EntryListContainer
│   ├── EntryList
│   │   ├── EntryCard
│   │   │   ├── EntryIcon
│   │   │   ├── EntryTitle
│   │   │   ├── EntryDescription (truncated)
│   │   │   └── EntryActions
│   │   │       ├── EditButton
│   │   │       ├── DeleteButton
│   │   │       └── LinkButton
│   │   └── EmptyState (when no entries)
│   └── LoadMoreButton
├── CreateEntryFAB
└── EntryDetailsPanel (shown when entry selected)
    ├── EntryHeader
    │   ├── EntryImage
    │   ├── EntryTitle
    │   ├── EntryType
    │   └── EditButton
    ├── EntryContent
    │   ├── MainDescription
    │   ├── AttributesSection
    │   │   └── AttributeItem
    │   ├── RelationshipsSection
    │   │   └── RelationshipItem
    │   └── RelatedEntriesSection
    │       └── RelatedEntryCard
    └── AIActionsPanel
        ├── ExpandDescriptionButton
        ├── GenerateAttributesButton
        ├── SuggestRelationshipsButton
        └── CreateRelatedEntryButton
```

### 5. 核心功能实现

#### 5.1 创建新条目表单

```dart
class CodexEntryForm extends StatefulWidget {
  final String novelId;
  final String entryType;
  final CodexEntry? initialEntry;
  final Function(CodexEntry) onSubmit;
  
  const CodexEntryForm({
    Key? key,
    required this.novelId,
    required this.entryType,
    this.initialEntry,
    required this.onSubmit,
  }) : super(key: key);
  
  @override
  State<CodexEntryForm> createState() => _CodexEntryFormState();
}

class _CodexEntryFormState extends State<CodexEntryForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final Map<String, TextEditingController> _attributeControllers = {};
  bool _isGenerating = false;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化控制器
    _titleController = TextEditingController(text: widget.initialEntry?.title ?? '');
    _descriptionController = TextEditingController(text: widget.initialEntry?.description ?? '');
    
    // 根据条目类型设置特定属性的控制器
    _setupAttributeControllers();
  }
  
  void _setupAttributeControllers() {
    // 清除现有控制器
    for (var controller in _attributeControllers.values) {
      controller.dispose();
    }
    _attributeControllers.clear();
    
    // 根据条目类型设置控制器
    switch (widget.entryType) {
      case 'character':
        _attributeControllers['age'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.age ?? ''
        );
        _attributeControllers['gender'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.gender ?? ''
        );
        _attributeControllers['occupation'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.occupation ?? ''
        );
        _attributeControllers['personality'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.personality ?? ''
        );
        _attributeControllers['background'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.background ?? ''
        );
        _attributeControllers['goals'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.goals ?? ''
        );
        _attributeControllers['conflicts'] = TextEditingController(
          text: (widget.initialEntry as Character?)?.conflicts ?? ''
        );
        break;
      
      case 'location':
        _attributeControllers['type'] = TextEditingController(
          text: (widget.initialEntry as Location?)?.type ?? ''
        );
        _attributeControllers['climate'] = TextEditingController(
          text: (widget.initialEntry as Location?)?.climate ?? ''
        );
        _attributeControllers['culture'] = TextEditingController(
          text: (widget.initialEntry as Location?)?.culture ?? ''
        );
        _attributeControllers['history'] = TextEditingController(
          text: (widget.initialEntry as Location?)?.history ?? ''
        );
        _attributeControllers['significance'] = TextEditingController(
          text: (widget.initialEntry as Location?)?.significance ?? ''
        );
        break;
      
      // 其他条目类型...
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题字段
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '标题',
              hintText: '输入${_getEntryTypeName()}名称',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入标题';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // 描述字段
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: '描述',
              hintText: '输入详细描述',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入描述';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // 条目特定属性字段
          ..._buildAttributeFields(),
          
          SizedBox(height: 24),
          
          // 表单按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('保存'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateWithAI,
                  icon: _isGenerating 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.auto_awesome),
                  label: Text('使用AI生成'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 构建特定属性字段
  List<Widget> _buildAttributeFields() {
    final List<Widget> fields = [];
    
    _attributeControllers.forEach((key, controller) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: _getAttributeLabel(key),
              border: OutlineInputBorder(),
            ),
            maxLines: key.contains('description') || 
                     key == 'background' || 
                     key == 'personality' || 
                     key == 'history' ? 3 : 1,
          ),
        ),
      );
    });
    
    return fields;
  }
  
  // 获取属性显示名称
  String _getAttributeLabel(String key) {
    final Map<String, String> labels = {
      'age': '年龄',
      'gender': '性别',
      'occupation': '职业',
      'personality': '性格特征',
      'background': '背景故事',
      'goals': '目标',
      'conflicts': '冲突',
      'type': '类型',
      'climate': '气候',
      'culture': '文化',
      'history': '历史',
      'significance': '重要性',
      // 其他属性标签...
    };
    
    return labels[key] ?? key.substring(0, 1).toUpperCase() + key.substring(1);
  }
  
  // 获取条目类型显示名称
  String _getEntryTypeName() {
    switch (widget.entryType) {
      case 'character':
        return '角色';
      case 'location':
        return '地点';
      case 'item':
        return '物品';
      case 'lore':
        return '背景设定';
      case 'subplot':
        return '情节线索';
      default:
        return '条目';
    }
  }
  
  // 提交表单
  void _submitForm() {
    // 收集属性值
    final Map<String, dynamic> attributes = {};
    _attributeControllers.forEach((key, controller) {
      attributes[key] = controller.text;
    });
    
    // 创建相应类型的条目
    CodexEntry entry;
    switch (widget.entryType) {
      case 'character':
        entry = Character(
          id: widget.initialEntry?.id ?? UUID.v4(),
          title: _titleController.text,
          description: _descriptionController.text,
          createdAt: widget.initialEntry?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          novelId: widget.novelId,
          age: attributes['age'],
          gender: attributes['gender'],
          occupation: attributes['occupation'],
          personality: attributes['personality'],
          background: attributes['background'],
          goals: attributes['goals'],
          conflicts: attributes['conflicts'],
        );
        break;
      
      case 'location':
        entry = Location(
          id: widget.initialEntry?.id ?? UUID.v4(),
          title: _titleController.text,
          description: _descriptionController.text,
          createdAt: widget.initialEntry?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          novelId: widget.novelId,
          type: attributes['type'],
          climate: attributes['climate'],
          culture: attributes['culture'],
          history: attributes['history'],
          significance: attributes['significance'],
        );
        break;
      
      // 其他条目类型...
      
      default:
        throw Exception('不支持的条目类型: ${widget.entryType}');
    }
    
    // 调用回调
    widget.onSubmit(entry);
  }
  
  // 使用AI生成内容
  Future<void> _generateWithAI() async {
    // 设置生成状态
    setState(() {
      _isGenerating = true;
    });
    
    try {
      // 获取当前填写的信息作为提示
      final prompt = StringBuffer();
      prompt.write('创建一个${_getEntryTypeName()}：');
      
      if (_titleController.text.isNotEmpty) {
        prompt.write('名称：${_titleController.text}。');
      }
      
      if (_descriptionController.text.isNotEmpty) {
        prompt.write('描述：${_descriptionController.text}。');
      }
      
      // 添加已填写的属性
      _attributeControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          prompt.write('${_getAttributeLabel(key)}：${controller.text}。');
        }
      });
      
      // 获取小说的其他条目作为上下文
      final codexBloc = context.read<CodexBloc>();
      List<CodexEntry> existingEntries = [];
      if (codexBloc.state is CodexLoaded) {
        existingEntries = (codexBloc.state as CodexLoaded).entries;
      }
      
      // 调用生成事件
      codexBloc.add(GenerateEntryWithAI(
        novelId: widget.novelId,
        entryType: widget.entryType,
        prompt: prompt.toString(),
        existingEntries: existingEntries,
      ));
      
      // 监听生成结果
      await for (final state in codexBloc.stream) {
        if (state is EntryGenerated) {
          // 更新表单字段
          _updateFormWithGeneratedEntry(state.entry);
          break;
        } else if (state is CodexError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          break;
        }
      }
    } finally {
      // 恢复状态
      setState(() {
        _isGenerating = false;
      });
    }
  }
  
  // 使用生成的条目更新表单
  void _updateFormWithGeneratedEntry(CodexEntry entry) {
    _titleController.text = entry.title;
    _descriptionController.text = entry.description;
    
    // 更新特定属性
    if (entry is Character) {
      _attributeControllers['age']?.text = entry.age ?? '';
      _attributeControllers['gender']?.text = entry.gender ?? '';
      _attributeControllers['occupation']?.text = entry.occupation ?? '';
      _attributeControllers['personality']?.text = entry.personality ?? '';
      _attributeControllers['background']?.text = entry.background ?? '';
      _attributeControllers['goals']?.text = entry.goals ?? '';
      _attributeControllers['conflicts']?.text = entry.conflicts ?? '';
    } else if (entry is Location) {
      _attributeControllers['type']?.text = entry.type ?? '';
      _attributeControllers['climate']?.text = entry.climate ?? '';
      _attributeControllers['culture']?.text = entry.culture ?? '';
      _attributeControllers['history']?.text = entry.history ?? '';
      _attributeControllers['significance']?.text = entry.significance ?? '';
    }
    // 其他条目类型...
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    
    for (var controller in _attributeControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }
}
```

#### 5.2 关系管理器

```dart
class RelationshipManager extends StatefulWidget {
  final String novelId;
  final CodexEntry entry;
  final List<CodexEntry> allEntries;
  final Function(List<Relationship>) onRelationshipsChanged;
  
  const RelationshipManager({
    Key? key,
    required this.novelId,
    required this.entry,
    required this.allEntries,
    required this.onRelationshipsChanged,
  }) : super(key: key);
  
  @override
  State<RelationshipManager> createState() => _RelationshipManagerState();
}

class _RelationshipManagerState extends State<RelationshipManager> {
  List<Relationship> _relationships = [];
  
  @override
  void initState() {
    super.initState();
    _relationships = List.from(widget.entry.relationships);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关系',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        
        // 现有关系列表
        ..._relationships.map(_buildRelationshipItem).toList(),
        
        SizedBox(height: 12),
        
        // 添加关系按钮
        OutlinedButton.icon(
          onPressed: _showAddRelationshipDialog,
          icon: Icon(Icons.add),
          label: Text('添加关系'),
        ),
        
        SizedBox(height: 12),
        
        // AI建议关系按钮
        OutlinedButton.icon(
          onPressed: _suggestRelationshipsWithAI,
          icon: Icon(Icons.auto_awesome),
          label: Text('AI建议关系'),
        ),
      ],
    );
  }
  
  // 构建关系项目
  Widget _buildRelationshipItem(Relationship relationship) {
    // 查找关联的条目
    final targetEntry = widget.allEntries.firstWhere(
      (e) => e.id == relationship.targetId,
      orElse: () => null as CodexEntry, // 注意：这种情况不应该发生
    );
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // 条目图标
            Icon(_getEntryTypeIcon(targetEntry)),
            SizedBox(width: 12),
            
            // 关系详情
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetEntry.title,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_getRelationshipTypeLabel(relationship.type)}${relationship.description != null ? ': ${relationship.description}' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // 编辑按钮
            IconButton(
              icon: Icon(Icons.edit, size: 18),
              onPressed: () => _showEditRelationshipDialog(relationship),
            ),
            
            // 删除按钮
            IconButton(
              icon: Icon(Icons.delete, size: 18),
              onPressed: () => _deleteRelationship(relationship),
            ),
          ],
        ),
      ),
    );
  }
  
  // 获取条目类型图标
  IconData _getEntryTypeIcon(CodexEntry entry) {
    if (entry is Character) {
      return Icons.person;
    } else if (entry is Location) {
      return Icons.place;
    } else if (entry is Item) {
      return Icons.inventory_2;
    } else if (entry is Lore) {
      return Icons.auto_stories;
    } else if (entry is Subplot) {
      return Icons.timeline;
    } else {
      return Icons.article;
    }
  }
  
  // 获取关系类型标签
  String _getRelationshipTypeLabel(RelationshipType type) {
    switch (type) {
      case RelationshipType.familial:
        return '家庭关系';
      case RelationshipType.romantic:
        return '恋爱关系';
      case RelationshipType.professional:
        return '职业关系';
      case RelationshipType.antagonistic:
        return '敌对关系';
      case RelationshipType.friendly:
        return '友好关系';
      case RelationshipType.ownership:
        return '所有关系';
      case RelationshipType.location:
        return '位置关系';
      case RelationshipType.historical:
        return '历史关系';
      case RelationshipType.custom:
        return '自定义关系';
    }
  }
  
  // 显示添加关系对话框
  void _showAddRelationshipDialog() {
    // 过滤掉当前条目和已有关系的条目
    final availableEntries = widget.allEntries.where((e) {
      return e.id != widget.entry.id && 
             !_relationships.any((r) => r.targetId == e.id);
    }).toList();
    
    if (availableEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没有可添加关系的条目')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => RelationshipDialog(
        allEntries: availableEntries,
        onSave: (targetId, type, description) {
          setState(() {
            _relationships.add(Relationship(
              sourceId: widget.entry.id,
              targetId: targetId,
              type: type,
              description: description,
            ));
          });
          
          widget.onRelationshipsChanged(_relationships);
        },
      ),
    );
  }
  
  // 显示编辑关系对话框
  void _showEditRelationshipDialog(Relationship relationship) {
    final targetEntry = widget.allEntries.firstWhere(
      (e) => e.id == relationship.targetId,
    );
    
    showDialog(
      context: context,
      builder: (context) => RelationshipDialog(
        allEntries: [targetEntry],
        initialTargetId: relationship.targetId,
        initialType: relationship.type,
        initialDescription: relationship.description,
        onSave: (targetId, type, description) {
          setState(() {
            final index = _relationships.indexWhere(
              (r) => r.targetId == relationship.targetId
            );
            
            if (index >= 0) {
              _relationships[index] = Relationship(
                sourceId: widget.entry.id,
                targetId: targetId,
                type: type,
                description: description,
              );
            }
          });
          
          widget.onRelationshipsChanged(_relationships);
        },
      ),
    );
  }
  
  // 删除关系
  void _deleteRelationship(Relationship relationship) {
    setState(() {
      _relationships.removeWhere(
        (r) => r.targetId == relationship.targetId
      );
    });
    
    widget.onRelationshipsChanged(_relationships);
  }
  
  // 使用AI建议关系
  Future<void> _suggestRelationshipsWithAI() async {
    // 实现AI关系建议功能
    // ...
  }
}

// 关系对话框组件
class RelationshipDialog extends StatefulWidget {
  final List<CodexEntry> allEntries;
  final String? initialTargetId;
  final RelationshipType? initialType;
  final String? initialDescription;
  final Function(String, RelationshipType, String?) onSave;
  
  const RelationshipDialog({
    Key? key,
    required this.allEntries,
    this.initialTargetId,
    this.initialType,
    this.initialDescription,
    required this.onSave,
  }) : super(key: key);
  
  @override
  State<RelationshipDialog> createState() => _RelationshipDialogState();
}

class _RelationshipDialogState extends State<RelationshipDialog> {
  late String _selectedTargetId;
  late RelationshipType _selectedType;
  late TextEditingController _descriptionController;
  
  @override
  void initState() {
    super.initState();
    _selectedTargetId = widget.initialTargetId ?? widget.allEntries.first.id;
    _selectedType = widget.initialType ?? RelationshipType.custom;
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? ''
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTargetId != null ? '编辑关系' : '添加关系'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 目标条目选择
            DropdownButtonFormField<String>(
              value: _selectedTargetId,
              decoration: InputDecoration(
                labelText: '关联条目',
                border: OutlineInputBorder(),
              ),
              items: widget.allEntries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.id,
                  child: Text(entry.title),
                );
              }).toList(),
              onChanged: widget.initialTargetId != null 
                  ? null  // 如果是编辑模式，不允许更改目标
                  : (value) {
                      setState(() {
                        _selectedTargetId = value!;
                      });
                    },
            ),
            SizedBox(height: 16),
            
            // 关系类型选择
            DropdownButtonFormField<RelationshipType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: '关系类型',
                border: OutlineInputBorder(),
              ),
              items: RelationshipType.values.map((type) {
                return DropdownMenuItem<RelationshipType>(
                  value: type,
                  child: Text(_getRelationshipTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            SizedBox(height: 16),
            
            // 关系描述
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
                hintText: '例如：父子关系、上司与下属、仇恨的起源...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              _selectedTargetId,
              _selectedType,
              _descriptionController.text.isEmpty 
                  ? null 
                  : _descriptionController.text,
            );
            Navigator.pop(context);
          },
          child: Text('保存'),
        ),
      ],
    );
  }
  
  String _getRelationshipTypeLabel(RelationshipType type) {
    switch (type) {
      case RelationshipType.familial:
        return '家庭关系';
      case RelationshipType.romantic:
        return '恋爱关系';
      case RelationshipType.professional:
        return '职业关系';
      case RelationshipType.antagonistic:
        return '敌对关系';
      case RelationshipType.friendly:
        return '友好关系';
      case RelationshipType.ownership:
        return '所有关系';
      case RelationshipType.location:
        return '位置关系';
      case RelationshipType.historical:
        return '历史关系';
      case RelationshipType.custom:
        return '自定义关系';
    }
```

<think>我需要继续完成Codex知识库模块详细设计文档的剩余部分，然后开始小说计划预览模块的详细设计。我会继续提供代码示例、数据结构和UI组件设计。</think># 模块详细设计文档（第二批 - 续2）

## Codex知识库模块详细设计（续）

### 5.3 知识库条目详情视图

```dart
class CodexEntryDetailView extends StatelessWidget {
  final CodexEntry entry;
  final List<CodexEntry> allEntries;
  final Function(CodexEntry) onEdit;
  final Function(String) onDelete;
  
  const CodexEntryDetailView({
    Key? key,
    required this.entry,
    required this.allEntries,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部区域
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图像
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildEntryImage(),
              ),
              SizedBox(width: 16),
              
              // 右侧标题和基本信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getEntryTypeName(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '创建于：${DateFormat('yyyy年MM月dd日').format(entry.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '最后更新：${DateFormat('yyyy年MM月dd日 HH:mm').format(entry.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEdit(entry),
                  icon: Icon(Icons.edit),
                  label: Text('编辑'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: Icon(Icons.delete),
                  label: Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          
          Divider(height: 32),
          
          // 描述部分
          Text(
            '描述',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Text(entry.description),
          
          SizedBox(height: 24),
          
          // 属性部分
          Text(
            '属性',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ..._buildAttributeWidgets(context),
          
          SizedBox(height: 24),
          
          // 关系部分
          if (entry.relationships.isNotEmpty) ...[
            Text(
              '关系',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            ..._buildRelationshipsWidgets(context),
            SizedBox(height: 24),
          ],
          
          // AI增强操作区域
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI辅助操作',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.auto_awesome, size: 18),
                        label: Text('扩展描述'),
                        onPressed: () => _expandDescription(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.psychology, size: 18),
                        label: Text('生成新特性'),
                        onPressed: () => _generateNewAttributes(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.people, size: 18),
                        label: Text('建议关系'),
                        onPressed: () => _suggestRelationships(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.add_circle, size: 18),
                        label: Text('创建相关条目'),
                        onPressed: () => _createRelatedEntry(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建条目图像
  Widget _buildEntryImage() {
    if (entry is Character && (entry as Character).profileImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Character).profileImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else if (entry is Location && (entry as Location).mapImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Location).mapImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else if (entry is Item && (entry as Item).imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Item).imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else {
      return _buildEntryIcon();
    }
  }
  
  // 构建条目图标
  Widget _buildEntryIcon() {
    IconData iconData;
    Color iconColor;
    
    if (entry is Character) {
      iconData = Icons.person;
      iconColor = Colors.blue;
    } else if (entry is Location) {
      iconData = Icons.place;
      iconColor = Colors.green;
    } else if (entry is Item) {
      iconData = Icons.inventory_2;
      iconColor = Colors.amber;
    } else if (entry is Lore) {
      iconData = Icons.auto_stories;
      iconColor = Colors.purple;
    } else if (entry is Subplot) {
      iconData = Icons.timeline;
      iconColor = Colors.red;
    } else {
      iconData = Icons.article;
      iconColor = Colors.grey;
    }
    
    return Center(
      child: Icon(
        iconData,
        size: 48,
        color: iconColor,
      ),
    );
  }
  
  // 获取条目类型名称
  String _getEntryTypeName() {
    if (entry is Character) {
      return '角色';
    } else if (entry is Location) {
      return '地点';
    } else if (entry is Item) {
      return '物品';
    } else if (entry is Lore) {
      return '背景设定';
    } else if (entry is Subplot) {
      return '情节线索';
    } else {
      return '条目';
    }
  }
  
  // 构建属性小部件
  List<Widget> _buildAttributeWidgets(BuildContext context) {
    final List<Widget> widgets = [];
    
    if (entry is Character) {
      final character = entry as Character;
      _addAttributeIfNotEmpty(widgets, '年龄', character.age);
      _addAttributeIfNotEmpty(widgets, '性别', character.gender);
      _addAttributeIfNotEmpty(widgets, '职业', character.occupation);
      _addAttributeIfNotEmpty(widgets, '性格特征', character.personality);
      _addAttributeIfNotEmpty(widgets, '背景故事', character.background);
      _addAttributeIfNotEmpty(widgets, '目标', character.goals);
      _addAttributeIfNotEmpty(widgets, '冲突', character.conflicts);
    } else if (entry is Location) {
      final location = entry as Location;
      _addAttributeIfNotEmpty(widgets, '类型', location.type);
      _addAttributeIfNotEmpty(widgets, '气候', location.climate);
      _addAttributeIfNotEmpty(widgets, '文化', location.culture);
      _addAttributeIfNotEmpty(widgets, '历史', location.history);
      _addAttributeIfNotEmpty(widgets, '重要性', location.significance);
    } else if (entry is Item) {
      final item = entry as Item;
      _addAttributeIfNotEmpty(widgets, '类型', item.type);
      _addAttributeIfNotEmpty(widgets, '来源', item.origin);
      _addAttributeIfNotEmpty(widgets, '属性', item.properties);
      _addAttributeIfNotEmpty(widgets, '重要性', item.significance);
      _addAttributeIfNotEmpty(widgets, '当前位置', item.currentLocation);
    } else if (entry is Lore) {
      final lore = entry as Lore;
      _addAttributeIfNotEmpty(widgets, '分类', lore.category);
      _addAttributeIfNotEmpty(widgets, '历史时期', lore.historicalPeriod);
      _addAttributeIfNotEmpty(widgets, '文化背景', lore.culturalContext);
    } else if (entry is Subplot) {
      final subplot = entry as Subplot;
      _addAttributeIfNotEmpty(widgets, '情节类型', subplot.plotType);
      _addAttributeIfNotEmpty(widgets, '解决方案', subplot.resolution);
      _addAttributeIfNotEmpty(widgets, '相关角色', subplot.relatedCharacters);
      _addAttributeIfNotEmpty(widgets, '高潮', subplot.climax);
    }
    
    // 如果没有任何属性
    if (widgets.isEmpty) {
      widgets.add(
        Text('没有属性', style: TextStyle(fontStyle: FontStyle.italic))
      );
    }
    
    return widgets;
  }
  
  // 添加非空属性
  void _addAttributeIfNotEmpty(List<Widget> widgets, String label, String? value) {
    if (value != null && value.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      );
    }
  }
  
  // 构建关系小部件
  List<Widget> _buildRelationshipsWidgets(BuildContext context) {
    return entry.relationships.map((relationship) {
      // 查找目标条目
      final targetEntry = allEntries.firstWhere(
        (e) => e.id == relationship.targetId,
        orElse: () => null as CodexEntry,  // 这种情况不应该发生
      );
      
      if (targetEntry == null) {
        return SizedBox.shrink();  // 如果找不到目标条目，不显示
      }
      
      return Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(_getEntryTypeIcon(targetEntry)),
          title: Text(targetEntry.title),
          subtitle: Text(
            '${_getRelationshipTypeLabel(relationship.type)}${relationship.description != null ? ': ${relationship.description}' : ''}',
          ),
          onTap: () {
            // 跳转到关联条目详情
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CodexEntryDetailScreen(
                  entry: targetEntry,
                  allEntries: allEntries,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
  
  // 获取条目类型图标
  IconData _getEntryTypeIcon(CodexEntry entry) {
    if (entry is Character) {
      return Icons.person;
    } else if (entry is Location) {
      return Icons.place;
    } else if (entry is Item) {
      return Icons.inventory_2;
    } else if (entry is Lore) {
      return Icons.auto_stories;
    } else if (entry is Subplot) {
      return Icons.timeline;
    } else {
      return Icons.article;
    }
  }
  
  // 获取关系类型标签
  String _getRelationshipTypeLabel(RelationshipType type) {
    switch (type) {
      case RelationshipType.familial:
        return '家庭关系';
      case RelationshipType.romantic:
        return '恋爱关系';
      case RelationshipType.professional:
        return '职业关系';
      case RelationshipType.antagonistic:
        return '敌对关系';
      case RelationshipType.friendly:
        return '友好关系';
      case RelationshipType.ownership:
        return '所有关系';
      case RelationshipType.location:
        return '位置关系';
      case RelationshipType.historical:
        return '历史关系';
      case RelationshipType.custom:
        return '自定义关系';
    }
  }
  
  // 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除"${entry.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete(entry.id);
            },
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
  
  // AI辅助操作：扩展描述
  void _expandDescription(BuildContext context) {
    // 实现AI扩展描述功能
  }
  
  // AI辅助操作：生成新特性
  void _generateNewAttributes(BuildContext context) {
    // 实现AI生成新特性功能
  }
  
  // AI辅助操作：建议关系
  void _suggestRelationships(BuildContext context) {
    // 实现AI建议关系功能
  }
  
  // AI辅助操作：创建相关条目
  void _createRelatedEntry(BuildContext context) {
    // 实现AI创建相关条目功能
  }
}
```

### 6. API交互

```dart
class CodexRepository {
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  CodexRepository({
    required this.apiService,
    required this.localStorageService,
  });
  
  // 获取所有知识库条目
  Future<List<CodexEntry>> getCodexEntries({
    required String novelId,
    String? entryType,
  }) async {
    try {
      // 尝试从服务器获取
      final entries = await apiService.fetchCodexEntries(
        novelId: novelId,
        entryType: entryType,
      );
      
      // 保存到本地缓存
      await localStorageService.saveCodexEntries(novelId, entries);
      
      return entries;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localEntries = await localStorageService.getCodexEntries(
        novelId: novelId,
        entryType: entryType,
      );
      
      if (localEntries.isNotEmpty) {
        return localEntries;
      }
      
      throw Exception('无法加载知识库条目: $e');
    }
  }
  
  // 获取特定条目
  Future<CodexEntry> getCodexEntry({
    required String novelId,
    required String entryId,
  }) async {
    try {
      // 尝试从服务器获取
      final entry = await apiService.fetchCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      // 更新本地缓存
      await localStorageService.saveCodexEntry(novelId, entry);
      
      return entry;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localEntry = await localStorageService.getCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      if (localEntry != null) {
        return localEntry;
      }
      
      throw Exception('无法加载知识库条目: $e');
    }
  }
  
  // 创建知识库条目
  Future<CodexEntry> createCodexEntry({
    required String novelId,
    required String entryType,
    required String title,
    required String description,
    Map<String, dynamic>? attributes,
  }) async {
    try {
      // 创建条目
      final newEntry = await apiService.createCodexEntry(
        novelId: novelId,
        entryType: entryType,
        title: title,
        description: description,
        attributes: attributes,
      );
      
      // 保存到本地
      await localStorageService.saveCodexEntry(novelId, newEntry);
      
      return newEntry;
    } catch (e) {
      // 如果服务器请求失败，创建本地临时条目
      final now = DateTime.now();
      
      CodexEntry tempEntry;
      final id = UUID.v4();
      
      switch (entryType) {
        case 'character':
          tempEntry = Character(
            id: id,
            title: title,
            description: description,
            createdAt: now,
            updatedAt: now,
            novelId: novelId,
            age: attributes?['age'],
            gender: attributes?['gender'],
            occupation: attributes?['occupation'],
            personality: attributes?['personality'],
            background: attributes?['background'],
            goals: attributes?['goals'],
            conflicts: attributes?['conflicts'],
          );
          break;
          
        case 'location':
          tempEntry = Location(
            id: id,
            title: title,
            description: description,
            createdAt: now,
            updatedAt: now,
            novelId: novelId,
            type: attributes?['type'],
            climate: attributes?['climate'],
            culture: attributes?['culture'],
            history: attributes?['history'],
            significance: attributes?['significance'],
          );
          break;
          
        // 其他类型的条目...
        
        default:
          throw Exception('不支持的条目类型: $entryType');
      }
      
      // 标记为需要同步
      await localStorageService.saveCodexEntry(
        novelId, 
        tempEntry,
        needsSync: true,
      );
      
      return tempEntry;
    }
  }
  
  // 更新知识库条目
  Future<CodexEntry> updateCodexEntry({
    required String novelId,
    required CodexEntry entry,
  }) async {
    try {
      // 更新服务器
      final updatedEntry = await apiService.updateCodexEntry(
        novelId: novelId,
        entry: entry,
      );
      
      // 更新本地缓存
      await localStorageService.saveCodexEntry(novelId, updatedEntry);
      
      return updatedEntry;
    } catch (e) {
      // 如果服务器请求失败，仅更新本地并标记为需要同步
      await localStorageService.saveCodexEntry(
        novelId, 
        entry.copyWith(updatedAt: DateTime.now()),
        needsSync: true,
      );
      
      return entry.copyWith(updatedAt: DateTime.now());
    }
  }
  
  // 删除知识库条目
  Future<void> deleteCodexEntry({
    required String novelId,
    required String entryId,
  }) async {
    try {
      // 从服务器删除
      await apiService.deleteCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      // 从本地缓存删除
      await localStorageService.deleteCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
    } catch (e) {
      // 如果服务器请求失败，标记为待删除
      await localStorageService.markCodexEntryForDeletion(
        novelId: novelId,
        entryId: entryId,
      );
    }
  }
  
  // 使用AI生成条目
  Future<CodexEntry> generateEntryWithAI({
    required String novelId,
    required String entryType,
    required String prompt,
    List<CodexEntry>? existingEntries,
  }) async {
    // 从服务器生成
    final generatedEntry = await apiService.generateCodexEntryWithAI(
      novelId: novelId,
      entryType: entryType,
      prompt: prompt,
      existingEntriesContext: existingEntries,
    );
    
    // 保存到本地
    await localStorageService.saveCodexEntry(novelId, generatedEntry);
    
    return generatedEntry;
  }
  
  // 语义搜索
  Future<List<SearchResult>> semanticSearch(
    String novelId,
    String query,
  ) async {
    return await apiService.semanticSearchCodex(
      novelId: novelId,
      query: query,
    );
  }
  
  // 根据类型获取条目
  Future<List<Character>> getCharacters(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'character',
    );
    
    final characters = entries
        .whereType<Character>()
        .toList();
    
    if (limit != null && characters.length > limit) {
      return characters.sublist(0, limit);
    }
    
    return characters;
  }
  
  Future<List<Location>> getLocations(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'location',
    );
    
    final locations = entries
        .whereType<Location>()
        .toList();
    
    if (limit != null && locations.length > limit) {
      return locations.sublist(0, limit);
    }
    
    return locations;
  }
  
  Future<List<Subplot>> getPlots(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'subplot',
    );
    
    final plots = entries
        .whereType<Subplot>()
        .toList();
    
    if (limit != null && plots.length > limit) {
      return plots.sublist(0, limit);
    }
    
    return plots;
  }
}

// 搜索结果模型
class SearchResult {
  final String id;
  final String title;
  final String content;
  final String type;
  final double score;
  
  SearchResult({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.score,
  });
}
```

### 7. 性能优化

```dart
// 懒加载网格视图
class LazyLoadingCodexGrid extends StatefulWidget {
  final String novelId;
  final String? entryType;
  final Function(CodexEntry) onEntryTap;
  
  const LazyLoadingCodexGrid({
    Key? key,
    required this.novelId,
    this.entryType,
    required this.onEntryTap,
  }) : super(key: key);
  
  @override
  State<LazyLoadingCodexGrid> createState() => _LazyLoadingCodexGridState();
}

class _LazyLoadingCodexGridState extends State<LazyLoadingCodexGrid> {
  static const int pageSize = 20;
  final List<CodexEntry> _entries = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadMore();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }
  
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final repo = context.read<CodexRepository>();
      final newEntries = await repo.getCodexEntriesPaginated(
        novelId: widget.novelId,
        entryType: widget.entryType,
        page: _currentPage,
        pageSize: pageSize,
      );
      
      setState(() {
        _entries.addAll(newEntries);
        _isLoading = false;
        _hasMore = newEntries.length == pageSize;
        _currentPage++;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载条目失败: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateCrossAxisCount(context),
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _entries.length + (_hasMore ? 1 : 0),
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == _entries.length) {
          return _buildLoadingCard();
        }
        return CodexEntryCard(
          entry: _entries[index],
          onTap: () => widget.onEntryTap(_entries[index]),
        );
      },
    );
  }
  
  int _calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }
  
  Widget _buildLoadingCard() {
    return Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}
```

<think>我需要继续完成Codex知识库模块详细设计文档的剩余部分，然后开始小说计划预览模块的详细设计。我会继续提供代码示例、数据结构和UI组件设计。</think># 模块详细设计文档（第二批 - 续2）

## Codex知识库模块详细设计（续）

### 5.3 知识库条目详情视图

```dart
class CodexEntryDetailView extends StatelessWidget {
  final CodexEntry entry;
  final List<CodexEntry> allEntries;
  final Function(CodexEntry) onEdit;
  final Function(String) onDelete;
  
  const CodexEntryDetailView({
    Key? key,
    required this.entry,
    required this.allEntries,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部区域
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图像
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildEntryImage(),
              ),
              SizedBox(width: 16),
              
              // 右侧标题和基本信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getEntryTypeName(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '创建于：${DateFormat('yyyy年MM月dd日').format(entry.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '最后更新：${DateFormat('yyyy年MM月dd日 HH:mm').format(entry.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEdit(entry),
                  icon: Icon(Icons.edit),
                  label: Text('编辑'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: Icon(Icons.delete),
                  label: Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          
          Divider(height: 32),
          
          // 描述部分
          Text(
            '描述',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Text(entry.description),
          
          SizedBox(height: 24),
          
          // 属性部分
          Text(
            '属性',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          ..._buildAttributeWidgets(context),
          
          SizedBox(height: 24),
          
          // 关系部分
          if (entry.relationships.isNotEmpty) ...[
            Text(
              '关系',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            ..._buildRelationshipsWidgets(context),
            SizedBox(height: 24),
          ],
          
          // AI增强操作区域
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI辅助操作',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.auto_awesome, size: 18),
                        label: Text('扩展描述'),
                        onPressed: () => _expandDescription(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.psychology, size: 18),
                        label: Text('生成新特性'),
                        onPressed: () => _generateNewAttributes(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.people, size: 18),
                        label: Text('建议关系'),
                        onPressed: () => _suggestRelationships(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.add_circle, size: 18),
                        label: Text('创建相关条目'),
                        onPressed: () => _createRelatedEntry(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建条目图像
  Widget _buildEntryImage() {
    if (entry is Character && (entry as Character).profileImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Character).profileImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else if (entry is Location && (entry as Location).mapImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Location).mapImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else if (entry is Item && (entry as Item).imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (entry as Item).imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildEntryIcon(),
        ),
      );
    } else {
      return _buildEntryIcon();
    }
  }
  
  // 构建条目图标
  Widget _buildEntryIcon() {
    IconData iconData;
    Color iconColor;
    
    if (entry is Character) {
      iconData = Icons.person;
      iconColor = Colors.blue;
    } else if (entry is Location) {
      iconData = Icons.place;
      iconColor = Colors.green;
    } else if (entry is Item) {
      iconData = Icons.inventory_2;
      iconColor = Colors.amber;
    } else if (entry is Lore) {
      iconData = Icons.auto_stories;
      iconColor = Colors.purple;
    } else if (entry is Subplot) {
      iconData = Icons.timeline;
      iconColor = Colors.red;
    } else {
      iconData = Icons.article;
      iconColor = Colors.grey;
    }
    
    return Center(
      child: Icon(
        iconData,
        size: 48,
        color: iconColor,
      ),
    );
  }
  
  // 获取条目类型名称
  String _getEntryTypeName() {
    if (entry is Character) {
      return '角色';
    } else if (entry is Location) {
      return '地点';
    } else if (entry is Item) {
      return '物品';
    } else if (entry is Lore) {
      return '背景设定';
    } else if (entry is Subplot) {
      return '情节线索';
    } else {
      return '条目';
    }
  }
  
  // 构建属性小部件
  List<Widget> _buildAttributeWidgets(BuildContext context) {
    final List<Widget> widgets = [];
    
    if (entry is Character) {
      final character = entry as Character;
      _addAttributeIfNotEmpty(widgets, '年龄', character.age);
      _addAttributeIfNotEmpty(widgets, '性别', character.gender);
      _addAttributeIfNotEmpty(widgets, '职业', character.occupation);
      _addAttributeIfNotEmpty(widgets, '性格特征', character.personality);
      _addAttributeIfNotEmpty(widgets, '背景故事', character.background);
      _addAttributeIfNotEmpty(widgets, '目标', character.goals);
      _addAttributeIfNotEmpty(widgets, '冲突', character.conflicts);
    } else if (entry is Location) {
      final location = entry as Location;
      _addAttributeIfNotEmpty(widgets, '类型', location.type);
      _addAttributeIfNotEmpty(widgets, '气候', location.climate);
      _addAttributeIfNotEmpty(widgets, '文化', location.culture);
      _addAttributeIfNotEmpty(widgets, '历史', location.history);
      _addAttributeIfNotEmpty(widgets, '重要性', location.significance);
    } else if (entry is Item) {
      final item = entry as Item;
      _addAttributeIfNotEmpty(widgets, '类型', item.type);
      _addAttributeIfNotEmpty(widgets, '来源', item.origin);
      _addAttributeIfNotEmpty(widgets, '属性', item.properties);
      _addAttributeIfNotEmpty(widgets, '重要性', item.significance);
      _addAttributeIfNotEmpty(widgets, '当前位置', item.currentLocation);
    } else if (entry is Lore) {
      final lore = entry as Lore;
      _addAttributeIfNotEmpty(widgets, '分类', lore.category);
      _addAttributeIfNotEmpty(widgets, '历史时期', lore.historicalPeriod);
      _addAttributeIfNotEmpty(widgets, '文化背景', lore.culturalContext);
    } else if (entry is Subplot) {
      final subplot = entry as Subplot;
      _addAttributeIfNotEmpty(widgets, '情节类型', subplot.plotType);
      _addAttributeIfNotEmpty(widgets, '解决方案', subplot.resolution);
      _addAttributeIfNotEmpty(widgets, '相关角色', subplot.relatedCharacters);
      _addAttributeIfNotEmpty(widgets, '高潮', subplot.climax);
    }
    
    // 如果没有任何属性
    if (widgets.isEmpty) {
      widgets.add(
        Text('没有属性', style: TextStyle(fontStyle: FontStyle.italic))
      );
    }
    
    return widgets;
  }
  
  // 添加非空属性
  void _addAttributeIfNotEmpty(List<Widget> widgets, String label, String? value) {
    if (value != null && value.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      );
    }
  }
  
  // 构建关系小部件
  List<Widget> _buildRelationshipsWidgets(BuildContext context) {
    return entry.relationships.map((relationship) {
      // 查找目标条目
      final targetEntry = allEntries.firstWhere(
        (e) => e.id == relationship.targetId,
        orElse: () => null as CodexEntry,  // 这种情况不应该发生
      );
      
      if (targetEntry == null) {
        return SizedBox.shrink();  // 如果找不到目标条目，不显示
      }
      
      return Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(_getEntryTypeIcon(targetEntry)),
          title: Text(targetEntry.title),
          subtitle: Text(
            '${_getRelationshipTypeLabel(relationship.type)}${relationship.description != null ? ': ${relationship.description}' : ''}',
          ),
          onTap: () {
            // 跳转到关联条目详情
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CodexEntryDetailScreen(
                  entry: targetEntry,
                  allEntries: allEntries,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
  
  // 获取条目类型图标
  IconData _getEntryTypeIcon(CodexEntry entry) {
    if (entry is Character) {
      return Icons.person;
    } else if (entry is Location) {
      return Icons.place;
    } else if (entry is Item) {
      return Icons.inventory_2;
    } else if (entry is Lore) {
      return Icons.auto_stories;
    } else if (entry is Subplot) {
      return Icons.timeline;
    } else {
      return Icons.article;
    }
  }
  
  // 获取关系类型标签
  String _getRelationshipTypeLabel(RelationshipType type) {
    switch (type) {
      case RelationshipType.familial:
        return '家庭关系';
      case RelationshipType.romantic:
        return '恋爱关系';
      case RelationshipType.professional:
        return '职业关系';
      case RelationshipType.antagonistic:
        return '敌对关系';
      case RelationshipType.friendly:
        return '友好关系';
      case RelationshipType.ownership:
        return '所有关系';
      case RelationshipType.location:
        return '位置关系';
      case RelationshipType.historical:
        return '历史关系';
      case RelationshipType.custom:
        return '自定义关系';
    }
  }
  
  // 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除"${entry.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete(entry.id);
            },
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
  
  // AI辅助操作：扩展描述
  void _expandDescription(BuildContext context) {
    // 实现AI扩展描述功能
  }
  
  // AI辅助操作：生成新特性
  void _generateNewAttributes(BuildContext context) {
    // 实现AI生成新特性功能
  }
  
  // AI辅助操作：建议关系
  void _suggestRelationships(BuildContext context) {
    // 实现AI建议关系功能
  }
  
  // AI辅助操作：创建相关条目
  void _createRelatedEntry(BuildContext context) {
    // 实现AI创建相关条目功能
  }
}
```

### 6. API交互

```dart
class CodexRepository {
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  CodexRepository({
    required this.apiService,
    required this.localStorageService,
  });
  
  // 获取所有知识库条目
  Future<List<CodexEntry>> getCodexEntries({
    required String novelId,
    String? entryType,
  }) async {
    try {
      // 尝试从服务器获取
      final entries = await apiService.fetchCodexEntries(
        novelId: novelId,
        entryType: entryType,
      );
      
      // 保存到本地缓存
      await localStorageService.saveCodexEntries(novelId, entries);
      
      return entries;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localEntries = await localStorageService.getCodexEntries(
        novelId: novelId,
        entryType: entryType,
      );
      
      if (localEntries.isNotEmpty) {
        return localEntries;
      }
      
      throw Exception('无法加载知识库条目: $e');
    }
  }
  
  // 获取特定条目
  Future<CodexEntry> getCodexEntry({
    required String novelId,
    required String entryId,
  }) async {
    try {
      // 尝试从服务器获取
      final entry = await apiService.fetchCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      // 更新本地缓存
      await localStorageService.saveCodexEntry(novelId, entry);
      
      return entry;
    } catch (e) {
      // 如果服务器请求失败，尝试从本地获取
      final localEntry = await localStorageService.getCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      if (localEntry != null) {
        return localEntry;
      }
      
      throw Exception('无法加载知识库条目: $e');
    }
  }
  
  // 创建知识库条目
  Future<CodexEntry> createCodexEntry({
    required String novelId,
    required String entryType,
    required String title,
    required String description,
    Map<String, dynamic>? attributes,
  }) async {
    try {
      // 创建条目
      final newEntry = await apiService.createCodexEntry(
        novelId: novelId,
        entryType: entryType,
        title: title,
        description: description,
        attributes: attributes,
      );
      
      // 保存到本地
      await localStorageService.saveCodexEntry(novelId, newEntry);
      
      return newEntry;
    } catch (e) {
      // 如果服务器请求失败，创建本地临时条目
      final now = DateTime.now();
      
      CodexEntry tempEntry;
      final id = UUID.v4();
      
      switch (entryType) {
        case 'character':
          tempEntry = Character(
            id: id,
            title: title,
            description: description,
            createdAt: now,
            updatedAt: now,
            novelId: novelId,
            age: attributes?['age'],
            gender: attributes?['gender'],
            occupation: attributes?['occupation'],
            personality: attributes?['personality'],
            background: attributes?['background'],
            goals: attributes?['goals'],
            conflicts: attributes?['conflicts'],
          );
          break;
          
        case 'location':
          tempEntry = Location(
            id: id,
            title: title,
            description: description,
            createdAt: now,
            updatedAt: now,
            novelId: novelId,
            type: attributes?['type'],
            climate: attributes?['climate'],
            culture: attributes?['culture'],
            history: attributes?['history'],
            significance: attributes?['significance'],
          );
          break;
          
        // 其他类型的条目...
        
        default:
          throw Exception('不支持的条目类型: $entryType');
      }
      
      // 标记为需要同步
      await localStorageService.saveCodexEntry(
        novelId, 
        tempEntry,
        needsSync: true,
      );
      
      return tempEntry;
    }
  }
  
  // 更新知识库条目
  Future<CodexEntry> updateCodexEntry({
    required String novelId,
    required CodexEntry entry,
  }) async {
    try {
      // 更新服务器
      final updatedEntry = await apiService.updateCodexEntry(
        novelId: novelId,
        entry: entry,
      );
      
      // 更新本地缓存
      await localStorageService.saveCodexEntry(novelId, updatedEntry);
      
      return updatedEntry;
    } catch (e) {
      // 如果服务器请求失败，仅更新本地并标记为需要同步
      await localStorageService.saveCodexEntry(
        novelId, 
        entry.copyWith(updatedAt: DateTime.now()),
        needsSync: true,
      );
      
      return entry.copyWith(updatedAt: DateTime.now());
    }
  }
  
  // 删除知识库条目
  Future<void> deleteCodexEntry({
    required String novelId,
    required String entryId,
  }) async {
    try {
      // 从服务器删除
      await apiService.deleteCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
      
      // 从本地缓存删除
      await localStorageService.deleteCodexEntry(
        novelId: novelId,
        entryId: entryId,
      );
    } catch (e) {
      // 如果服务器请求失败，标记为待删除
      await localStorageService.markCodexEntryForDeletion(
        novelId: novelId,
        entryId: entryId,
      );
    }
  }
  
  // 使用AI生成条目
  Future<CodexEntry> generateEntryWithAI({
    required String novelId,
    required String entryType,
    required String prompt,
    List<CodexEntry>? existingEntries,
  }) async {
    // 从服务器生成
    final generatedEntry = await apiService.generateCodexEntryWithAI(
      novelId: novelId,
      entryType: entryType,
      prompt: prompt,
      existingEntriesContext: existingEntries,
    );
    
    // 保存到本地
    await localStorageService.saveCodexEntry(novelId, generatedEntry);
    
    return generatedEntry;
  }
  
  // 语义搜索
  Future<List<SearchResult>> semanticSearch(
    String novelId,
    String query,
  ) async {
    return await apiService.semanticSearchCodex(
      novelId: novelId,
      query: query,
    );
  }
  
  // 根据类型获取条目
  Future<List<Character>> getCharacters(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'character',
    );
    
    final characters = entries
        .whereType<Character>()
        .toList();
    
    if (limit != null && characters.length > limit) {
      return characters.sublist(0, limit);
    }
    
    return characters;
  }
  
  Future<List<Location>> getLocations(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'location',
    );
    
    final locations = entries
        .whereType<Location>()
        .toList();
    
    if (limit != null && locations.length > limit) {
      return locations.sublist(0, limit);
    }
    
    return locations;
  }
  
  Future<List<Subplot>> getPlots(String novelId, {int? limit}) async {
    final entries = await getCodexEntries(
      novelId: novelId,
      entryType: 'subplot',
    );
    
    final plots = entries
        .whereType<Subplot>()
        .toList();
    
    if (limit != null && plots.length > limit) {
      return plots.sublist(0, limit);
    }
    
    return plots;
  }
}

// 搜索结果模型
class SearchResult {
  final String id;
  final String title;
  final String content;
  final String type;
  final double score;
  
  SearchResult({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.score,
  });
}
```

### 7. 性能优化

```dart
// 懒加载网格视图
class LazyLoadingCodexGrid extends StatefulWidget {
  final String novelId;
  final String? entryType;
  final Function(CodexEntry) onEntryTap;
  
  const LazyLoadingCodexGrid({
    Key? key,
    required this.novelId,
    this.entryType,
    required this.onEntryTap,
  }) : super(key: key);
  
  @override
  State<LazyLoadingCodexGrid> createState() => _LazyLoadingCodexGridState();
}

class _LazyLoadingCodexGridState extends State<LazyLoadingCodexGrid> {
  static const int pageSize = 20;
  final List<CodexEntry> _entries = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadMore();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }
  
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final repo = context.read<CodexRepository>();
      final newEntries = await repo.getCodexEntriesPaginated(
        novelId: widget.novelId,
        entryType: widget.entryType,
        page: _currentPage,
        pageSize: pageSize,
      );
      
      setState(() {
        _entries.addAll(newEntries);
        _isLoading = false;
        _hasMore = newEntries.length == pageSize;
        _currentPage++;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载条目失败: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _calculateCrossAxisCount(context),
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _entries.length + (_hasMore ? 1 : 0),
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == _entries.length) {
          return _buildLoadingCard();
        }
        return CodexEntryCard(
          entry: _entries[index],
          onTap: () => widget.onEntryTap(_entries[index]),
        );
      },
    );
  }
  
  int _calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }
  
  Widget _buildLoadingCard() {
    return Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}
```

## 小说计划预览模块详细设计

### 1. 模块概述

小说计划预览模块提供了小说结构的可视化和管理功能，允许作者查看和组织小说的章节、场景，并提供整体规划和进度跟踪。该模块支持拖拽重排序、章节扩展和场景管理，并与AI集成以获取创作建议。

### 2. 数据模型

```dart
// 小说结构模型
class NovelStructure {
  final String novelId;
  final String title;
  final List<ChapterOutline> chapters;
  final int totalWordCount;
  final int targetWordCount;
  final double completionPercentage;
  
  NovelStructure({
    required this.novelId,
    required this.title,
    required this.chapters,
    this.totalWordCount = 0,
    this.targetWordCount = 0,
    this.completionPercentage = 0.0,
  });
}

// 章节大纲模型
class ChapterOutline {
  final String id;
  final String title;
  final int order;
  final String? summary;
  final List<SceneOutline> scenes;
  final int wordCount;
  final ChapterStatus status;
  
  ChapterOutline({
    required this.id,
    required this.title,
    required this.order,
    this.summary,
    required this.scenes,
    this.wordCount = 0,
    this.status = ChapterStatus.planned,
  });
  
  // 计算完成状态
  ChapterStatus calculateStatus() {
    if (scenes.isEmpty) {
      return ChapterStatus.planned;
    }
    
    final completedScenes = scenes.where((s) => 
        s.status == SceneStatus.completed).length;
    
    if (completedScenes == 0) {
      return ChapterStatus.planned;
    } else if (completedScenes == scenes.length) {
      return ChapterStatus.completed;
    } else {
      return ChapterStatus.inProgress;
    }
  }
  
  // 创建副本
  ChapterOutline copyWith({
    String? id,
    String? title,
    int? order,
    String? summary,
    List<SceneOutline>? scenes,
    int? wordCount,
    ChapterStatus? status,
  }) {
    return ChapterOutline(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      summary: summary ?? this.summary,
      scenes: scenes ?? this.scenes,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
    );
  }
}

// 场景大纲模型
class SceneOutline {
  final String id;
  final String title;
  final int order;
  final String? summary;
  final int wordCount;
  final SceneStatus status;
  final List<String>? characterIds;
  final String? locationId;
  final String? pov;
  
  SceneOutline({
    required this.id,
    required this.title,
    required this.order,
    this.summary,
    this.wordCount = 0,
    this.status = SceneStatus.planned,
    this.characterIds,
    this.locationId,
    this.pov,
  });
  
  // 创建副本
  SceneOutline copyWith({
    String? id,
    String? title,
    int? order,
    String? summary,
    int? wordCount,
    SceneStatus? status,
    List<String>? characterIds,
    String? locationId,
    String? pov,
  }) {
    return SceneOutline(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      summary: summary ?? this.summary,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      characterIds: characterIds ?? this.characterIds,
      locationId: locationId ?? this.locationId,
      pov: pov ?? this.pov,
    );
  }
}

// 章节状态
enum ChapterStatus {
  planned,      // 计划中
  inProgress,   // 进行中
  completed,    // 已完成
  revision,     // 修订中
}

// 场景状态
enum SceneStatus {
  planned,      // 计划中
  drafted,      // 已起草
  completed,    // 已完成
  revision,     // 修订中
}
```

### 3. 状态管理

```dart
// 小说计划状态管理
class NovelPlanBloc extends Bloc<NovelPlanEvent, NovelPlanState> {
  final NovelPlanRepository repository;
  
  NovelPlanBloc({required this.repository}) : super(NovelPlanInitial()) {
    on<LoadNovelStructure>(_onLoadStructure);
    on<AddChapter>(_onAddChapter);
    on<UpdateChapter>(_onUpdateChapter);
    on<DeleteChapter>(_onDeleteChapter);
    on<ReorderChapters>(_onReorderChapters);
    on<AddScene>(_onAddScene);
    on<UpdateScene>(_onUpdateScene);
    on<DeleteScene>(_onDeleteScene);
    on<ReorderScenes>(_onReorderScenes);
    on<GenerateChapterWithAI>(_onGenerateChapterWithAI);
    on<GenerateSceneWithAI>(_onGenerateSceneWithAI);
  }
  
  Future<void> _onLoadStructure(LoadNovelStructure event, Emitter<NovelPlanState> emit) async {
    emit(NovelPlanLoading());
    
    try {
      final structure = await repository.getNovelStructure(event.novelId);
      emit(NovelPlanLoaded(structure: structure));
    } catch (e) {
      emit(NovelPlanError(message: '加载小说结构失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onAddChapter(AddChapter event, Emitter<NovelPlanState> emit) async {
    if (state is NovelPlanLoaded) {
      final currentState = state as NovelPlanLoaded;
      final structure = currentState.structure;
      
      try {
        // 计算新章节的顺序
        final nextOrder = structure.chapters.isEmpty 
            ? 1 
            : structure.chapters.map((c) => c.order).reduce(max) + 1;
        
        // 创建新章节
        final newChapter = ChapterOutline(
          id: UUID.v4(),
          title: event.title.isEmpty ? '第$nextOrder章' : event.title,
          order: nextOrder,
          scenes: [],
        );
        
        // 更新结构
        final updatedChapters = [...structure.chapters, newChapter];
        final updatedStructure = NovelStructure(
          novelId: structure.novelId,
          title: structure.title,
          chapters: updatedChapters,
          totalWordCount: structure.totalWordCount,
          targetWordCount: structure.targetWordCount,
          completionPercentage: structure.completionPercentage,
        );
        
        // 保存到仓库
        await repository.saveNovelStructure(updatedStructure);
        
        // 更新状态
        emit(NovelPlanLoaded(structure: updatedStructure));
      } catch (e) {
        emit(NovelPlanError(message: '添加章节失败: ${e.toString()}'));
      }
    }
  }
  
  Future<void> _onReorderChapters(ReorderChapters event, Emitter<NovelPlanState> emit) async {
    if (state is NovelPlanLoaded) {
      final currentState = state as NovelPlanLoaded;
      final structure = currentState.structure;
      
      try {
        // 克隆章节列表
        final chapters = List<ChapterOutline>.from(structure.chapters);
        
        // 移动项目
        final movedItem = chapters.removeAt(event.oldIndex);
        chapters.insert(event.newIndex, movedItem);
        
        // 更新顺序
        for (int i = 0; i < chapters.length; i++) {
          chapters[i
