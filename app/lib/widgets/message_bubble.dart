/// Message bubble widget

import 'package:flutter/material.dart';
import '../main/app_theme.dart';
import '../models/message.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final EncryptedMessage message;
  final bool allowCopying;
  
  const MessageBubble({
    super.key,
    required this.message,
    this.allowCopying = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwn = message.isOwn;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            _Avatar(isDark: isDark),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: isOwn
                    ? AppTheme._primaryColor
                    : (isDark ? const Color(0xFF252525) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwn ? 16 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: _buildContent(theme, isDark),
                  ),
                  
                  // Status and time
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 6, left: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        _StatusIcon(status: message.status, isOwn: isOwn),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(message.timestamp, theme),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOwn
                                ? Colors.white70
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            _Avatar(isOwn: true, isDark: isDark),
          ],
        ],
      ),
    );
  }
  
  Widget _buildContent(ThemeData theme, bool isDark) {
    switch (message.type) {
      case MessageType.text:
        return SelectableText(
          message.displayContent ?? '🔒 Encrypted message',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: message.isOwn ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
          selectionControls: allowCopying ? null : null,
        );
        
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.image, size: 40)),
            ),
            const SizedBox(height: 4),
            if (message.displayContent != null && message.displayContent!.isNotEmpty)
              SelectableText(
                message.displayContent!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: message.isOwn ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
          ],
        );
        
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 140,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.play_circle_filled, size: 36)),
            ),
          ],
        );
        
      case MessageType.document:
      case MessageType.file:
        return _FileAttachment(theme, isDark);
        
      case MessageType.system:
      case MessageType.security_event:
        return Text(
          message.displayContent ?? 'System message',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white38 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        );
        
      case MessageType.voice:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack, size: 16, color: message.isOwn ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 8),
            Text('0:05', style: theme.textTheme.bodySmall),
          ],
        );
    }
  }
  
  String _formatTime(int timestamp, ThemeData theme) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat.Hm().format(date);
  }
}

class _Avatar extends StatelessWidget {
  final bool isOwn;
  final bool isDark;
  
  const _Avatar({this.isOwn = false, required this.isDark});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isOwn ? AppTheme._primaryColor.withOpacity(0.3) : AppTheme._secondaryColor.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isOwn ? Icons.person_rounded : Icons.face_rounded,
        size: 18,
        color: isOwn ? AppTheme._primaryColor : AppTheme._secondaryColor,
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final bool isOwn;
  
  const _StatusIcon({required this.status, required this.isOwn});
  
  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, size: 14, color: isOwn ? Colors.white70 : color);
  }
}

class _FileAttachment extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  
  const _FileAttachment(this.theme, this.isDark);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 20, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'document.pdf',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
