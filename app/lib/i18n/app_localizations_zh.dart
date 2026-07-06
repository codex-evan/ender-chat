import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  
  @override
  Future<AppLocalizations> load(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return SynchronousFuture<AppLocalizations>(_AppLocalizationsZh());
      case 'en':
      default:
        return SynchronousFuture<AppLocalizations>(AppLocalizations());
    }
  }
  
  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);
  
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class _AppLocalizationsZh extends AppLocalizations {
  @override
  String get appName => '加密聊天';
  @override
  String get rooms => '聊天室';
  @override
  String get settings => '设置';
  @override
  String get privacy => '隐私';
  @override
  String get splashTitle => '加密聊天';
  @override
  String get splashSubtitle => '匿名端到端加密聊天';
  @override
  String get createRoom => '创建房间';
  @override
  String get joinRoom => '加入房间';
  @override
  String get enterRoomCode => '输入房间号';
  @override
  String get enterRoomCodeHint => '输入8位房间号码';
  @override
  String get joinViaLink => '通过邀请链接加入';
  @override
  String get joinViaLinkHint => '粘贴 encchat:// 邀请链接';
  @override
  String get create => '创建';
  @override
  String get join => '加入';
  @override
  String get cancel => '取消';
  @override
  String get waitingTitle => '等待对方加入';
  @override
  String get waitingSubtitle => '分享房间号或邀请链接给对方';
  @override
  String get roomCode => '房间号';
  @override
  String get inviteLink => '邀请链接';
  @override
  String get copyRoomCode => '复制房间号';
  @override
  String get copyInviteLink => '复制邀请链接';
  @override
  String get copied => '已复制！';
  @override
  String get partnerJoined => '对方已加入房间';
  @override
  String get waitingForPartner => '等待对方加入...';
  @override
  String get typeMessage => '输入消息...';
  @override
  String get send => '发送';
  @override
  String get connecting => '连接中...';
  @override
  String get connected => '已连接';
  @override
  String get disconnected => '已断开';
  @override
  String get reconnecting => '重连中...';
  @override
  String get online => '在线';
  @override
  String get offline => '离线';
  @override
  String get sending => '发送中...';
  @override
  String get sent => '已发送';
  @override
  String get delivered => '已送达';
  @override
  String get failed => '发送失败';
  @override
  String get read => '已读';
  @override
  String get today => '今天';
  @override
  String get yesterday => '昨天';
  @override
  String get fileTooLarge => '文件过大';
  @override
  String get maxFileSize => '最大文件大小: ';
  @override
  String get copyingNotAllowed => '此聊天不允许复制消息';
  @override
  String get systemMessageBothLeft => '双方已离开房间';
  @override
  String get systemMessageRoomDestroyed => '房间已销毁';
  @override
  String get securityWarning => '安全警告';
  @override
  String get screenshotDetected => '检测到可能的截屏';
  @override
  String get screenRecordingDetected => '检测到屏幕录制';
  @override
  String get partnerMayScreenshot => '对方可能已截屏';
  @override
  String get partnerRecording => '对方可能正在录屏';
  @override
  String get tapToDismiss => '点击关闭';
  @override
  String get securityAlert => '安全警报';
  @override
  String get blurActive => '因检测到屏幕捕获，界面已模糊';
  @override
  String get saveChatTitle => '保存聊天记录？';
  @override
  String get saveChatSubtitle => '聊天记录将加密保存在本机。服务器上的消息将被删除。';
  @override
  String get saveNow => '现在保存';
  @override
  String get notNow => '稍后再说';
  @override
  String get never => '永不';
  @override
  String get setupPassphrase => '设置恢复密语';
  @override
  String get setupPassphraseDesc => '设置恢复密语以加密本地聊天记录。如果忘记，保存的聊天记录无法恢复。';
  @override
  String get enterPassphrase => '输入恢复密语';
  @override
  String get enterPassphraseDesc => '输入恢复密语以解锁保存的聊天记录。';
  @override
  String get passphrase => '恢复密语';
  @override
  String get passphraseHint => '输入您的恢复密语';
  @override
  String get passphraseConfirm => '确认恢复密语';
  @override
  String get unlock => '解锁';
  @override
  String get incorrectPassphrase => '恢复密语不正确';
  @override
  String get passphraseWarning => '您保存的聊天记录已用此密语加密。如果忘记，无法恢复。';
  @override
  String get localRecords => '保存的聊天';
  @override
  String get noLocalRecords => '暂无保存的聊天记录';
  @override
  String get localRecordsDesc => '您选择保存的聊天记录将显示在这里';
  @override
  String get deleteRecord => '删除';
  @override
  String get deleteRecordConfirm => '确定永久删除此保存的聊天记录？';
  @override
  String get tapToUnlock => '点击解锁';
  @override
  String get appearance => '外观';
  @override
  String get darkMode => '深色模式';
  @override
  String get lightMode => '浅色模式';
  @override
  String get systemTheme => '跟随系统';
  @override
  String get language => '语言';
  @override
  String get english => 'English';
  @override
  String get chinese => '中文';
  @override
  String get localStorage => '本地存储';
  @override
  String get manageSavedChats => '管理保存的聊天';
  @override
  String get clearCache => '清除缓存';
  @override
  String get clearCacheConfirm => '确定清除所有缓存数据？此操作不可撤销。';
  @override
  String get about => '关于';
  @override
  String get version => '版本';
  @override
  String get privacyPolicy => '隐私政策';
  @override
  String get securitySettings => '安全设置';
  @override
  String get allowCopying => '允许复制消息';
  @override
  String get maxUploadSize => '最大上传大小';
  @override
  String get antiScreenshot => '防截屏保护';
  @override
  String get privacyTitle => '隐私与安全';
  @override
  String get privacyIntro1 => '本应用无需注册。';
  @override
  String get privacyIntro2 => '不收集手机号、邮箱、真实姓名。';
  @override
  String get privacyIntro3 => '服务器无法查看聊天内容。';
  @override
  String get privacyIntro4 => '消息和文件在发送前已加密。';
  @override
  String get privacyIntro5 => '服务器仅保存密文，最多7天。';
  @override
  String get privacyIntro6 => '双方退出且未保存时，消息将被删除。';
  @override
  String get privacyIntro7 => '如选择本地保存，数据仅存于本机。';
  @override
  String get privacyIntro8 => '忘记恢复密语后，保存的数据无法恢复。';
  @override
  String get image => '图片';
  @override
  String get video => '视频';
  @override
  String get document => '文档';
  @override
  String get file => '文件';
  @override
  String get audio => '音频';
  @override
  String get voiceMessage => '语音消息';
  @override
  String get pickFile => '选择文件';
  @override
  String get pickImage => '选择图片';
  @override
  String get pickVideo => '选择视频';
  @override
  String get download => '下载';
  @override
  String get uploading => '上传中...';
  @override
  String get downloading => '下载中...';
  @override
  String get uploadProgress => '上传: ';
  @override
  String get downloadProgress => '下载: ';
  @override
  String get errorRoomNotFound => '房间不存在或已过期';
  @override
  String get errorRoomFull => '房间已满';
  @override
  String get errorConnectionFailed => '连接失败';
  @override
  String get errorEncryptionFailed => '加密失败';
  @override
  String get errorDecryptionFailed => '解密失败';
  @override
  String get errorFileTooLarge => '文件超出大小限制';
  @override
  String get errorUnknown => '发生未知错误';
}
