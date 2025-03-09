import 'package:ainoval/models/editor_settings.dart';
import 'package:flutter/material.dart';

class EditorSettingsPanel extends StatefulWidget {
  
  const EditorSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });
  final EditorSettings settings;
  final Function(EditorSettings) onSettingsChanged;

  @override
  State<EditorSettingsPanel> createState() => _EditorSettingsPanelState();
}

class _EditorSettingsPanelState extends State<EditorSettingsPanel> {
  late EditorSettings _settings;
  
  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 字体大小设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '字体大小',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('小'),
                    Expanded(
                      child: Slider(
                        value: _settings.fontSize,
                        min: 12,
                        max: 24,
                        divisions: 12,
                        label: _settings.fontSize.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(fontSize: value);
                          });
                          widget.onSettingsChanged(_settings);
                        },
                      ),
                    ),
                    const Text('大'),
                  ],
                ),
                Center(
                  child: Text(
                    '示例文本',
                    style: TextStyle(
                      fontSize: _settings.fontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 行间距设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '行间距',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('紧凑'),
                    Expanded(
                      child: Slider(
                        value: _settings.lineSpacing,
                        min: 1.0,
                        max: 2.0,
                        divisions: 10,
                        label: _settings.lineSpacing.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(lineSpacing: value);
                          });
                          widget.onSettingsChanged(_settings);
                        },
                      ),
                    ),
                    const Text('宽松'),
                  ],
                ),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '示例文本行1',
                        style: TextStyle(
                          height: _settings.lineSpacing,
                        ),
                      ),
                      Text(
                        '示例文本行2',
                        style: TextStyle(
                          height: _settings.lineSpacing,
                        ),
                      ),
                      Text(
                        '示例文本行3',
                        style: TextStyle(
                          height: _settings.lineSpacing,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 字体选择
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '字体',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _settings.fontFamily,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Roboto',
                      child: Text('Roboto'),
                    ),
                    DropdownMenuItem(
                      value: 'serif',
                      child: Text('宋体'),
                    ),
                    DropdownMenuItem(
                      value: 'monospace',
                      child: Text('等宽字体'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(fontFamily: value);
                      });
                      widget.onSettingsChanged(_settings);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '示例文本',
                    style: TextStyle(
                      fontFamily: _settings.fontFamily,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 自动保存设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动保存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('启用自动保存'),
                  value: _settings.autoSaveEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(autoSaveEnabled: value);
                    });
                    widget.onSettingsChanged(_settings);
                  },
                ),
                if (_settings.autoSaveEnabled) ...[
                  const SizedBox(height: 8),
                  const Text('自动保存间隔'),
                  const SizedBox(height: 8),
                  Slider(
                    value: _settings.autoSaveIntervalMinutes.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 9,
                    label: '${(_settings.autoSaveIntervalMinutes / 60).toStringAsFixed(1)}分钟',
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          autoSaveIntervalMinutes: value.toInt(),
                        );
                      });
                      widget.onSettingsChanged(_settings);
                    },
                  ),
                  Center(
                    child: Text(
                      '每${(_settings.autoSaveIntervalMinutes / 60).toStringAsFixed(1)}分钟自动保存一次',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 拼写检查
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '拼写检查',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('启用拼写检查'),
                  value: _settings.spellCheckEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(spellCheckEnabled: value);
                    });
                    widget.onSettingsChanged(_settings);
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 主题模式
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主题',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('深色模式'),
                  value: _settings.darkModeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(darkModeEnabled: value);
                    });
                    widget.onSettingsChanged(_settings);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 