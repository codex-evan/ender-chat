/**
 * Anonymous Encrypted Chat Server
 * 
 * This server ONLY processes ciphertext. It never sees:
 * - Plaintext messages
 * - Plaintext files
 * - Encryption keys
 * - Passphrases
 * - User identities
 * 
 * All data is stored temporarily with TTL and auto-deleted.
 */

import express from 'express';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { v4 as uuidv4 } from 'uuid';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ============================================================
// Configuration
// ============================================================

const PORT = parseInt(process.env.PORT || '3000', 10);
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE || '104857600', 10); // 100MB
const MAX_MESSAGE_SIZE = parseInt(process.env.MAX_MESSAGE_SIZE || '1048576', 10); // 1MB
const MESSAGE_TTL_MS = parseInt(process.env.MESSAGE_TTL_DAYS || '7', 10) * 24 * 60 * 60 * 1000;
const CLEANUP_INTERVAL_MS = parseInt(process.env.CLEANUP_INTERVAL_MINUTES || '60', 10) * 60 * 1000;
const RATE_LIMIT_WINDOW = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const RATE_LIMIT_MAX = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10);
const ROOM_JOIN_LIMIT = parseInt(process.env.ROOM_JOIN_RATE_LIMIT || '10', 10);
const UPLOAD_DIR = path.resolve(__dirname, process.env.UPLOAD_DIR || '../uploads');

// Ensure upload directory exists
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// ============================================================
// Minimal Logging (never logs sensitive data)
// ============================================================

const LOG_LEVEL = process.env.LOG_LEVEL || 'warn';

function log(level: string, message: string, meta?: Record<string, unknown>) {
  if (shouldLog(level)) {
    const safeMeta = meta ? sanitizeForLogging(meta) : {};
    console[level](`[${new Date().toISOString()}] [${level.toUpperCase()}] ${message}`, safeMeta);
  }
}

function shouldLog(level: string): boolean {
  const levels = ['error', 'warn', 'info', 'debug'];
  return levels.indexOf(level) <= levels.indexOf(LOG_LEVEL);
}

function sanitizeForLogging(obj: Record<string, unknown>): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};
  const sensitiveKeys = ['ciphertext', 'nonce', 'key', 'secret', 'passphrase', 'password', 'content', 'message'];
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();
    if (sensitiveKeys.some(sk => lowerKey.includes(sk))) {
      sanitized[key] = '[REDACTED]';
    } else {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

// ============================================================
// Rate Limiter
// ============================================================

interface RateLimitEntry {
  timestamps: number[];
}

const rateLimits = new Map<string, RateLimitEntry>();

function checkRateLimit(clientId: string, maxRequests: number): boolean {
  const now = Date.now();
  let entry = rateLimits.get(clientId);
  
  if (!entry) {
    entry = { timestamps: [] };
    rateLimits.set(clientId, entry);
  }
  
  // Remove old timestamps
  entry.timestamps = entry.timestamps.filter(t => now - t < RATE_LIMIT_WINDOW);
  
  if (entry.timestamps.length >= maxRequests) {
    return false;
  }
  
  entry.timestamps.push(now);
  return true;
}

// Clean up expired rate limit entries periodically
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimits.entries()) {
    entry.timestamps = entry.timestamps.filter(t => now - t < RATE_LIMIT_WINDOW);
    if (entry.timestamps.length === 0) {
      rateLimits.delete(key);
    }
  }
}, RATE_LIMIT_WINDOW);

// ============================================================
// Room & Connection State
// ============================================================

interface RoomParticipant {
  ws: WebSocket;
  id: string;
  joinedAt: number;
  clientId: string;
}

interface RoomState {
  roomId: string;
  participants: Map<string, RoomParticipant>;
  createdAt: number;
  bothLeft: boolean;
  deleteRequested: boolean;
  messageStore: Map<string, {
    msgId: string;
    roomHash: string;
    ciphertext: string;
    nonce: string;
    senderEphemeralId: string;
    type: string;
    timestamp: number;
    expiresAt: number;
    deliveryStatus: string;
    encryptedFileId?: string;
    fileSize?: number;
  }>;
  fileStore: Map<string, {
    fileId: string;
    roomHash: string;
    filePath: string;
    chunkIndex: number;
    totalChunks: number;
    createdAt: number;
    expiresAt: number;
  }>;
}

