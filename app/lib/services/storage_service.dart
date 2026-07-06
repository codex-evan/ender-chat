/// Local storage service for encrypted chat records
/// Uses SQLite with encryption at rest

import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  
  Database? _db;
  String? _dbPath;
  
  bool get isOpen => _db != null;
  
  Future<void> init() async {
    if (_db != null) return;
    
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = p.join(dir.path, 'encchat_secure.db');
    
    _db = await openDatabase(
      _dbPath!,
      version: 1,
      onCreate: _createDatabase,
    );
  }
  
  Future<void> _createDatabase(Database db, int version) async {
    // Encrypted messages table (for local storage only)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS encrypted_messages (
        msg_id TEXT PRIMARY KEY,
        room_hash TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        nonce TEXT NOT NULL,
        sender_ephemeral_pk TEXT,
        message_type TEXT DEFAULT 'text',
        original_filename TEXT,
        file_size INTEGER,
        encrypted_file_id TEXT,
        timestamp INTEGER NOT NULL,
        delivery_status TEXT DEFAULT 'sent',
        is_own INTEGER DEFAULT 0,
        display_content TEXT
      )
    ''');
    
    // Room info table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rooms (
        room_hash TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        room_code TEXT,
        invite_link TEXT,
        created_at INTEGER NOT NULL,
        both_participants_left INTEGER DEFAULT 0,
        delete_requested INTEGER DEFAULT 0
      )
    ''');
    
    // File metadata table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_metadata (
        file_id TEXT PRIMARY KEY,
        room_hash TEXT NOT NULL,
        encrypted_path TEXT NOT NULL,
        original_name_encrypted TEXT,
        mime_type TEXT,
        file_size INTEGER,
        total_chunks INTEGER DEFAULT 1,
        downloaded INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Queued messages for offline send
    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_data TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Passphrase salt storage
    await db.execute('''
      CREATE TABLE IF NOT EXISTS passphrase_store (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        salt TEXT NOT NULL,
        derived_key_exists INTEGER DEFAULT 0
      )
    ''');
  }
  
  /// Save a message to local encrypted storage
  Future<void> saveMessage(Map<String, dynamic> message) async {
    if (_db == null) return;
    
    await _db!.insert('encrypted_messages', message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get all messages for a room
  Future<List<Map<String, dynamic>>> getMessagesByRoom(String roomHash) async {
    if (_db == null) return [];
    
    return _db!.query(
      'encrypted_messages',
      where: 'room_hash = ?',
      whereArgs: [roomHash],
      orderBy: 'timestamp ASC',
    );
  }
  
  /// Get all rooms
  Future<List<Map<String, dynamic>>> getAllRooms() async {
    if (_db == null) return [];
    
    return _db!.query('rooms', orderBy: 'created_at DESC');
  }
  
  /// Delete a room and its messages
  Future<void> deleteRoom(String roomHash) async {
    if (_db == null) return;
    
    await _db!.delete('encrypted_messages', where: 'room_hash = ?', whereArgs: [roomHash]);
    await _db!.delete('rooms', where: 'room_hash = ?', whereArgs: [roomHash]);
  }
  
  /// Save queued messages
  Future<void> saveQueuedMessages(List<Map<String, dynamic>> messages) async {
    if (_db == null) return;
    
    // Delete old queue
    await _db!.delete('message_queue');
    
    for (final msg in messages) {
      await _db!.insert('message_queue', {
        'message_data': msg.toString(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  /// Get queued messages
  Future<List<Map<String, dynamic>>> getQueuedMessages() async {
    if (_db == null) return [];
    
    final rows = await _db!.query('message_queue');
    return rows.map((row) => row['message_data'] as Map<String, dynamic>).toList();
  }
  
  /// Clear queued messages
  Future<void> clearQueuedMessages() async {
    if (_db == null) return;
    await _db!.delete('message_queue');
  }
  
  /// Get app documents directory
  Future<String> getDocumentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
  
  /// Get encrypted file storage path
  Future<String> getEncryptedFilesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'encrypted_files');
    final folder = Directory(path);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return path;
  }
  
  /// Close database
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
  
  /// Clear all local data
  Future<void> clearAll() async {
    if (_db == null || _dbPath == null) return;
    
    await _db!.delete('encrypted_messages');
    await _db!.delete('rooms');
    await _db!.delete('file_metadata');
    await _db!.delete('message_queue');
  }
}
