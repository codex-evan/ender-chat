/**
 * EncChat Server - Anonymous End-to-End Encrypted Chat Server
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

const express = require('express');
const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// ============================================================
// Configuration
// ============================================================

const PORT = parseInt(process.env.PORT || '3000', 10);
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE || '104857600', 10);
const MAX_MESSAGE_SIZE = parseInt(process.env.MAX_MESSAGE_SIZE || '1048576', 10);
const MESSAGE_TTL_MS = (parseInt(process.env.MESSAGE_TTL_DAYS || '7', 10)) * 24 * 60 * 60 * 1000;
const CLEANUP_INTERVAL_MS = (parseInt(process.env.CLEANUP_INTERVAL_MINUTES || '60', 10)) * 60 * 1000;
const RATE_LIMIT_WINDOW = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000', 10);
const RATE_LIMIT_MAX = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10);
const ROOM_JOIN_LIMIT = parseInt(process.env.ROOM_JOIN_RATE_LIMIT || '10', 10);
const UPLOAD_DIR = path.resolve(__dirname, process.env.UPLOAD_DIR || '../uploads');

if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// ============================================================
// Logging (never logs sensitive data)
// ============================================================

const LOG_LEVEL = process.env.LOG_LEVEL || 'warn';
const LEVELS = ['error', 'warn', 'info', 'debug'];

function log(level, message, meta = {}) {
  if (LEVELS.indexOf(level) > LEVELS.indexOf(LOG_LEVEL)) return;
  const sanitized = {};
  const sensitive = ['ciphertext','nonce','key','secret','passphrase','password','content','message','file_name'];
  for (const [k, v] of Object.entries(meta)) {
    if (sensitive.some(s => k.toLowerCase().includes(s))) {
      sanitized[k] = '[REDACTED]';
    } else {
      sanitized[k] = typeof v === 'string' && v.length > 50 ? v.substring(0, 50) + '...' : v;
    }
  }
  console[level](`[${new Date().toISOString()}] [${level.toUpperCase()}] ${message}`, sanitized);
}

// ============================================================
// Rate Limiter
// ============================================================

const rateLimits = new Map();

function checkRateLimit(clientId, maxRequests) {
  const now = Date.now();
  let entry = rateLimits.get(clientId);
  if (!entry) {
    entry = { timestamps: [] };
    rateLimits.set(clientId, entry);
  }
  entry.timestamps = entry.timestamps.filter(t => now - t < RATE_LIMIT_WINDOW);
  if (entry.timestamps.length >= maxRequests) return false;
  entry.timestamps.push(now);
  return true;
}

setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimits.entries()) {
    entry.timestamps = entry.timestamps.filter(t => now - t < RATE_LIMIT_WINDOW);
    if (entry.timestamps.length === 0) rateLimits.delete(key);
  }
}, RATE_LIMIT_WINDOW);

// ============================================================
// Room & Connection State
// ============================================================

const rooms = new Map();
const clientRooms = new Map();
const wsToRoom = new Map();
const wsToClientId = new Map();

// ============================================================
// Express + HTTP
// ============================================================

const app = express();
const server = http.createServer(app);

app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    rooms_active: rooms.size,
    clients_connected: wsToClientId.size,
  });
});

// ============================================================
// WebSocket
// ============================================================

const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  const clientId = uuidv4();
  wsToClientId.set(ws, clientId);
  
  const clientIp = req.socket.remoteAddress || 'unknown';
  
  if (!checkRateLimit(clientId, RATE_LIMIT_MAX)) {
    log('warn', 'Rate limit exceeded', { clientId: clientId.substring(0, 8), ip: clientIp });
    ws.send(JSON.stringify({ type: 'error', message: 'Rate limit exceeded' }));
    ws.close(4001);
    return;
  }
  
  ws.send(JSON.stringify({ type: 'connected', client_id: clientId }));
  
  ws.on('message', (data) => {
    handleMessage(ws, clientId, data);
  });
  
  ws.on('close', () => handleDisconnect(ws, clientId));
  ws.on('error', (err) => {
    log('error', 'WebSocket error', { clientId: clientId.substring(0, 8), error: err.message });
    handleDisconnect(ws, clientId);
  });
});

function handleDisconnect(ws, clientId) {
  const room_id = clientRooms.get(clientId);
  if (room_id) {
    const room = rooms.get(room_id);
    if (room) {
      room.participants.delete(clientId);
      clientRooms.delete(clientId);
      broadcastToRoom(room_id, {
        type: 'participant_left',
        participant_id: clientId.substring(0, 8) + '...',
      });
      if (room.participants.size === 0) {
        destroyRoom(room_id);
      }
    }
  }
  wsToClientId.delete(ws);
  wsToRoom.delete(ws);
}

// ============================================================
// Message Handler
// ============================================================

function handleMessage(ws, clientId, rawData) {
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
    case 'create_room': handleCreateRoom(ws, clientId); break;
    case 'join_room': handleJoinRoom(ws, clientId, payload); break;
    case 'encrypted_message_send': handleEncryptedMessage(ws, clientId, payload); break;
    case 'encrypted_file_upload_request': handleFileUploadRequest(ws, clientId, payload); break;
    case 'encrypted_file_chunk': handleFileChunk(ws, clientId, payload); break;
    case 'encrypted_file_complete': handleFileComplete(ws, clientId, payload); break;
    case 'participant_left': handleParticipantLeft(ws, clientId); break;
    case 'room_destroy': handleRoomDestroy(ws, clientId); break;
    case 'screenshot_detected':
    case 'screen_recording_detected':
    case 'security_warning':
      handleSecurityEvent(ws, clientId, type, payload); break;
    case 'message_delivered': handleDeliveryReceipt(ws, clientId, payload); break;
    case 'message_read': handleReadReceipt(ws, clientId, payload); break;
    default:
      ws.send(JSON.stringify({ type: 'error', message: `Unknown event: ${type}` }));
  }
}

// ============================================================
// Room Handlers
// ============================================================

function handleCreateRoom(ws, clientId) {
  const roomId = uuidv4();
  const roomHash = sha256(roomId).substring(0, 16);
  const roomCode = generateRoomCode();
  const inviteLink = `encchat://join/${roomId}`;
  
  const room = {
    roomId,
    roomHash,
    roomCode,
    inviteLink,
    participants: new Map([[clientId, { ws, id: clientId, joinedAt: Date.now() }]]),
    createdAt: Date.now(),
    messages: new Map(),
    files: new Map(),
  };
  
  rooms.set(roomId, room);
  clientRooms.set(clientId, roomId);
  wsToRoom.set(ws, roomId);
  
  log('info', 'Room created', { roomHash, participants: 1 });
  
  ws.send(JSON.stringify({
    type: 'room_created',
    room_id: roomId,
    room_hash: roomHash,
    room_code: roomCode,
    invite_link: inviteLink,
  }));
}

function handleJoinRoom(ws, clientId, payload) {
  const { room_id } = payload;
  if (!room_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Missing room_id' }));
    return;
  }
  
  const room = rooms.get(room_id);
  if (!room) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room not found or expired' }));
    return;
  }
  if (room.participants.size >= 2) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room is full' }));
    return;
  }
  
  // Leave previous room if any
  const prevRoom = clientRooms.get(clientId);
  if (prevRoom && prevRoom !== room_id) {
    leaveRoom(clientId, prevRoom);
  }
  
  room.participants.set(clientId, { ws, id: clientId, joinedAt: Date.now() });
  clientRooms.set(clientId, room_id);
  wsToRoom.set(ws, room_id);
  
  log('info', 'Participant joined', { roomHash: room.roomHash, count: room.participants.size });
  
  ws.send(JSON.stringify({
    type: 'room_ready',
    room_id: room_id,
    room_hash: room.roomHash,
  }));
  
  // Notify the other participant
  broadcastToRoom(room_id, {
    type: 'participant_joined',
    participant_id: clientId.substring(0, 8) + '...',
    participant_count: room.participants.size,
  }, ws);
  
  // If both present, notify first participant too
  if (room.participants.size === 2) {
    for (const [, p] of room.participants) {
      if (p.id !== clientId && p.ws.readyState === WebSocket.OPEN) {
        p.ws.send(JSON.stringify({
          type: 'room_ready',
          room_id: room_id,
          room_hash: room.roomHash,
        }));
      }
    }
  }
}

function handleEncryptedMessage(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const msgId = payload.msg_id || uuidv4();
  const msg = {
    msgId,
    roomHash: room.roomHash,
    ciphertext: payload.ciphertext || '',
    nonce: payload.nonce || '',
    senderEphemeralId: (payload.sender_ephemeral_pk || '').substring(0, 8) + '...',
    type: payload.type || 'text',
    timestamp: payload.timestamp || Date.now(),
    expiresAt: Date.now() + MESSAGE_TTL_MS,
    deliveryStatus: 'sent',
    encryptedFileId: payload.encrypted_file_id,
    fileSize: payload.file_size,
  };
  
  room.messages.set(msgId, msg);
  
  broadcastToRoom(room_id, {
    type: 'encrypted_message_receive',
    ...msg,
  }, ws);
  
  ws.send(JSON.stringify({
    type: 'message_sent',
    msg_id: msgId,
    status: 'sent',
  }));
}

function handleFileUploadRequest(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  
  const room = rooms.get(room_id);
  if (!room) return;
  
  const fileId = uuidv4();
  const totalChunks = payload.total_chunks || 1;
  const fileSize = payload.file_size || 0;
  
  if (fileSize > MAX_FILE_SIZE) {
    ws.send(JSON.stringify({ type: 'error', message: 'File too large' }));
    return;
  }
  
  room.files.set(fileId, {
    fileId,
    roomHash: room.roomHash,
    chunkIndex: 0,
    totalChunks,
    createdAt: Date.now(),
    expiresAt: Date.now() + MESSAGE_TTL_MS,
  });
  
  ws.send(JSON.stringify({
    type: 'file_upload_accepted',
    file_id: fileId,
    room_hash: room.roomHash,
    total_chunks: totalChunks,
  }));
  
  broadcastToRoom(room_id, {
    type: 'file_upload_notification',
    file_id: fileId,
    room_hash: room.roomHash,
    total_chunks: totalChunks,
    file_size: fileSize,
  }, ws);
}

function handleFileChunk(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  const room = rooms.get(room_id);
  if (!room) return;
  
  const fileId = payload.file_id;
  const fileRec = room.files.get(fileId);
  if (!fileRec) {
    ws.send(JSON.stringify({ type: 'error', message: 'File upload not accepted' }));
    return;
  }
  
  fileRec.chunkIndex = payload.chunk_index || 0;
  
  ws.send(JSON.stringify({
    type: 'file_chunk_received',
    file_id: fileId,
    chunk_index: fileRec.chunkIndex,
    total_chunks: fileRec.totalChunks,
  }));
}

function handleFileComplete(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  const room = rooms.get(room_id);
  if (!room) return;
  
  const fileId = payload.file_id;
  const fileRec = room.files.get(fileId);
  if (!fileRec) return;
  
  ws.send(JSON.stringify({
    type: 'file_upload_complete',
    file_id: fileId,
    room_hash: room.roomHash,
  }));
  
  broadcastToRoom(room_id, {
    type: 'file_uploaded',
    file_id: fileId,
    room_hash: room.roomHash,
    total_chunks: fileRec.totalChunks,
  }, ws);
}

function handleParticipantLeft(ws, clientId) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  leaveRoom(clientId, room_id);
}

function handleRoomDestroy(ws, clientId) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) {
    ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
    return;
  }
  destroyRoom(room_id);
  clientRooms.delete(clientId);
  ws.send(JSON.stringify({ type: 'room_destroyed' }));
}

function handleSecurityEvent(ws, clientId, eventType, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  broadcastToRoom(room_id, {
    type: eventType,
    message: 'Security event detected',
    timestamp: Date.now(),
    ...payload,
  }, ws);
}

function handleDeliveryReceipt(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  broadcastToRoom(room_id, {
    type: 'message_delivered',
    msg_id: payload.msg_id,
  }, ws);
}

function handleReadReceipt(ws, clientId, payload) {
  const room_id = clientRooms.get(clientId);
  if (!room_id) return;
  broadcastToRoom(room_id, {
    type: 'message_read',
    msg_id: payload.msg_id,
    timestamp: Date.now(),
  }, ws);
}

// ============================================================
// Helpers
// ============================================================

function leaveRoom(clientId, room_id) {
  const room = rooms.get(room_id);
  if (!room) return;
  
  room.participants.delete(clientId);
  clientRooms.delete(clientId);
  
  if (room.participants.size === 0) {
    destroyRoom(room_id);
  } else {
    broadcastToRoom(room_id, {
      type: 'participant_left',
      participant_id: clientId.substring(0, 8) + '...',
    });
  }
}

function destroyRoom(room_id) {
  const room = rooms.get(room_id);
  if (!room) return;
  
  log('info', 'Room destroyed', { roomHash: room.roomHash });
  room.messages.clear();
  room.files.clear();
  rooms.delete(room_id);
  
  for (const [, p] of room.participants) {
    if (p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(JSON.stringify({ type: 'room_destroyed', room_hash: room.roomHash }));
    }
  }
}

function broadcastToRoom(roomId, message, excludeWs) {
  const room = rooms.get(roomId);
  if (!room) return;
  const data = JSON.stringify(message);
  for (const [, p] of room.participants) {
    if (p.ws !== excludeWs && p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(data);
    }
  }
}

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(6);
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars[bytes[i] % chars.length];
  }
  return result;
}

// ============================================================
// Cleanup
// ============================================================

setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  
  for (const [roomId, room] of rooms.entries()) {
    for (const [msgId, msg] of room.messages.entries()) {
      if (now > msg.expiresAt) {
        room.messages.delete(msgId);
        cleaned++;
      }
    }
    for (const [fileId, file] of room.files.entries()) {
      if (now > file.expiresAt) {
        room.files.delete(fileId);
        cleaned++;
      }
    }
  }
  
  if (cleaned > 0) log('info', `Cleanup: removed ${cleaned} expired records`);
}, CLEANUP_INTERVAL_MS);

// ============================================================
// Start
// ============================================================

server.listen(PORT, () => {
  log('info', `EncChat server listening on port ${PORT}`, {
    port: PORT,
    ttl_days: process.env.MESSAGE_TTL_DAYS || '7',
    max_file_mb: MAX_FILE_SIZE / (1024 * 1024),
  });
});

process.on('SIGTERM', () => {
  log('info', 'Shutting down...');
  wss.close(() => server.close(() => process.exit(0)));
});

process.on('SIGINT', () => {
  log('info', 'Shutting down...');
  wss.close(() => server.close(() => process.exit(0)));
});
