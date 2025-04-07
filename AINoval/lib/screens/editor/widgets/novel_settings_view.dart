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

// Enum to represent the different tabs
enum NovelEditorTab { metadata, writing, collaboration, export }

class NovelSettingsView extends StatefulWidget {
  const NovelSettingsView({
    super.key, 
    required this.novel,
    required this.onSettingsClose,
    this.availableSeries = const ['New Series'], 
  });

  final NovelSummary novel;
  final VoidCallback onSettingsClose;
  final List<String> availableSeries;

  @override
  State<NovelSettingsView> createState() => _NovelSettingsViewState();
}

class _NovelSettingsViewState extends State<NovelSettingsView> {
  final _formKey = GlobalKey<FormState>();
  
  // State for the selected tab
  NovelEditorTab _selectedTab = NovelEditorTab.metadata; 

  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesIndexController;
  
  String? _selectedSeries;
  
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
    _selectedSeries = widget.novel.seriesName?.isNotEmpty == true 
        ? widget.novel.seriesName 
        : (widget.availableSeries.isNotEmpty ? widget.availableSeries.first : null);
    _seriesIndexController = TextEditingController(text: '' /* widget.novel.seriesIndex ?? '' */);
    
    _coverUrl = widget.novel.coverUrl;
    
    _titleController.addListener(_onFieldChanged);
    _authorController.addListener(_onFieldChanged);
    _seriesIndexController.addListener(_onFieldChanged);
  }
  
  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }
  
  void _onSeriesChanged(String? newValue) {
    setState(() {
      _selectedSeries = newValue;
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _seriesIndexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    return Container(
      color: Colors.grey[100], // Add light grey background
      // Use all available height if needed, or constrain it
      // height: double.infinity, 
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          // Use Column to stack Navigation Bar and Content
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch content horizontally
            children: [
              // Navigation Bar
              _buildNavigationBar(),
              const SizedBox(height: 24), // Spacing below nav bar

              // Content Area based on selected tab
              Expanded( // Use Expanded to take remaining vertical space
                child: _buildSelectedTabView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Builds the top navigation bar
  Widget _buildNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Align buttons to the left
        children: [
          _buildNavButton(NovelEditorTab.metadata, '元数据', Icons.info_outline),
          _buildNavButton(NovelEditorTab.writing, '写作', Icons.edit_note),
          _buildNavButton(NovelEditorTab.collaboration, '协作', Icons.people_outline),
          _buildNavButton(NovelEditorTab.export, '导出', Icons.upload_file_outlined),
        ],
      ),
    );
  }

  // Helper to build individual navigation buttons
  Widget _buildNavButton(NovelEditorTab tab, String label, IconData icon) {
    final bool isSelected = _selectedTab == tab;
    final theme = Theme.of(context);
    final Color activeColor = theme.colorScheme.primary; // Or your desired active color
    final Color inactiveColor = Colors.grey.shade600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
        },
        splashColor: theme.primaryColor.withOpacity(0.1),
        highlightColor: theme.primaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? activeColor : inactiveColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14, // Adjust font size if needed
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Builds the content view based on the selected tab
  Widget _buildSelectedTabView() {
    switch (_selectedTab) {
      case NovelEditorTab.metadata:
        return _buildMetadataSettingsView(); // Return the original settings content
      case NovelEditorTab.writing:
        return const Center(child: Text('写作 界面 (待开发)')); // Placeholder
      case NovelEditorTab.collaboration:
        return const Center(child: Text('协作 界面 (待开发)')); // Placeholder
      case NovelEditorTab.export:
        return const Center(child: Text('导出 界面 (待开发)')); // Placeholder
    }
  }

  // Extracted the original settings content into its own builder method
  Widget _buildMetadataSettingsView() {
     final theme = Theme.of(context);
     final textTheme = theme.textTheme;

    // Row containing the card-styled metadata form and cover preview
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Left Column: Metadata Form and Danger Zone --- 
        Expanded(
          flex: 3,
          child: SingleChildScrollView( // Make the left column scrollable independently
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Metadata Card --- 
                _buildCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'METADATA',
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '这是您小说的元数据，用于整理您的小说集锦。', // Chinese
                          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        
                        _buildLabeledTextField(
                          controller: _titleController,
                          label: '小说标题', // Chinese
                          required: true,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildLabeledTextField(
                          controller: _authorController,
                          label: '作者 / 笔名', // Chinese
                        ),
                        const SizedBox(height: 20),
                        
                        _buildSeriesInput(), // Contains Chinese text inside
                        
                        const SizedBox(height: 32),
                        
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _hasChanges && !_isSaving 
                                ? _saveMetadata 
                                : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                textStyle: textTheme.labelLarge,
                              ),
                              child: _isSaving 
                                ? const SizedBox(
                                    width: 18, 
                                    height: 18, 
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                                  )
                                : const Text('保存更改'), // Chinese
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: widget.onSettingsClose, // This button might navigate away entirely now
                              child: const Text('取消'), // Chinese
                              style: TextButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                 textStyle: textTheme.labelLarge,
                              )
                            ),
                          ],
                        ),
                        
                        if (_saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _saveError!, // Error messages likely still in English from backend
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Spacing between cards

                // --- Danger Zone Card --- 
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DANGER ZONE',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '本节中的某些操作无法撤销，并可能产生意想不到的后果。', // Chinese
                        style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                           TextButton.icon(
                            onPressed: () => _showArchiveConfirmDialog(context),
                            icon: const Icon(Icons.archive_outlined, size: 18),
                            label: const Text('归档小说'), // Chinese
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          TextButton.icon(
                            onPressed: () => _showDeleteConfirmDialog(context),
                            icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                            label: Text('删除小说', style: TextStyle(color: theme.colorScheme.error)), // Chinese
                            style: TextButton.styleFrom(
                               foregroundColor: theme.colorScheme.error,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16), // Bottom padding inside card
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 48),
        
        // --- Right Column: Cover Card --- 
        Expanded(
          flex: 2,
          // Wrap the cover section in a card
          child: _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COVER',
                   style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                ),
                 Text(
                  '这是您小说的封面。它将显示在小说集锦页面上。', // Chinese
                  style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
    
                Text(
                  '上传你的封面', // Chinese
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                 Text(
                  '或将文件拖放到此区域', // Chinese
                  style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
    
                // Wrap InkWell with AspectRatio for better responsive height?
                // Or keep fixed height if design requires it.
                InkWell(
                  onTap: _isUploading ? null : _selectCoverImage,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 350, // Keep fixed height as per previous design
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _uploadError != null 
                            ? theme.colorScheme.error 
                            : Colors.grey.shade300,
                        width: 1,
                       ),
                    ),
                    child: _buildCoverPreview(), // Cover preview logic remains the same
                  ),
                ),
                
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('上传中 ${_selectedFileName ?? '图片'}...', style: textTheme.bodySmall), // Chinese
                         const SizedBox(height: 4),
                         LinearProgressIndicator(
                           value: _uploadProgress, 
                           minHeight: 6,
                           borderRadius: BorderRadius.circular(3),
                         ),
                       ],
                    )
                  )
              ],
            ),
          ), // End Card
        ),
      ],
    );
  }

  
  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (required ? ' *' : ''),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          validator: required 
            ? (value) => value == null || value.isEmpty 
                // Use label in error message
                ? '$label 不能为空' // Chinese
                : null
            : null,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSeriesInput() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentSelectedSeries = widget.availableSeries.contains(_selectedSeries) 
      ? _selectedSeries 
      : (widget.availableSeries.isNotEmpty ? widget.availableSeries.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '系列 (可选)', // Chinese
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: currentSelectedSeries,
                items: widget.availableSeries.map((String seriesName) {
                  // Handle "New Series" display logic if needed
                  return DropdownMenuItem<String>(
                    value: seriesName,
                    child: Text(seriesName == 'New Series' ? '新建系列' : seriesName), // Example Chinese display
                  );
                }).toList(),
                onChanged: _onSeriesChanged,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                   isDense: true,
                ),
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _seriesIndexController,
                decoration: const InputDecoration(
                  hintText: '系列索引 (例如：卷一)', // Chinese hint
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                   isDense: true,
                ),
                 style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildCoverPreview() {
     final theme = Theme.of(context);
     final textTheme = theme.textTheme;

    if (_isUploading && _uploadProgress < 0.9) {
       return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: _uploadProgress > 0.1 ? _uploadProgress : null),
              const SizedBox(height: 16),
              Text('上传中...', style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)), // Chinese
              if (_selectedFileName != null) 
                Text(_selectedFileName!, style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }
    
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Image.network(
          _coverUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                  : null,
            ));
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildUploadPlaceholder(isError: true);
          },
        ),
      );
    }
    
    return _buildUploadPlaceholder();
  }

  Widget _buildUploadPlaceholder({bool isError = false}) {
    final color = isError ? Theme.of(context).colorScheme.error : Colors.grey.shade500;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.cloud_upload_outlined,
              size: 56,
              color: color,
            ),
            const SizedBox(height: 16),
             Text(
              isError ? '封面加载失败' : '上传封面', // Chinese
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
             const SizedBox(height: 4),
             Text(
              isError ? '请重试上传.' : '或拖放到此区域', // Chinese
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            if (!isError) ...[
               const SizedBox(height: 12),
               Text(
                '支持 JPG, PNG, GIF, WEBP 格式\n建议尺寸: 600x900 像素', // Chinese
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  height: 1.3
                ),
              ),
            ]
           
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectCoverImage() async {
    setState(() {
      _uploadError = null;
      _selectedFileName = null;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        final fileExtension = file.extension?.toLowerCase();
        if (fileExtension == null || !allowedExtensions.contains(fileExtension)) {
           throw Exception('无效的文件类型。请选择 JPG, PNG, GIF 或 WEBP。'); // Chinese
        }

        setState(() {
          _selectedFileName = file.name;
        });
        
        Uint8List fileBytes;
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          final File imageFile = File(file.path!);
          fileBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('无法读取所选图片文件。'); // Chinese
        }
        
        final img.Image? image = img.decodeImage(fileBytes);
        if (image == null) {
          throw Exception('无法解码所选图片。'); // Chinese
        }
        
        img.Image resizedImage = image;
        const maxSize = 1200;
        if (image.width > maxSize || image.height > maxSize) {
          resizedImage = img.copyResize(
            image,
            width: image.width > image.height ? maxSize : null,
            height: image.height >= image.width ? maxSize : null,
            interpolation: img.Interpolation.average,
          );
        }
        
        final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${widget.novel.id}_${timestamp}_cover.jpg';

        await _uploadCoverImage(Uint8List.fromList(compressedBytes), uniqueFileName);
      } else {
         AppLogger.i('NovelSettingsView', 'User cancelled file selection.');
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', 'Error selecting/processing cover image', e, stackTrace);
      if (mounted) {
        final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        setState(() {
          _uploadError = errorMessage;
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $errorMessage'), backgroundColor: Theme.of(context).colorScheme.error), // Chinese
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
      
      await Future.delayed(const Duration(milliseconds: 100));
       if (!mounted) return;
       setState(() => _uploadProgress = 0.1);
      
      final coverUrl = await storageRepository.uploadCoverImage(
        novelId: widget.novel.id,
        fileBytes: bytes,
        fileName: fileName,
      );
       if (!mounted) return;
       setState(() => _uploadProgress = 0.8);

      await editorRepository.updateNovelCover(
        novelId: widget.novel.id,
        coverUrl: coverUrl,
      );
       if (!mounted) return;

      setState(() {
        _coverUrl = coverUrl;
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));
       if (!mounted) return;

      setState(() {
         _isUploading = false;
         _selectedFileName = null;
         _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('封面上传成功!')), // Chinese
      );
      
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', 'Failed to upload cover image', e, stackTrace);
       if (mounted) {
         final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
         setState(() {
          _isUploading = false;
          _uploadError = errorMessage;
          _uploadProgress = 0.0;
        });
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $errorMessage'), backgroundColor: Theme.of(context).colorScheme.error), // Chinese
        );
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
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        series: (_selectedSeries != null && _selectedSeries != 'New Series') ? _selectedSeries : null,
        // TODO: Update EditorRepository.updateNovelMetadata to accept seriesIndex
        // seriesIndex: _seriesIndexController.text.trim(), // Save index
      );
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小说元数据已更新.')), // Chinese
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', 'Failed to save metadata', e, stackTrace);
      if (mounted) {
        final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        setState(() {
          _isSaving = false;
          _saveError = '保存失败: $errorMessage'; // Keep backend error potentially English
        });
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $errorMessage'), backgroundColor: Theme.of(context).colorScheme.error), // Chinese prefix
        );
      }
    }
  }
  
  Future<void> _showArchiveConfirmDialog(BuildContext context) async {
     final theme = Theme.of(context);
     final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('确认归档'), // Chinese
          ],
        ),
        content: const Text(
          '归档操作会将小说从您的主列表中隐藏。您可以稍后取消归档。确定要归档这本小说吗？' // Chinese
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'), // Chinese
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认归档'), // Chinese
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
          const SnackBar(content: Text('小说已成功归档。')), // Chinese
        );
        widget.onSettingsClose(); // Close or navigate back
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', 'Failed to archive novel', e, stackTrace);
      if (mounted) {
         final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('归档失败: $errorMessage'), backgroundColor: Theme.of(context).colorScheme.error), // Chinese prefix
        );
      }
    }
  }
  
  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
     final theme = Theme.of(context);
     final novelTitle = _titleController.text.trim();
     final TextEditingController confirmController = TextEditingController();
     bool isConfirmed = false;
    
    final confirmedResult = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
         return StatefulBuilder(
          builder: (context, setDialogState) {
             return AlertDialog(
               title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('永久删除'), // Chinese
                ],
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                     const Text(
                      '警告：此操作无法撤销!', // Chinese
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '删除这本小说将永久移除其所有内容、章节和设置。这些数据将无法恢复。', // Chinese
                    ),
                    const SizedBox(height: 16),
                    RichText(
                       text: TextSpan(
                         style: DefaultTextStyle.of(context).style,
                         children: <TextSpan>[
                           const TextSpan(text: '请输入小说标题 '), // Chinese
                           TextSpan(text: '"$novelTitle"', style: const TextStyle(fontWeight: FontWeight.bold)),
                           const TextSpan(text: ' 以确认删除:'), // Chinese
                         ],
                       ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '输入 "$novelTitle"', // Chinese
                        errorText: !isConfirmed && confirmController.text.isNotEmpty && confirmController.text != novelTitle 
                          ? '标题不匹配' // Chinese
                          : null,
                      ),
                      autofocus: true,
                       onChanged: (value) {
                         setDialogState(() {
                           isConfirmed = value == novelTitle;
                         });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'), // Chinese
                ),
                ElevatedButton(
                  onPressed: isConfirmed ? () {
                     Navigator.pop(context, true);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                     disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('确认删除'), // Chinese
                ),
              ],
            );
          }
        );
      }
    );
    
    confirmController.dispose();
    if (confirmedResult == true) {
      _deleteNovel();
    }
  }
  
  Future<void> _deleteNovel() async {
     try {
      final repository = context.read<EditorRepository>();
      await repository.deleteNovel(novelId: widget.novel.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小说已永久删除。')), // Chinese
        );
         widget.onSettingsClose(); // Close or navigate back
      }
    } catch (e, stackTrace) {
      AppLogger.e('NovelSettingsView', 'Failed to delete novel', e, stackTrace);
      if (mounted) {
         final errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $errorMessage'), backgroundColor: Theme.of(context).colorScheme.error), // Chinese prefix
        );
      }
    }
  }

  // Helper method to build a styled card Container
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
        // Optional: Add a subtle shadow
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.grey.withOpacity(0.1),
        //     spreadRadius: 1,
        //     blurRadius: 3,
        //     offset: Offset(0, 1), // changes position of shadow
        //   ),
        // ],
      ),
      child: child,
    );
  }
} 