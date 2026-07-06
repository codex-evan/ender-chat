/// Internationalization support
/// All strings defined here for easy future expansion

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations_zh.dart';

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();
  
  // App
  String get appName => 'EncChat';
  String get rooms => 'Rooms';
  String get settings => 'Settings';
  String get privacy => 'Privacy';
  
  // Splash
  String get splashTitle => 'EncChat';
  String get splashSubtitle => 'Anonymous End-to-End Encrypted Chat';
  
  // Room Selection
  String get createRoom => 'Create Room';
  String get joinRoom => 'Join Room';
  String get enterRoomCode => 'Enter Room Code';
  String get enterRoomCodeHint => 'Enter the 8-character room code';
  String get joinViaLink => 'Join via Invite Link';
  String get joinViaLinkHint => 'Paste an encchat:// invite link';
  String get create => 'Create';
  String get join => 'Join';
  String get cancel => 'Cancel';
  
  // Waiting
  String get waitingTitle => 'Waiting for Partner';
  String get waitingSubtitle => 'Share the room code or invite link';
  String get roomCode => 'Room Code';
  String get inviteLink => 'Invite Link';
  String get copyRoomCode => 'Copy Room Code';
  String get copyInviteLink => 'Copy Invite Link';
  String get copied => 'Copied!';
  String get partnerJoined => 'Partner joined the room';
  String get waitingForPartner => 'Waiting for the other person to join...';
  
  // Chat
  String get typeMessage => 'Type a message...';
  String get send => 'Send';
  String get connecting => 'Connecting...';
  String get connected => 'Connected';
  String get disconnected => 'Disconnected';
  String get reconnecting => 'Reconnecting...';
  String get online => 'Online';
  String get offline => 'Offline';
  String get sending => 'Sending...';
  String get sent => 'Sent';
  String get delivered => 'Delivered';
  String get failed => 'Failed';
  String get read => 'Read';
  String get today => 'Today';
  String get yesterday => 'Yesterday';
  String get fileTooLarge => 'File too large';
  String get maxFileSize => 'Maximum file size: ';
  String get copyingNotAllowed => 'Copying is not allowed in this chat';
  String get systemMessageBothLeft => 'Both participants have left the room';
  String get systemMessageRoomDestroyed => 'Room has been destroyed';
  
  // Security
  String get securityWarning => 'Security Warning';
  String get screenshotDetected => 'Possible screenshot detected';
  String get screenRecordingDetected => 'Screen recording detected';
  String get partnerMayScreenshot => 'The other person may have taken a screenshot';
  String get partnerRecording => 'The other person may be recording the screen';
  String get tapToDismiss => 'Tap to dismiss';
  String get securityAlert => 'Security Alert';
  String get blurActive => 'Blur activated due to screen capture detection';
  
  // Save Prompt
  String get saveChatTitle => 'Save Chat History?';
  String get saveChatSubtitle => 'Chat history will be saved locally encrypted on this device only. Messages will be deleted from the server.';
  String get saveNow => 'Save Now';
  String get notNow => 'Not Now';
  String get never => 'Never';
  
  // Passphrase
  String get setupPassphrase => 'Set Up Recovery Phrase';
  String get setupPassphraseDesc => 'Set a recovery phrase to encrypt your local chat history. If you forget this, your saved chats cannot be recovered.';
  String get enterPassphrase => 'Enter Recovery Phrase';
  String get enterPassphraseDesc => 'Enter your recovery phrase to unlock saved chat history.';
  String get passphrase => 'Recovery Phrase';
  String get passphraseHint => 'Enter your recovery phrase';
  String get passphraseConfirm => 'Confirm Recovery Phrase';
  String get unlock => 'Unlock';
  String get incorrectPassphrase => 'Incorrect recovery phrase';
  String get passphraseWarning => 'Your saved chat history is encrypted with this phrase. If forgotten, it cannot be recovered.';
  
  // Local Records
  String get localRecords => 'Saved Chats';
  String get noLocalRecords => 'No saved chat history';
  String get localRecordsDesc => 'Chats you chose to save will appear here';
  String get deleteRecord => 'Delete';
  String get deleteRecordConfirm => 'Delete this saved chat permanently?';
  String get tapToUnlock => 'Tap to unlock';
  
  // Settings
  String get appearance => 'Appearance';
  String get darkMode => 'Dark Mode';
  String get lightMode => 'Light Mode';
  String get systemTheme => 'System';
  String get language => 'Language';
  String get english => 'English';
  String get chinese => '中文';
  String get localStorage => 'Local Storage';
  String get manageSavedChats => 'Manage Saved Chats';
  String get clearCache => 'Clear Cache';
  String get clearCacheConfirm => 'Clear all cached data? This cannot be undone.';
  String get about => 'About';
  String get version => 'Version';
  String get privacyPolicy => 'Privacy Policy';
  String get securitySettings => 'Security Settings';
  String get allowCopying => 'Allow Message Copying';
  String get maxUploadSize => 'Max Upload Size';
  String get antiScreenshot => 'Anti-Screenshot Protection';
  
  // Privacy
  String get privacyTitle => 'Privacy & Security';
  String get privacyIntro1 => 'This app does not require registration.';
  String get privacyIntro2 => 'We do not collect phone numbers, emails, or real names.';
  String get privacyIntro3 => 'The server cannot see your chat content.';
  String get privacyIntro4 => 'Messages and files are encrypted before sending.';
  String get privacyIntro5 => 'The server only stores ciphertext for a maximum of 7 days.';
  String get privacyIntro6 => 'If both parties leave without saving, messages will be deleted.';
  String get privacyIntro7 => 'If you choose local save, data is stored only on your device.';
  String get privacyIntro8 => 'If you forget your recovery phrase, saved data cannot be recovered.';
  
  // File types
  String get image => 'Image';
  String get video => 'Video';
  String get document => 'Document';
  String get file => 'File';
  String get audio => 'Audio';
  String get voiceMessage => 'Voice Message';
  
  // Actions
  String get pickFile => 'Pick File';
  String get pickImage => 'Pick Image';
  String get pickVideo => 'Pick Video';
  String get download => 'Download';
  String get uploading => 'Uploading...';
  String get downloading => 'Downloading...';
  String get uploadProgress => 'Upload: ';
  String get downloadProgress => 'Download: ';
  
  // Error messages
  String get errorRoomNotFound => 'Room not found or expired';
  String get errorRoomFull => 'Room is full';
  String get errorConnectionFailed => 'Connection failed';
  String get errorEncryptionFailed => 'Encryption failed';
  String get errorDecryptionFailed => 'Decryption failed';
  String get errorFileTooLarge => 'File exceeds size limit';
  String get errorUnknown => 'An unknown error occurred';
}
