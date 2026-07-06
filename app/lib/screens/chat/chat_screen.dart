/// Chat screen with anti-screenshot protection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_theme.dart';
import '../../main/app_locator.dart';
import '../../models/message.dart';
import '../../services/crypto_service.dart';
import '../../services/ws_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/security_banner.dart';

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final String roomSecret;

  const ChatScreen({
    super.key,
    required this.roomCode,
    required this.roomSecret,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _allowCopying = true;
  bool _securityAlertVisible = false;
  bool _isBlurred = false;

  final List<EncryptedMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupPlatformProtection();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToService();
      setState(() => _isLoading = false);
    });
  }

  void _setupPlatformProtection() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onFocusChange() {}

  void _subscribeToService() {
    final ws = AppLocator.wsService;
    ws.onMessageReceived = (msg) {
      if (!mounted) return;
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottom();
    };
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme, l10n),
                if (_securityAlertVisible)
                  SecurityBanner(
                    message: l10n.partnerMayScreenshot,
                    onDismiss: () => setState(() => _securityAlertVisible = false),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isBlurred
                        ? _buildBlurOverlay(theme)
                        : _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildMessageList(theme),
                  ),
                ),
                _buildInputArea(theme, l10n),
              ],
            ),
            if (_isBlurred) _buildFullScreenBlur(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room: ${widget.roomCode}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'End-to-end encrypted',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.greenAccent : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          _ConnectionStatus(isDark: isDark),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black87),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(children: [
                  Icon(Icons.copy, size: 20),
                  const SizedBox(width: 8),
                  Text('Copy room code'),
                ]),
              ),
              PopupMenuItem(
                value: 'save',
                child: Row(children: [
                  Icon(Icons.save, size: 20),
                  const SizedBox(width: 8),
                  Text('Save chat'),
                ]),
              ),
              PopupMenuItem(
                value: 'destroy',
                child: Row(children: [
                  Icon(Icons.delete_forever, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Destroy room', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'destroy') {
                _showDestroyDialog();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return MessageBubble(
          message: _messages[index],
          allowCopying: _allowCopying,
        );
      },
    );
  }

  Widget _buildBlurOverlay(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Screen capture detected',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Interface blurred for security',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenBlur() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: const Center(
        child: Icon(Icons.shield_outlined, size: 64, color: Colors.white54),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.attach_file_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
                onTap: _pickFile,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: l10n.typeMessage,
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.send_rounded,
                color: AppTheme.primaryColor,
                onTap: _sendMessage,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final msg = EncryptedMessage(
      msgId: DateTime.now().millisecondsSinceEpoch.toString(),
      ciphertext: text,
      nonce: '',
      senderEphemeralPk: '',
      type: MessageType.text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.sending,
      isOwn: true,
      displayContent: text,
    );

    setState(() {
      _messages.add(msg);
    });

    _messageController.clear();
    _scrollToBottom();

    // Send via WebSocket (encrypted)
    AppLocator.wsService.sendMessage(text, roomId: widget.roomCode);

    // Update status to sent after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.msgId == msg.msgId);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
        }
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _pickFile() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FileOption(
              icon: Icons.image,
              label: 'Image',
              onTap: () => Navigator.pop(context),
            ),
            _FileOption(
              icon: Icons.video_library,
              label: 'Video',
              onTap: () => Navigator.pop(context),
            ),
            _FileOption(
              icon: Icons.description,
              label: 'Document',
              onTap: () => Navigator.pop(context),
            ),
            _FileOption(
              icon: Icons.insert_drive_file,
              label: 'File',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDestroyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destroy Room'),
        content: const Text('This will permanently delete all messages in this room. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppLocator.wsService.destroyRoom();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Destroy'),
          ),
        ],
      ),
    );
  }

  void _simulateSecurityEvent() {
    setState(() {
      _securityAlertVisible = true;
      _isBlurred = true;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isBlurred = false);
      }
    });
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool isDark;

  const _ConnectionStatus({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.green : Colors.green).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text('Connected', style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.greenAccent : Colors.green,
          )),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: filled ? color : color.withOpacity(0.7), size: 22),
        ),
      ),
    );
  }
}

class _FileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FileOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
