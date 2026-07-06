/**
 * Data cleanup utilities for TTL-based message and file deletion
 */

import fs from 'fs';
import path from 'path';

interface StoredMessage {
  msgId: string;
  roomHash: string;
  ciphertext: string;
  nonce: string;
  senderEphemeralId: string;
  type: string;
  timestamp: number;
  expiresAt: number;
  deliveryStatus: string;
}

interface StoredFile {
  fileId: string;
  roomHash: string;
  filePath: string;
  createdAt: number;
  expiresAt: number;
  totalChunks: number;
}

/**
 * Clean expired messages from the in-memory store.
 * Returns count of deleted records.
 */
export function cleanExpiredMessages(
  messages: Map<string, StoredMessage>,
  now: number = Date.now()
): number {
  let cleaned = 0;
  
  for (const [msgId, msg] of messages.entries()) {
    if (now > msg.expiresAt) {
      messages.delete(msgId);
      cleaned++;
    }
  }
  
  return cleaned;
}

/**
 * Clean expired files from storage.
 * Deletes both metadata and physical files.
 */
export async function cleanExpiredFiles(
  files: Map<string, StoredFile>,
  uploadDir: string,
  now: number = Date.now()
): Promise<number> {
  let cleaned = 0;
  
  for (const [fileId, file] of files.entries()) {
    if (now > file.expiresAt) {
      // Delete physical file
      try {
        const filePath = path.join(uploadDir, fileId);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      } catch {
        // Ignore file deletion errors
      }
      
      files.delete(fileId);
      cleaned++;
    }
  }
  
  return cleaned;
}

/**
 * Clean empty directories in the upload folder.
 */
export function cleanEmptyDirectories(dir: string): void {
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      
      if (entry.isDirectory()) {
        cleanEmptyDirectories(fullPath);
        
        // Remove empty directory
        if (fs.readdirSync(fullPath).length === 0) {
          fs.rmdirSync(fullPath);
        }
      }
    }
  } catch {
    // Ignore directory traversal errors
  }
}

/**
 * Generate a deterministic hash for a room ID.
 * Used for anonymized room identification in logs.
 */
export function hashRoomId(roomId: string): string {
  let hash = 0;
  for (let i = 0; i < roomId.length; i++) {
    const char = roomId.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(16).padStart(8, '0');
}

/**
 * Mask an IP address for logging (keep only first 2 octets).
 */
export function maskIpAddress(ip: string): string {
  if (ip.includes(':')) {
    // IPv6
    const parts = ip.split(':');
    return parts.slice(0, 2).join(':') + ':***';
  }
  // IPv4
  const parts = ip.split('.');
  return parts.slice(0, 2).join('.') + '.***.***';
}