const rooms = new Map<string, RoomState>();
const clientRooms = new Map<string, string>(); // clientId -> roomId
const wsToRoom = new Map<WebSocket, string>(); // ws -> roomId
const wsToClientId = new Map<WebSocket, string>(); // ws -> clientId

// ============================================================
// Express + HTTP Setup
// ============================================================

const app = express();
const server = http.createServer(app);

// Middleware
app.use(helmet({
  contentSecurityPolicy: false, // We don't serve HTML
  crossOriginEmbedderPolicy: false,
}));
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') || '*' }));
app.use(compression());

// Health check (no sensitive data)
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    rooms_active: rooms.size,
    clients_connected: wsToClientId.size,
  });
});

// ============================================================
// WebSocket Server
// ============================================================

const wss = new WebSocketServer({ 
  server,
  path: '/ws',
  maxPayload: MAX_FILE_SIZE,
});

wss.on('connection', (ws, req) => {
  const clientId = uuidv4();
  wsToClientId.set(ws, clientId);
  
  log('info', `Client connected`, { clientId: clientId.substring(0, 8) + '...' });
  
  // Rate limit per client IP
  const clientIp = req.headers['x-forwarded-for']?.toString() || 
                   req.socket.remoteAddress || 'unknown';
  const ipKey = `${clientId}-${clientIp}`;
  
  if (!checkRateLimit(ipKey, RATE_LIMIT_MAX)) {
    log('warn', `Rate limit exceeded`, { clientId: clientId.substring(0, 8) + '...', ip: maskIp(clientIp) });
    ws.send(JSON.stringify({ type: 'error', message: 'Rate limit exceeded. Please try again later.' }));
    ws.close(4001, 'Rate limited');
    return;
  }
  
  // Send client their ID
  ws.send(JSON.stringify({ type: 'connected', client_id: clientId }));
  
  ws.on('message', (data) => {
    handleMessage(ws, clientId, data);
  });
  
  ws.on('close', (code, reason) => {
    handleDisconnect(ws, clientId);
  });
  
  ws.on('error', (err) => {
    log('error', `WebSocket error`, { clientId: clientId.substring(0, 8) + '...', error: err.message });
    handleDisconnect(ws, clientId);
  });
});

function maskIp(ip: string): string {
  if (ip.includes(':')) {
    return ip.split(':').slice(0, 3).join(':') + ':***';
  }
  return ip.split('.').slice(0, 3).join('.') + '.***';
}

// ============================================================
// Message Handler
// ============================================================

function handleMessage(ws: WebSocket, clientId: string, rawData: Buffer) {
  let parsed;
  try {
    const str = rawData.toString('utf-8');
    if (str.length > MAX_MESSAGE_SIZE) {
      ws.send(JSON.stringify({ type: 'error', message: 'Message too large' }));
      return;
    }
    parsed = JSON.parse(str);
  } catch {
    ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }));
    return;
  }
  
  const { type, ...payload } = parsed;
  
  switch (type) {
    case 'create_room':
      handleCreateRoom(ws, clientId, payload);
      break;
    case 'join_room':
      handleJoinRoom(ws, clientId, payload);
      break;
    case 'encrypted_message_send':
      handleEncryptedMessage(ws, clientId, payload);
      break;
    case 'encrypted_file_upload_request':
      handleFileUploadRequest(ws, clientId, payload);
      break;
    case 'encrypted_file_chunk':
      handleFileChunk(ws, clientId, payload);
      break;
    case 'encrypted_file_complete':
      handleFileComplete(ws, clientId, payload);
      break;
    case 'participant_left':
      handleParticipantLeft(ws, clientId);
      break;
    case 'room_destroy':
      handleRoomDestroy(ws, clientId);
      break;
    case 'screenshot_detected':
    case 'screen_recording_detected':
    case 'security_warning':
      handleSecurityEvent(ws, clientId, type, payload);
      break;
    case 'message_delivered':
      handleDeliveryReceipt(ws, clientId, payload);
      break;
    case 'message_read':
      handleReadReceipt(ws, clientId, payload);
      break;
    default:
      ws.send(JSON.stringify({ type: 'error', message: `Unknown event: ${type}` }));
  }
}

