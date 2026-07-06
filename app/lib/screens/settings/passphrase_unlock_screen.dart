/// Passphrase unlock screen for accessing saved local records

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';
import '../../main/app_theme.dart';

class PassphraseUnlockScreen extends StatefulWidget {
  const PassphraseUnlockScreen({super.key});

  @override
  State<PassphraseUnlockScreen> createState() => _PassphraseUnlockScreenState();
}

class _PassphraseUnlockScreenState extends State<PassphraseUnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passphraseController = TextEditingController();
  bool _obscure = true;
  bool _unlocking = false;
  String? _error;
  
  @override
  void dispose() {
    _passphraseController.dispose();
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
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 24),
                  Text(
                    l10n.enterPassphrase,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.enterPassphraseDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _passphraseController,
                    obscureText: _obscure,
                    enabled: !_unlocking,
                    decoration: InputDecoration(
                      labelText: l10n.passphrase,
                      hintText: l10n.passphraseHint,
                      errorText: _error,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (_unlocking)
                    const CircularProgressIndicator()
                  else
                    FilledButton(
                      onPressed: _tryUnlock,
                      child: Text(l10n.unlock),
                    ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Nav.pop(context),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _tryUnlock() {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _unlocking = true;
        _error = null;
      });
      
      // Simulate decryption attempt
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _unlocking = false;
          if (_passphraseController.text.length < 4) {
            _error = l10n.incorrectPassphrase;
          } else {
            // Success - navigate back with passphrase
            Nav.pop(context, _passphraseController.text);
          }
        });
      });
    }
  }
}
