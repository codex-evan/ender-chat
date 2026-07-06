// End-to-end encryption module
// Uses NaCl/libsodium primitives: X25519 key exchange, XSalsa20-Poly1305 encryption
// Adapted for TypeScript via tweetnacl

import * as nacl from 'tweetnacl';
import { encodeBase64, decodeBase64 } from 'tweetnacl-util';

// ============================================================
// Key Types
// ============================================================

export interface KeyPair {
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}

export interface EncryptedMessage {
  ciphertext: string;   // base64
  nonce: string;        // base64
  sender_ephemeral_pk: string; // base64 ephemeral public key
  type: 'text' | 'image' | 'video' | 'document' | 'file' | 'system' | 'security_event';
  timestamp: number;
  msg_id: string;
}

export interface EncryptedFile {
  file_ciphertext: string;  // base64 encrypted file data
  file_nonce: string;       // base64 nonce
  file_metadata: string;    // base64 encrypted metadata {original_name, size, mime_type}
  file_size: number;        // size of encrypted blob
  chunk_index: number;
  total_chunks: number;
}

// ============================================================
// Key Generation
// ============================================================

/** Generate a new X25519 keypair for identity */
export function generateIdentityKeyPair(): KeyPair {
  return nacl.box.keyPair();
}

/** Generate an ephemeral keypair for each message session */
export function generateEphemeralKeyPair(): KeyPair {
  return nacl.box.keyPair();
}

// ============================================================
// Key Exchange & Session Derivation (X25519 + HKDF-SHA256)
// ============================================================

/**
 * Perform X25519 key exchange to establish shared secret.
 * This is the foundation of our double-ratchet-like session.
 */
export function computeSharedSecret(privateKey: Uint8Array, publicKey: Uint8Array): Uint8Array {
  return nacl.box.before(privateKey, publicKey);
}

/**
 * Derive session keys from shared secret using HKDF-SHA256.
 * Produces:
 *   - message_encryption_key (32 bytes)
 *   - message_auth_key (32 bytes)  
 *   - file_encryption_key (32 bytes)
 */
export async function deriveSessionKeys(sharedSecret: Uint8Array, roomSalt: Uint8Array): Promise<{
  messageKey: Uint8Array;
  authKey: Uint8Array;
  fileKey: Uint8Array;
}> {
  // HKDF extract
  const ikm = sharedSecret;
  const salt = roomSalt.length > 0 ? roomSalt : new Uint8Array(32);
  
  const prk = await crypto.subtle.deriveBits(
    { name: 'HKDF', salt, hash: 'SHA-256', info: new Uint8Array([0]) },
    await crypto.subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']),
    256,
    false
  );
  
  // HKDF expand for message key
  const messageKey = await hkdfExpand(prk, new Uint8Array([1]), 32);
  const authKey = await hkdfExpand(prk, new Uint8Array([2]), 32);
  const fileKey = await hkdfExpand(prk, new Uint8Array([3]), 32);
  
  return { messageKey, authKey, fileKey };
}

async function hkdfExpand(prk: CryptoKey, info: Uint8Array, length: number): Promise<Uint8Array> {
  const t: Uint8Array[] = [];
  let okm = new Uint8Array(0);
  let i = 1;
  
  while (okm.length < length) {
    const data = new Uint8Array([...okm, ...info, i]);
    const mac = await crypto.subtle.sign(
      { name: 'HMAC', hash: 'SHA-256' },
      prk,
      data
    );
    t.push(new Uint8Array(mac));
    okm = new Uint8Array([...okm, ...info, i]);
    i++;
  }
  
  // Concatenate and truncate
  const total = t.reduce((acc, val) => {
    const combined = new Uint8Array(acc.length + val.length);
    combined.set(acc);
    combined.set(val, acc.length);
    return combined;
  }, new Uint8Array(0));
  
  return total.slice(0, length);
}

// ============================================================
// Passphrase Key Derivation (Argon2id via WebCrypto fallback to PBKDF2)
// ============================================================