// ============================================================
// Room Handlers
// ============================================================

function handleCreateRoom(ws: WebSocket, clientId: string, _payload: unknown) {
  const roomId = uuidv4();
  const roomHash = sha256Hash(roomId).substring(0, 16);
  
  const roomState: RoomState = {
    roomId,
    participants: new Map(),
    createdAt: Date.now(),
    bothLeft: false,
    deleteRequested: false,
    messageStore: new Map(),
    fileStore: new Map(),
  };
  
  const participant: RoomParticipant = {
    ws,
    id: clientId,
    joinedAt: Date.now(),
    clientId,
  };
  
  roomState.participants.set(clientId, participant);
  rooms.set(roomId, roomState);
  clientRooms.set(clientId, roomId);
  wsToRoom.set(ws, roomId);
  
  log('info', 'Room created', { roomHash, participant_count: 1 });
  
  // Notify the creator
  ws.send(JSON.stringify({
    type: 'room_created',
    room_id: roomId,
    room_hash: roomHash,
    room_code: generateRoomCode(),
    invite_link: generateInviteLink(roomId),
  }));
  
  // Notify the other participant if they're already in the room
  broadcastToRoom(roomId, {
    type: 'participant_joined',
    participant_id: clientId.substring(0, 8) + '...',
    participant_count: roomState.participants.size,
  }, ws);
}

function handleJoinRoom(ws: WebSocket, clientId: string, payload: unknown) {
  const { room_id } = payload as { room_id: string };
  
  if (!room_id || room_id.length < 10) {
    ws.send(JSON.stringify({ type: 'error', message: 'Invalid room ID' }));
    return;
  }
  
  const room = rooms.get(room_id);
  
  if (!room) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room not found or expired' }));
    return;
  }
  
  if (room.participants.size >= 2) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room is full (max 2 participants)' }));
    return;
  }
  
  // Check if already in a room
  const existingRoom = clientRooms.get(clientId);
  if (existingRoom && existingRoom !== room_id) {
    // Leave previous room
    leaveRoom(clientId, existingRoom);
  }
  
  const participant: RoomParticipant = {
    ws,
    id: clientId,
    joinedAt: Date.now(),
    clientId,
  };
  
  room.participants.set(clientId, participant);
  clientRooms.set(clientId, room_id);
  wsToRoom.set(ws, room_id);
  
  log('info', 'Participant joined room', { 
    roomHash: sha256Hash(room_id).substring(0, 8),
    participant_count: room.participants.size 
  });
  
  // Send room ready to the joiner
  ws.send(JSON.stringify({
    type: 'room_ready',
    room_id: room_id,
    room_hash: sha256Hash(room_id).substring(0, 16),
  }));
  
  // Notify the other participant
  broadcastToRoom(room_id, {
    type: 'participant_joined',
    participant_id: clientId.substring(0, 8) + '...',
    participant_count: room.participants.size,
  }, ws);
  
  // If both are present, send room ready to the first participant too
  if (room.participants.size === 2) {
    for (const [pid, p] of room.participants) {
      if (pid !== clientId) {
        p.ws.send(JSON.stringify({
          type: 'room_ready',
          room_id: room_id,
          room_hash: sha256Hash(room_id).substring(0, 16),
        }));
      }
    }
  }
}

// ============================================================
// Message Handlers
// ============================================================

