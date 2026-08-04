import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class SoftAppBar extends StatelessWidget {
  const SoftAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      title: Text(title),
      actions: actions,
    );
  }
}

class SoftLoading extends StatelessWidget {
  const SoftLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Semantics(
          label: '加载中',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class SoftError extends StatelessWidget {
  const SoftError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Text(
          message,
          style: AppTheme.body(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