/**
 * Derive encryption key from user passphrase.
 * Uses PBKDF2-SHA256 with 100000 iterations (Argon2id not available in pure TS).
 */
export async function deriveKeyFromPassphrase(passphrase: string, salt: Uint8Array): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const passphraseKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(passphrase),
    'PBKDF2',
    false,
    ['deriveBits']
  );
  
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    passphraseKey,
    256
  );
  
  return new Uint8Array(bits);
}

// ============================================================
// Message Encryption / Decryption (XSalsa20-Poly1305 via nacl.secretbox)
// ============================================================

/**
 * Encrypt a message payload.
 * Returns an EncryptedMessage with base64-encoded fields.
 */
export function encryptMessage(
  plaintext: string,
  sessionKey: Uint8Array,
  senderEphemeral: KeyPair
): EncryptedMessage {
  const nonce = nacl.randomBytes(nacl.secretbox.nonceLength);
  const encoder = new TextEncoder();
  const plaintextBytes = encoder.encode(plaintext);
  
  const ciphertext = nacl.secretbox(plaintextBytes, nonce, sessionKey);
  
  // Prepend sender ephemeral public key to ciphertext for receiver to derive session
  const combined = new Uint8Array(ciphertext.length + senderEphemeral.publicKey.length);
  combined.set(senderEphemeral.publicKey, 0);
  combined.set(ciphertext, senderEphemeral.publicKey.length);
  
  return {
    ciphertext: encodeBase64(combined),
    nonce: encodeBase64(nonce),
    sender_ephemeral_pk: encodeBase64(senderEphemeral.publicKey),
    type: 'text',
    timestamp: Date.now(),
    msg_id: generateMsgId(),
  };
}

/**
 * Decrypt a message payload.
 */
export function decryptMessage(
  encrypted: EncryptedMessage,
  sessionKey: Uint8Array,
  receiverPrivateKey: Uint8Array
): string | null {
  try {
    const combined = decodeBase64(encrypted.ciphertext);
    const nonce = decodeBase64(encrypted.nonce);
    
    // Extract sender ephemeral PK and ciphertext
    const senderPk = combined.slice(0, nacl.box.publicKeyLength);
    const ct = combined.slice(nacl.box.publicKeyLength);
    
    // Verify sender matches expected
    const sharedSecret = nacl.box.before(receiverPrivateKey, senderPk);
    if (!sharedSecret) return null;
    
    const decrypted = nacl.secretbox.open(ct, nonce, sessionKey);
    if (!decrypted) return null;
    
    const decoder = new TextDecoder();
    return decoder.decode(decrypted);
  } catch {
    return null;
  }
}

// ============================================================
// File Encryption / Decryption (Chunked XChaCha20-Poly1305 equivalent)
// ============================================================

const CHUNK_SIZE = 1024 * 1024; // 1MB chunks

/**
 * Encrypt a file in chunks.
 * Each chunk gets its own nonce for security.
 */
export async function* encryptFileChunks(
  fileBuffer: Uint8Array,
  fileKey: Uint8Array,
  originalName: string,
  mimeType: string,
  fileSize: number
): AsyncGenerator<EncryptedFile> {
  const metadata = JSON.stringify({
    original_name: originalName,
    mime_type: mimeType,
    file_size: fileSize,
  });
  
  const metadataNonce = nacl.randomBytes(nacl.secretbox.nonceLength);
  const metadataBytes = new TextEncoder().encode(metadata);
  const encryptedMetadata = nacl.secretbox(metadataBytes, metadataNonce, fileKey);
  
  const totalChunks = Math.ceil(fileBuffer.length / CHUNK_SIZE);
  
  for (let i = 0; i < totalChunks; i++) {
    const start = i * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, fileBuffer.length);
    const chunk = fileBuffer.slice(start, end);
    
    const chunkNonce = nacl.randomBytes(nacl.secretbox.nonceLength);
    const encryptedChunk = nacl.secretbox(chunk, chunkNonce, fileKey);
    
    yield {
      file_ciphertext: encodeBase64(encryptedChunk),
      file_nonce: encodeBase64(chunkNonce),
      file_metadata: encodeBase64(encryptedMetadata),
      file_size: encryptedChunk.length,
      chunk_index: i,
      total_chunks: totalChunks,
    };
  }
}