function handleEncryptedMessage(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
    return;
  }
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const msg = payload as Record<string, unknown>;
  const roomHash = sha256Hash(room_id).substring(0, 16);
  
  // Store the ciphertext (never decrypt)
  const messageRecord = {
    msgId: (msg.msg_id as string) || uuidv4(),
    roomHash,
    ciphertext: msg.ciphertext as string,
    nonce: msg.nonce as string,
    senderEphemeralId: (msg.sender_ephemeral_pk as string)?.substring(0, 8) + '...',
    type: (msg.type as string) || 'text',
    timestamp: msg.timestamp as number || Date.now(),
    expiresAt: Date.now() + MESSAGE_TTL_MS,
    deliveryStatus: 'sent',
  };
  
  room.messageStore.set(messageRecord.msgId, messageRecord);
  
  // Forward to the other participant
  broadcastToRoom(room_id, {
    type: 'encrypted_message_receive',
    ...messageRecord,
  }, ws);
  
  // Send delivery receipt back to sender
  ws.send(JSON.stringify({
    type: 'message_sent',
    msg_id: messageRecord.msgId,
    status: 'sent',
  }));
}

// ============================================================
// File Upload Handlers
// ============================================================

function handleFileUploadRequest(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
    return;
  }
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const req = payload as Record<string, unknown>;
  const fileId = uuidv4();
  const roomHash = sha256Hash(room_id).substring(0, 16);
  const totalChunks = req.total_chunks as number || 1;
  const fileSize = req.file_size as number || 0;
  
  // Validate file size
  if (fileSize > MAX_FILE_SIZE) {
    ws.send(JSON.stringify({ type: 'error', message: 'File too large' }));
    return;
  }
  
  // Register file
  room.fileStore.set(fileId, {
    fileId,
    roomHash,
    filePath: '',
    chunkIndex: 0,
    totalChunks,
    createdAt: Date.now(),
    expiresAt: Date.now() + MESSAGE_TTL_MS,
  });
  
  ws.send(JSON.stringify({
    type: 'file_upload_accepted',
    file_id: fileId,
    room_hash: roomHash,
    total_chunks: totalChunks,
  }));
  
  // Notify other participant
  broadcastToRoom(room_id, {
    type: 'file_upload_notification',
    file_id: fileId,
    room_hash: roomHash,
    total_chunks: totalChunks,
    file_size: fileSize,
  }, ws);
}

function handleFileChunk(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const chunk = payload as Record<string, unknown>;
  const fileId = chunk.file_id as string;
  const fileRecord = room.fileStore.get(fileId);
  
  if (!fileRecord) {
    ws.send(JSON.stringify({ type: 'error', message: 'File upload not accepted' }));
    return;
  }
  
  // Store chunk data in memory (encrypted)
  fileRecord.chunkIndex = (chunk.chunk_index as number) || 0;
  
  // In production, this would stream to disk/S3
  // For now, we acknowledge receipt
  ws.send(JSON.stringify({
    type: 'file_chunk_received',
    file_id: fileId,
    chunk_index: fileRecord.chunkIndex,
    total_chunks: fileRecord.totalChunks,
  }));
}

function handleFileComplete(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const req = payload as Record<string, unknown>;
  const fileId = req.file_id as string;
  const fileRecord = room.fileStore.get(fileId);
  
  if (!fileRecord) return;
  
  ws.send(JSON.stringify({
    type: 'file_upload_complete',
    file_id: fileId,
    room_hash: sha256Hash(room_id).substring(0, 16),
  }));
  
  broadcastToRoom(room_id, {
    type: 'file_uploaded',
    file_id: fileId,
    room_hash: sha256Hash(room_id).substring(0, 16),
    total_chunks: fileRecord.totalChunks,
  }, ws);
}

// ============================================================
// Lifecycle Handlers
// ============================================================

function handleParticipantLeft(ws: WebSocket, clientId: string) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  leaveRoom(clientId, room_id);
  
  // Notify remaining participant
  broadcastToRoom(room_id, {
    type: 'participant_left',
    participant_id: clientId.substring(0, 8) + '...',
  });
}

function handleRoomDestroy(ws: WebSocket, clientId: string) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
    return;
  }
  
  destroyRoom(room_id);
  clientRooms.delete(clientId);
  ws.send(JSON.stringify({ type: 'room_destroyed' }));
}

function handleSecurityEvent(ws: WebSocket, clientId: string, eventType: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  broadcastToRoom(room_id, {
    type: eventType,
    message: 'Security event detected',
    timestamp: Date.now(),
    ...payload,
  }, ws);
}

