import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/ui_bits.dart';
import '../auth/auth_controller.dart';
import '../practice/practice_constants.dart';
import '../practice/practice_stats_store.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  static const _maxWidth = 560.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final stats = ref.watch(practiceStatsProvider);
    final minutes = (stats.totalSeconds / 60).floor();
    final todayMin = (stats.todaySeconds() / 60).floor();
    final todayProgress = stats.todayProgress01();
    final goal = PracticeConstants.dailyPracticeGoalMinutes;
    final name = auth.displayName ?? '访客';
    final email = auth.email ?? '';
    final initial =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          children: [
            Text('我的', style: AppTheme.display(fontSize: 32)),
            const SizedBox(height: 28),
            // User block — custom layout, not ListTile (avoids subtitle clip).
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.accentSoft,
                    child: Text(
                      initial,
                      style: AppTheme.body(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTheme.body(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: AppTheme.body(
                              fontSize: 14,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('今日练习'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '今日 $todayMin / $goal 分钟',
                        style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(todayProgress * 100).round()}%',
                        style: AppTheme.body(
                          fontSize: 13,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: todayProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceAlt,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('练习概览'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  _Stat(label: '练习次数', value: '${stats.totalSessions}'),
                  _Stat(label: '累计分钟', value: '$minutes'),
                  _Stat(label: '曲目数', value: '${stats.bySong.length}'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.auto_awesome_rounded,
                    title: '练习星座',
                    subtitle: '点亮练过的曲子',
                    onTap: () => context.push('/constellation'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ActionRow(
                    icon: Icons.music_note_outlined,
                    title: '节拍器与试音',
                    subtitle: '独立节拍器 + 点按 88 键试音',
                    onTap: () => context.push('/sandbox'),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  _ActionRow(
                    icon: Icons.graphic_eq,
                    title: '音高识别测试',
                    subtitle: '播放音频，检查识别与琴键高亮',
                    onTap: () => context.push('/pitch-test'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ActionRow(
                    icon: Icons.settings_outlined,
                    title: '设置',
                    subtitle: '关于与偏好',
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ActionRow(
                    icon: Icons.logout,
                    title: '退出登录',
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.display(
              fontSize: 26,
              color: AppColors.accent,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTheme.body(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
