import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import './thumbnail_image.dart';

/// A reusable card widget for displaying file entries
class FileItemCard extends StatefulWidget {
  /// The file entry to display
  final FileEntry file;
  
  /// Whether the file is selected
  final bool isSelected;
  
  /// Whether to show a checkbox for selection
  final bool showCheckbox;
  
  /// Whether the provider supports thumbnails
  final bool providerSupportsThumbnails;
  
  /// Callback when the file is tapped
  final VoidCallback? onTap;
  
  /// Callback when the checkbox is changed
  final ValueChanged<bool?>? onCheckboxChanged;

  const FileItemCard({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.providerSupportsThumbnails = true,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  State<FileItemCard> createState() => _FileItemCardState();
}

class _FileItemCardState extends State<FileItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getBackgroundColor(theme),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCheckbox) ...[
                Checkbox(
                  value: widget.isSelected,
                  onChanged: widget.onCheckboxChanged,
                ),
                const SizedBox(width: 8),
              ],
              _buildFileIcon(theme),
            ],
          ),
          title: Text(
            widget.file.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildSubtitle(),
          onTap: widget.onTap,
          selected: widget.isSelected,
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (widget.isSelected) {
      return theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
    } else if (_isHovered) {
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      return Colors.transparent;
    }
  }

  Widget _buildFileIcon(ThemeData theme) {
    // Use thumbnail if available and provider supports thumbnails, otherwise fall back to icon
    return FileThumbnail(
      thumbnailUrl: widget.file.thumbnailUrl,
      hasThumbnail: widget.file.hasThumbnail && widget.providerSupportsThumbnails,
      mimeType: widget.file.mimeType,
      isFolder: widget.file.isFolder,
    );
  }

  Widget? _buildSubtitle() {
    final lines = <String>[];
    
    // Primeira linha: tamanho, tipo de arquivo ou "Pasta"
    final firstLineParts = <String>[];
    
    if (widget.file.isFolder) {
      firstLineParts.add('Pasta');
    } else {
      // Adicionar tamanho do arquivo
      if (widget.file.size != null) {
        firstLineParts.add('${(widget.file.size! / 1024 / 1024).toStringAsFixed(1)} MB');
      }
      
      // Adicionar tipo de arquivo baseado no MIME type
      final fileTypeDescription = _getFileTypeDescription();
      if (fileTypeDescription != null) {
        firstLineParts.add(fileTypeDescription);
      }
    }
    
    if (firstLineParts.isNotEmpty) {
      lines.add(firstLineParts.join(' • '));
    }
    
    // Segunda linha: informações de data
    final dateParts = <String>[];
    if (widget.file.createdAt != null) {
      dateParts.add('Criado: ${_formatDate(widget.file.createdAt!)}');
    }
    if (widget.file.modifiedAt != null) {
      dateParts.add('Modificado: ${_formatDate(widget.file.modifiedAt!)}');
    }
    
    if (dateParts.isNotEmpty) {
      lines.add(dateParts.join(' • '));
    }
    
    return lines.isNotEmpty
        ? Text(
            lines.join('\n'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.2),
          )
        : null;
  }

  /// Retorna uma descrição amigável do tipo de arquivo baseada no MIME type
  String? _getFileTypeDescription() {
    final mimeType = widget.file.mimeType;
    if (mimeType == null || mimeType.isEmpty) return null;
    
    // Verificar se o arquivo tem uma extensão clara no nome
    final fileName = widget.file.name.toLowerCase();
    final hasCommonExtension = RegExp(r'\.(jpg|jpeg|png|gif|bmp|svg|pdf|doc|docx|xls|xlsx|ppt|pptx|txt|csv|zip|rar|mp4|mp3|wav|avi)$').hasMatch(fileName);
    
    // Se tem extensão comum e reconhecível, não precisamos mostrar tipo MIME
    if (hasCommonExtension) return null;
    
    // Mapear MIME types comuns para descrições amigáveis
    final mimeTypeDescriptions = {
      // Documentos
      'application/pdf': 'PDF',
      'application/msword': 'Word',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'Word',
      'application/vnd.ms-excel': 'Excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'Excel',
      'application/vnd.ms-powerpoint': 'PowerPoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'PowerPoint',
      'text/plain': 'Texto',
      'text/csv': 'CSV',
      'application/json': 'JSON',
      'application/xml': 'XML',
      'text/html': 'HTML',
      'text/css': 'CSS',
      'application/javascript': 'JavaScript',
      
      // Imagens
      'image/jpeg': 'Imagem JPEG',
      'image/png': 'Imagem PNG',
      'image/gif': 'Imagem GIF',
      'image/bmp': 'Imagem BMP',
      'image/svg+xml': 'Imagem SVG',
      'image/webp': 'Imagem WebP',
      'image/tiff': 'Imagem TIFF',
      
      // Áudio
      'audio/mpeg': 'Áudio MP3',
      'audio/wav': 'Áudio WAV',
      'audio/ogg': 'Áudio OGG',
      'audio/aac': 'Áudio AAC',
      
      // Vídeo
      'video/mp4': 'Vídeo MP4',
      'video/avi': 'Vídeo AVI',
      'video/mov': 'Vídeo MOV',
      'video/webm': 'Vídeo WebM',
      'video/mkv': 'Vídeo MKV',
      
      // Arquivos compactados
      'application/zip': 'Arquivo ZIP',
      'application/x-rar-compressed': 'Arquivo RAR',
      'application/x-tar': 'Arquivo TAR',
      'application/gzip': 'Arquivo GZIP',
      
      // Google Apps
      'application/vnd.google-apps.document': 'Documento Google',
      'application/vnd.google-apps.spreadsheet': 'Planilha Google',
      'application/vnd.google-apps.presentation': 'Apresentação Google',
      'application/vnd.google-apps.form': 'Formulário Google',
      'application/vnd.google-apps.drawing': 'Desenho Google',
      'application/vnd.google-apps.folder': 'Pasta Google',
      
      // Outros
      'application/octet-stream': 'Arquivo binário',
      'application/x-executable': 'Executável',
      'application/x-deb': 'Pacote DEB',
      'application/x-rpm': 'Pacote RPM',
    };
    
    // Tentar encontrar descrição específica
    String? description = mimeTypeDescriptions[mimeType];
    
    if (description != null) {
      return description;
    }
    
    // Se não encontrou descrição específica, usar categorias gerais
    if (mimeType.startsWith('image/')) {
      return 'Imagem';
    } else if (mimeType.startsWith('audio/')) {
      return 'Áudio';
    } else if (mimeType.startsWith('video/')) {
      return 'Vídeo';
    } else if (mimeType.startsWith('text/')) {
      return 'Texto';
    } else if (mimeType.startsWith('application/')) {
      return 'Aplicativo';
    }
    
    // Como último recurso, mostrar o MIME type simplificado
    final parts = mimeType.split('/');
    if (parts.length >= 2) {
      return parts[1].toUpperCase();
    }
    
    return null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      // Today
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'hoje às $hour:$minute';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'ontem';
    } else if (difference.inDays < 7) {
      // This week
      final weekdays = [
        'domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'
      ];
      return weekdays[date.weekday % 7];
    } else if (difference.inDays < 365) {
      // This year
      final months = [
        'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
        'jul', 'ago', 'set', 'out', 'nov', 'dez'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } else {
      // Previous years
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}