/// Room waiting screen - shows room code and invite link for partner to join

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';
import '../chat/chat_screen.dart';

class RoomWaitingScreen extends StatefulWidget {
  final String roomCode;
  final String roomSecret;
  
  const RoomWaitingScreen({
    super.key,
    required this.roomCode,
    required this.roomSecret,
  });

  @override
  State<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends State<RoomWaitingScreen> {
  bool _copiedCode = false;
  bool _copiedLink = false;
  int _partnerCount = 0;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => Nav.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status indicator
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme._primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_add_outlined,
                            size: 48,
                            color: AppTheme._primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        l10n.waitingTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.waitingForPartner,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Room code card
                      _ShareCard(
                        context: context,
                        icon: Icons.pin_outlined,
                        title: l10n.roomCode,
                        value: widget.roomCode,
                        color: AppTheme._primaryColor,
                        onCopy: () => _copyToClipboard(l10n, widget.roomCode, (copied) {
                          setState(() => _copiedCode = copied);
                          Future.delayed(const Duration(seconds: 2), () {
                            setState(() => _copiedCode = false);
                          });
                        }),
                        copied: _copiedCode,
                      ),
                      const SizedBox(height: 16),
                      
                      // Invite link card
                      _ShareCard(
                        context: context,
                        icon: Icons.link_outlined,
                        title: l10n.inviteLink,
                        value: 'encchat://join/${widget.roomSecret}',
                        color: AppTheme._secondaryColor,
                        onCopy: () => _copyToClipboard(l10n, 'encchat://join/${widget.roomSecret}', (copied) {
                          setState(() => _copiedLink = copied);
                          Future.delayed(const Duration(seconds: 2), () {
                            setState(() => _copiedLink = false);
                          });
                        }),
                        copied: _copiedLink,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to join:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Share the room code or invite link with the person you want to chat with.\n\n'
                              '2. They enter the code or tap the link to join.\n\n'
                              '3. Once both are in the room, encrypted chatting begins.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Auto-advance button (demo)
              TextButton(
                onPressed: () {
                  // In production, this would wait for partner via WebSocket
                  Nav.push(context, const ChatScreen(
                    roomCode: 'DEMO',
                    roomSecret: widget.roomSecret,
                  ));
                },
                child: Text('Demo: Skip to chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _copyToClipboard(AppLocalizations l10n, String text, Function(bool) onCopied) {
    Clipboard.setData(ClipboardData(text: text));
    onCopied(true);
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.copied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onCopy;
  final bool copied;
  
  const _ShareCard({
    required this.context,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onCopy,
    required this.copied,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 4,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCopy,
            icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
            label: Text(copied ? 'Copied!' : 'Copy'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
