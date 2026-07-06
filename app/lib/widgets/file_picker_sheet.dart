/// File attachment picker with encryption progress

import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../main/app_theme.dart';

class FilePickerSheet extends StatelessWidget {
  final Function(String type, String path) onSelect;
  
  const FilePickerSheet({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              l10n.pickFile,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          _FileOption(
            context: context,
            icon: Icons.image,
            label: l10n.image,
            color: AppTheme.secondaryColor,
            onTap: () => onSelect('image', ''),
          ),
          _FileOption(
            context: context,
            icon: Icons.videocam,
            label: l10n.video,
            color: AppTheme.accentColor,
            onTap: () => onSelect('video', ''),
          ),
          _FileOption(
            context: context,
            icon: Icons.description,
            label: l10n.document,
            color: AppTheme.primaryColor,
            onTap: () => onSelect('document', ''),
          ),
          _FileOption(
            context: context,
            icon: Icons.attach_file,
            label: l10n.file,
            color: Colors.grey,
            onTap: () => onSelect('file', ''),
          ),
          
          const Divider(height: 1),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

class _FileOption extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _FileOption({
    required this.context,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// File upload progress indicator widget
class UploadProgressWidget extends StatelessWidget {
  final double progress;   // 0.0 to 1.0
  final String fileName;
  final bool isUploading;
  
  const UploadProgressWidget({
    super.key,
    required this.progress,
    required this.fileName,
    required this.isUploading,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUploading ? Icons.upload_file : Icons.download,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isUploading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