function handleDeliveryReceipt(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const msg = payload as Record<string, unknown>;
  broadcastToRoom(room_id, {
    type: 'message_delivered',
    msg_id: msg.msg_id as string,
  }, ws);
}

function handleReadReceipt(ws: WebSocket, clientId: string, payload: unknown) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const msg = payload as Record<string, unknown>;
  broadcastToRoom(room_id, {
    type: 'message_read',
    msg_id: msg.msg_id as string,
    timestamp: Date.now(),
  }, ws);
}

// ============================================================
// Helper Functions
// ============================================================

function leaveRoom(clientId: string, room_id: string) {
  const room = rooms.get(room_id);
  if (!room) return;
  
  room.participants.delete(clientId);
  clientRooms.delete(clientId);
  
  if (room.participants.size === 0) {
    destroyRoom(room_id);
  } else {
    room.bothLeft = true;
  }
}

function destroyRoom(room_id: string) {
  const room = rooms.get(room_id);
  if (!room) return;
  
  const roomHash = sha256Hash(room_id).substring(0, 16);
  
  log('info', 'Room destroyed, cleaning up', { roomHash });
  
  // Clear message store
  room.messageStore.clear();
  
  // Clear file store and delete files from disk
  for (const [, fileRecord] of room.fileStore) {
    if (fileRecord.filePath) {
      try {
        fs.unlinkSync(fileRecord.filePath);
      } catch { /* ignore */ }
    }
  }
  room.fileStore.clear();
  
  rooms.delete(room_id);
  
  broadcastGlobally({
    type: 'room_destroyed',
    room_hash: roomHash,
  });
}

function broadcastToRoom(roomId: string, message: unknown, excludeWs?: WebSocket) {
  const room = rooms.get(roomId);
  if (!room) return;
  
  const data = JSON.stringify(message);
  
  for (const [, participant] of room.participants) {
    if (participant.ws !== excludeWs && participant.ws.readyState === WebSocket.OPEN) {
      participant.ws.send(data);
    }
  }
}

function broadcastGlobally(message: unknown) {
  const data = JSON.stringify(message);
  for (const [ws] of wsToRoom.keys()) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(data);
    }
  }
}

function sha256Hash(input: string): string {
  const hash = require('crypto').createHash('sha256');
  hash.update(input);
  return hash.digest('hex');
}

function generateRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars[Math.floor(Math.random() * chars.length)];
  }
  return result;
}

function generateInviteLink(roomId: string): string {
  return `encchat://join/${roomId}`;
}

// ============================================================
// Cleanup Tasks
// ============================================================

// Clean expired messages and files
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  
  for (const [roomId, room] of rooms.entries()) {
    // Clean expired messages
    for (const [msgId, msg] of room.messageStore.entries()) {
      if (now > msg.expiresAt) {
        room.messageStore.delete(msgId);
        cleaned++;
      }
    }
    
    // Clean expired files
    for (const [fileId, file] of room.fileStore.entries()) {
      if (now > file.expiresAt) {
        room.fileStore.delete(fileId);
        cleaned++;
      }
    }
  }
  
  if (cleaned > 0) {
    log('info', `Cleanup: removed ${cleaned} expired records`);
  }
}, CLEANUP_INTERVAL_MS);

// ============================================================
// HTTP Routes
// ============================================================

// File download endpoint (for encrypted files)
app.get('/api/file/:fileId', async (req, res) => {
  const { fileId } = req.params;
  // In production, verify room membership and return encrypted file
  res.status(501).json({ error: 'Not implemented in this demo' });
});

// ============================================================
// Start Server
// ============================================================

server.listen(PORT, () => {
  log('info', `Encrypted chat server listening on port ${PORT}`, {
    port: PORT,
    message_ttl_days: process.env.MESSAGE_TTL_DAYS || '7',
    max_file_size_mb: MAX_FILE_SIZE / (1024 * 1024),
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log('info', 'Shutting down...');
  wss.close(() => {
    server.close(() => {
      process.exit(0);
    });
  });
});

process.on('SIGINT', () => {
  log('info', 'Shutting down...');
  wss.close(() => {
    server.close(() => {
      process.exit(0);
    });
  });
});

export { app, server, wss };
