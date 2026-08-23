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
      subtitle: '一键：暂存 → 本机 OMR → 导入 → 练习（可跟弹；质量档为自导入/OMR）',
      icon: Icons.picture_as_pdf_outlined,
      available: true,
      statusLabel: '可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importMusicXml,
      title: '导入 MusicXML',
      subtitle: '本机 .musicxml / .xml / .mxl → 曲库可练（自导入质量档）',
      icon: Icons.upload_file_rounded,
      available: true,
      statusLabel: '可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.editScore,
      title: '编辑曲谱',
      subtitle: '自导入：元数据 + 音符表；外部 MusicXML；删除；打开练习',
      icon: Icons.edit_note_rounded,
      available: true,
      statusLabel: '可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importMidi,
      title: '导入 MIDI',
      subtitle: 'MIDI → 可跟弹谱入库；作节奏/音高参考（非教材级精确谱）',
      icon: Icons.piano_outlined,
      available: true,
      statusLabel: '可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importAudio,
      title: '导入音频',
      subtitle: '可选 Demucs → Basic Pitch → 入库并进练习（短片段；可跟弹）',
      icon: Icons.audio_file_outlined,
      available: true,
      statusLabel: '可用',
    ),
    WorkshopTool(
      id: WorkshopToolId.importOther,
      title: '其它格式',
      subtitle: 'MXL 请用「导入 MusicXML」；其余格式后续扩展',
      icon: Icons.folder_zip_outlined,
      available: true,
      statusLabel: '指引',
    ),
  ];

  static WorkshopTool? byId(WorkshopToolId id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
