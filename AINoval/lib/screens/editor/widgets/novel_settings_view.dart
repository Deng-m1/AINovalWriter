import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ainoval/models/novel_summary.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/storage_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

class NovelSettingsView extends StatefulWidget {
  const NovelSettingsView({
    super.key, 
    required this.novel,
    required this.onSettingsClose,
  });

  final NovelSummary novel;
  final VoidCallback onSettingsClose;

  @override
  State<NovelSettingsView> createState() => _NovelSettingsViewState();
}

class _NovelSettingsViewState extends State<NovelSettingsView> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesController;
  
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  
  String? _coverUrl;
  bool _isSaving = false;
  String? _saveError;
  bool _hasChanges = false;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.novel.title);
    _authorController = TextEditingController(text: widget.novel.author ?? '');
    _seriesController = TextEditingController(text: widget.novel.seriesName);
    _coverUrl = widget.novel.coverUrl;
    
    // 监听文本变化以跟踪更改状态
    _titleController.addListener(_onFieldChanged);
    _authorController.addListener(_onFieldChanged);
    _seriesController.addListener(_onFieldChanged);
  }
  
  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _seriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：元数据和危险区域
          Expanded(
            flex: 3,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 元数据标题
                  Text(
                    'METADATA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 小说标题
                  _buildTextField(
                    controller: _titleController,
                    label: '小说标题',
                    hint: '为您的小说起个好名字',
                    icon: Icons.title,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // 作者/笔名
                  _buildTextField(
                    controller: _authorController,
                    label: '作者 / 笔名',
                    hint: '您的笔名或真实姓名',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  
                  // 系列名
                  _buildTextField(
                    controller: _seriesController,
                    label: '系列名 (可选)',
                    hint: '如果这本小说属于某个系列',
                    icon: Icons.bookmarks_outlined,
                  ),
                  const SizedBox(height: 24),
                  
                  // 保存按钮
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _hasChanges && !_isSaving 
                          ? _saveMetadata 
                          : null,
                        icon: _isSaving 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Icon(Icons.save),
                        label: Text(_isSaving ? '保存中...' : '保存更改'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: widget.onSettingsClose,
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                  
                  // 保存错误消息
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _saveError!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // 危险区域
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DANGER ZONE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 归档按钮
                      OutlinedButton.icon(
                        onPressed: () => _showArchiveConfirmDialog(context),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('归档小说'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, 
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 删除按钮
                      OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmDialog(context),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除小说'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, 
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 32),
          
          // 右侧：封面上传和预览
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面标题
                Text(
                  'COVER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 封面预览/上传区域
                InkWell(
                  onTap: _isUploading ? null : _selectCoverImage,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 320,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _buildCoverPreview(),
                  ),
                ),
                
                // 上传按钮
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _selectCoverImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isUploading ? '上传中...' : '上传封面'),
                  ),
                ),
                
                // 上传进度条
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(value: _uploadProgress),
                  ),
                
                // 上传错误消息
                if (_uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _uploadError!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: required 
        ? (value) => value == null || value.isEmpty 
            ? '$label不能为空' 
            : null
        : null,
    );
  }
  
  Widget _buildCoverPreview() {
    // 如果有现有的封面URL，显示现有封面
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _coverUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / 
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        '无法加载封面',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 悬停时显示更改提示
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '点击更换封面',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // 如果没有封面，显示上传提示
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 64,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          '点击上传封面',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '支持 JPG, PNG, GIF, WEBP 格式',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          '建议尺寸：600×900 像素',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
  
  Future<void> _selectCoverImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
        });
        
        Uint8List fileBytes;
        if (file.bytes != null) {
          // Web平台直接获取字节
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          // 移动/桌面平台从文件路径读取字节
          final File imageFile = File(file.path!);
          fileBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('无法读取所选图片');
        }
        
        // 压缩图片以减小尺寸
        final img.Image? image = img.decodeImage(fileBytes);
        if (image == null) {
          throw Exception('无法解码所选图片');
        }
        
        // 如果图片过大，进行缩放
        img.Image resizedImage = image;
        if (image.width > 1200 || image.height > 1200) {
          resizedImage = img.copyResize(
            image,
            width: image.width > image.height ? 1200 : null,
            height: image.height >= image.width ? 1200 : null,
          );
        }
        
        // 重新编码为JPEG格式
        final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
        
        // 上传图片
        await _uploadCoverImage(Uint8List.fromList(compressedBytes), '${widget.novel.id}_cover.jpg');
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', '选择封面图片失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _uploadError = '选择图片失败: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }
  
  Future<void> _uploadCoverImage(Uint8List bytes, String fileName) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });
    
    try {
      final editorRepository = context.read<EditorRepository>();
      final storageRepository = context.read<StorageRepository>();
      
      setState(() {
        _uploadProgress = 0.1; // 开始上传
      });
      
      // 实际上传封面图片
      final coverUrl = await storageRepository.uploadCoverImage(
        novelId: widget.novel.id,
        fileBytes: bytes,
        fileName: fileName,
      );
      
      // 上传进度更新
      setState(() {
        _uploadProgress = 0.9; // 上传完成，即将更新元数据
      });
      
      // 通知后端更新封面URL
      await editorRepository.updateNovelCover(
        novelId: widget.novel.id,
        coverUrl: coverUrl,
      );
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _coverUrl = coverUrl;
          _uploadProgress = 1.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('封面上传成功')),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', '上传封面失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = '上传失败: $e';
        });
      }
    }
  }
  
  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    
    try {
      final repository = context.read<EditorRepository>();
      await repository.updateNovelMetadata(
        novelId: widget.novel.id,
        title: _titleController.text,
        author: _authorController.text,
        series: _seriesController.text,
      );
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小说信息已更新')),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', '保存元数据失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = '保存失败: $e';
        });
      }
    }
  }
  
  Future<void> _showArchiveConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档确认'),
        content: const Text(
          '归档后，小说将从主列表中隐藏，但可以随时恢复。确定要归档吗？'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认归档'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _archiveNovel();
    }
  }
  
  Future<void> _archiveNovel() async {
    try {
      final repository = context.read<EditorRepository>();
      await repository.archiveNovel(novelId: widget.novel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小说已归档')),
        );
        // 返回小说列表
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', '归档小说失败', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('归档失败: $e')),
        );
      }
    }
  }
  
  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final novelTitle = _titleController.text;
    final TextEditingController confirmController = TextEditingController();
    
    // 使用TextEditingController确保在dispose时被正确清理
    bool confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, 
              color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('永久删除'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '警告：此操作不可逆转！',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '删除后，小说的所有内容、章节和设置将永久丢失，且无法恢复。',
            ),
            const SizedBox(height: 16),
            Text(
              '请输入小说标题"$novelTitle"以确认删除：',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入小说标题确认',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (confirmController.text == novelTitle) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('标题不匹配，无法删除')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    ) ?? false;
    
    // 清理控制器
    confirmController.dispose();
    
    if (confirmed) {
      _deleteNovel();
    }
  }
  
  Future<void> _deleteNovel() async {
    try {
      final repository = context.read<EditorRepository>();
      await repository.deleteNovel(novelId: widget.novel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小说已永久删除')),
        );
        // 返回小说列表
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', '删除小说失败', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
} 