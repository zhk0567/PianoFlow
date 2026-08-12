import 'package:flutter/material.dart';

enum WorkshopToolId {
  pdfToScore,
  editScore,
  importMusicXml,
  importMidi,
  importAudio,
  importOther,
}

class WorkshopTool {
  const WorkshopTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.available,
    this.statusLabel,
  });

  final WorkshopToolId id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// True when the in-app path can do useful work (may still be draft-only).
  final bool available;

  /// Badge override; defaults to 可用 / 筹备中 from [available].
  final String? statusLabel;

  String get badge =>
      statusLabel ?? (available ? '可用' : '筹备中');

  static const all = <WorkshopTool>[
    WorkshopTool(
      id: WorkshopToolId.pdfToScore,
      title: 'PDF → 曲谱',
      subtitle: '引导：暂存 PDF → OMR → 校对后导入 MusicXML（自导入草稿）',
      icon: Icons.picture_as_pdf_outlined,
      available: true,
      statusLabel: '引导可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importMusicXml,
      title: '导入 MusicXML',
      subtitle: '本机 .musicxml / .xml / .mxl → 自导入曲库',
      icon: Icons.upload_file_rounded,
      available: true,
    ),
    WorkshopTool(
      id: WorkshopToolId.editScore,
      title: '编辑曲谱',
      subtitle: '自导入：元数据 + 音符表（MIDI/拍/手）；外部 MusicXML；删除',
      icon: Icons.edit_note_rounded,
      available: true,
      statusLabel: '音符表可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importMidi,
      title: '导入 MIDI',
      subtitle: '仅草稿·自导入；禁止冒充正式精确谱',
      icon: Icons.piano_outlined,
      available: true,
      statusLabel: '草稿可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importAudio,
      title: '导入音频',
      subtitle: '本地 Basic Pitch ONNX 转录→草稿→自动进练习（短片段秒级；非正式谱）',
      icon: Icons.audio_file_outlined,
      available: true,
      statusLabel: '草稿可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importOther,
      title: '其它格式',
      subtitle: 'MXL 请走「导入 MusicXML」；其余格式筹备中',
      icon: Icons.folder_zip_outlined,
      available: false,
    ),
  ];

  static WorkshopTool? byId(WorkshopToolId id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
