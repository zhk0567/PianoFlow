import 'package:flutter/material.dart';

/// Home + workshop catalog of score authoring / import tools.
enum WorkshopToolId {
  pdfToScore,
  editScore,
  importMusicXml,
  importMidi,
  importOther,
}

class WorkshopTool {
  const WorkshopTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.available = false,
  });

  final WorkshopToolId id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// False → UI shows「筹备中」; route still opens the tool detail.
  final bool available;

  static const List<WorkshopTool> all = [
    WorkshopTool(
      id: WorkshopToolId.pdfToScore,
      title: 'PDF 转曲谱',
      subtitle: '扫描谱 / PDF → OMR → 校对后入库',
      icon: Icons.picture_as_pdf_outlined,
    ),
    WorkshopTool(
      id: WorkshopToolId.editScore,
      title: '编辑曲谱',
      subtitle: '修正音高、时值与指法标注',
      icon: Icons.edit_note_outlined,
    ),
    WorkshopTool(
      id: WorkshopToolId.importMusicXml,
      title: '导入 MusicXML',
      subtitle: '选本地 MusicXML/MXL → 自导入曲库（非正式谱）',
      icon: Icons.code_outlined,
      available: true,
    ),
    WorkshopTool(
      id: WorkshopToolId.importMidi,
      title: '导入 MIDI',
      subtitle: '仅作草稿参考，不可标为正式谱',
      icon: Icons.piano_outlined,
    ),
    WorkshopTool(
      id: WorkshopToolId.importOther,
      title: '其他格式',
      subtitle: 'MXL、MusicXML.zip 等后续支持',
      icon: Icons.folder_open_outlined,
    ),
  ];

  static WorkshopTool? byId(WorkshopToolId id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static WorkshopToolId? parseId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in WorkshopToolId.values) {
      if (id.name == raw) return id;
    }
    return null;
  }
}