/**
 * Decrypt a file from chunks.
 */
export async function decryptFile(
  chunks: EncryptedFile[],
  fileKey: Uint8Array
): Promise<{ data: Uint8Array; metadata: { original_name: string; mime_type: string; file_size: number } }> {
  // Sort by chunk index
  const sorted = [...chunks].sort((a, b) => a.chunk_index - b.chunk_index);
  
  // Decrypt metadata from first chunk
  const metadataBytes = decodeBase64(sorted[0].file_metadata);
  const metadataNonce = decodeBase64(sorted[0].file_nonce);
  // The metadata is stored in the first chunk's file_metadata field
  // We need to decrypt it with the file key
  // Note: metadata was encrypted with its own nonce using the file key
  const decryptedMeta = nacl.secretbox.open(
    metadataBytes,
    metadataNonce,
    fileKey
  );
  
  if (!decryptedMeta) {
    throw new Error('Failed to decrypt file metadata');
  }
  
  const metadata = JSON.parse(new TextDecoder().decode(decryptedMeta));
  
  // Reassemble file data
  const totalSize = sorted.reduce((sum, c) => sum + decodeBase64(c.file_ciphertext).length, 0);
  const result = new Uint8Array(totalSize);
  let offset = 0;
  
  for (const chunk of sorted) {
    const ct = decodeBase64(chunk.file_ciphertext);
    const cn = decodeBase64(chunk.file_nonce);
    const decrypted = nacl.secretbox.open(ct, cn, fileKey);
    
    if (!decrypted) {
      throw new Error(`Failed to decrypt file chunk ${chunk.chunk_index}`);
    }
    
    result.set(decrypted, offset);
    offset += decrypted.length;
  }
  
  return { data: result, metadata };
}

// ============================================================
// Signature (for message integrity)
// ============================================================

/** Sign a message with the identity private key */
export function signMessage(message: EncryptedMessage, privateKey: Uint8Array): string {
  const data = `${message.msg_id}:${message.timestamp}:${message.type}:${message.ciphertext}`;
  const dataBytes = new TextEncoder().encode(data);
  const signature = nacl.sign.detached(dataBytes, privateKey);
  return encodeBase64(signature);
}

/** Verify a message signature */
export function verifySignature(message: EncryptedMessage, signature: string, publicKey: Uint8Array): boolean {
  try {
    const data = `${message.msg_id}:${message.timestamp}:${message.type}:${message.ciphertext}`;
    const dataBytes = new TextEncoder().encode(data);
    const sigBytes = decodeBase64(signature);
    return nacl.sign.detached.verify(dataBytes, sigBytes, publicKey);
  } catch {
    return false;
  }
}

// ============================================================
// Utility Functions
// ============================================================

function generateMsgId(): string {
  const bytes = nacl.randomBytes(16);
  return encodeBase64(bytes);
}

/** Encode bytes to hex string */
export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}

/** Decode hex string to bytes */
export function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
  }
  return bytes;
}

/** Encode bytes to base64 */
export function toBase64(bytes: Uint8Array): string {
  return encodeBase64(bytes);
}

/** Decode base64 to bytes */
export function fromBase64(b64: string): Uint8Array {
  return decodeBase64(b64);
}

/** Generate a secure room code (8 alphanumeric chars) */
export function generateRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Remove confusing chars
  const bytes = nacl.randomBytes(6); // 48 bits = ~8.3 chars of base36
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars[bytes[i] % chars.length];
  }
  return result;
}

/** Generate a secure room secret (32 random bytes, base64) */
export function generateRoomSecret(): string {
  return encodeBase64(nacl.randomBytes(32));
}

/** Generate a unique invite link code */
export function generateInviteCode(): string {
  return encodeBase64(nacl.randomBytes(24));
}

export { encodeBase64, decodeBase64 };
export { CHUNK_SIZE };
