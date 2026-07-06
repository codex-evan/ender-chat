/// Room join screen - enter room code or invite link

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';
import '../../main/app_locator.dart';
import 'room_waiting_screen.dart';

class RoomJoinScreen extends StatefulWidget {
  const RoomJoinScreen({super.key});

  @override
  State<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

class _RoomJoinScreenState extends State<RoomJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _linkController = TextEditingController();
  bool _showLinkInput = false;
  String _selectedTab = 'code';

  @override
  void dispose() {
    _codeController.dispose();
    _linkController.dispose();
    super.dispose();
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
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => Nav.pop(context),
        ),
        title: Text(
          l10n.joinRoom,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TabSelector(
                  selected: _selectedTab,
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
                const SizedBox(height: 24),

                if (_selectedTab == 'code') ...[
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: l10n.enterRoomCodeHint,
                      prefixIcon: Icon(Icons.pin_outlined, color: isDark ? Colors.white54 : Colors.black54),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.enterRoomCodeHint;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _onJoin,
                    child: Text(l10n.join),
                  ),
                ],

                if (_selectedTab == 'link') ...[
                  TextFormField(
                    controller: _linkController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.joinViaLinkHint,
                      prefixIcon: Icon(Icons.link_outlined, color: isDark ? Colors.white54 : Colors.black54),
                      hintText: 'encchat://join/',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.joinViaLinkHint;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _onJoinViaLink,
                    child: const Text('Join via Link'),
                  ),
                ],

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security_outlined, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only join rooms with people you trust. All messages are end-to-end encrypted.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onJoin() {
    if (_formKey.currentState!.validate()) {
      final roomCode = _codeController.text.toUpperCase();
      // Join room via WebSocket
      AppLocator.wsService.joinRoom(roomCode);

      Nav.push(context, RoomWaitingScreen(
        roomCode: roomCode,
        roomSecret: '',
      ));
    }
  }

  void _onJoinViaLink() {
    if (_formKey.currentState!.validate()) {
      final link = _linkController.text;
      String roomCode = '';
      String roomSecret = '';

      // Parse encchat://join/<secret>
      if (link.startsWith('encchat://join/')) {
        roomSecret = link.substring('encchat://join/'.length);
        roomCode = 'link';
      }

      Nav.push(context, RoomWaitingScreen(
        roomCode: roomCode,
        roomSecret: roomSecret,
      ));
    }
  }
}

class _TabSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TabSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: 'Room Code',
              icon: Icons.pin_outlined,
              isSelected: selected == 'code',
              onTap: () => onChanged('code'),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: 'Invite Link',
              icon: Icons.link_outlined,
              isSelected: selected == 'link',
              onTap: () => onChanged('link'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}
