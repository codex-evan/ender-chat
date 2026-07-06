/// Room waiting screen - shows room code and invite link for partner to join

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';
import '../../main/app_theme.dart';
import '../../main/app_locator.dart';
import '../../models/message.dart';
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
  bool _partnerJoined = false;

  @override
  void initState() {
    super.initState();
    _subscribeToService();
  }

  void _subscribeToService() {
    final ws = AppLocator.wsService;
    ws.onPartnerJoined = (roomCode) {
      if (!mounted) return;
      setState(() => _partnerJoined = true);
      // Navigate to chat when partner joins
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Nav.push(context, ChatScreen(
            roomCode: widget.roomCode,
            roomSecret: widget.roomSecret,
          ));
        }
      });
    };
  }

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
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            _partnerJoined ? Icons.check_circle : Icons.person_add_outlined,
                            size: 48,
                            color: _partnerJoined ? Colors.green : AppTheme.primaryColor,
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
                        _partnerJoined ? l10n.partnerJoined : l10n.waitingForPartner,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      _ShareCard(
                        context: context,
                        icon: Icons.pin_outlined,
                        title: l10n.roomCode,
                        value: widget.roomCode,
                        color: AppTheme.primaryColor,
                        onCopy: () => _copyToClipboard(l10n, widget.roomCode, (copied) {
                          setState(() => _copiedCode = copied);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copiedCode = false);
                          });
                        }),
                        copied: _copiedCode,
                      ),
                      const SizedBox(height: 16),

                      _ShareCard(
                        context: context,
                        icon: Icons.link_outlined,
                        title: l10n.inviteLink,
                        value: 'encchat://join/${widget.roomSecret}',
                        color: AppTheme.secondaryColor,
                        onCopy: () => _copyToClipboard(l10n, 'encchat://join/${widget.roomSecret}', (copied) {
                          setState(() => _copiedLink = copied);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copiedLink = false);
                          });
                        }),
                        copied: _copiedLink,
                      ),

                      const SizedBox(height: 32),

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
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(AppLocalizations l10n, String text, Function(bool) onCopied) {
    Clipboard.setData(ClipboardData(text: text));
    onCopied(true);
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
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onCopy,
            icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
            label: Text(copied ? 'Copied!' : 'Copy'),
            style: FilledButton.styleFrom(
              backgroundColor: color.withOpacity(0.1),
              foregroundColor: color,
            ),
          ),
        ],
      ),
    );
  }
}
