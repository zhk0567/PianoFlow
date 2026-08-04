import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '关于',
            style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              title: Text('PianoFlow'),
              subtitle: Text(
                '互动练琴 App · Windows / Android\n'
                '跟弹请用麦克风弹真琴（屏幕琴键仅高亮，不可点击发声）\n'
                '曲库含正式校对谱与 OMR 草稿；草稿未逐音校对，勿当教材',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('音高识别测试'),
              subtitle: const Text('播放音频，检查识别与琴键高亮'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pitch-test'),
            ),
          ),
        ],
      ),
    );
  }
}
