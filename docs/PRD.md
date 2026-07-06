# EncChat - Anonymous End-to-End Encrypted Chat

## Product Requirements Document (PRD)

### 1. Overview

EncChat is a cross-platform anonymous messaging application that provides end-to-end encryption for text, images, files, and voice messages. The app connects users through temporary rooms with no account registration, no personal data collection, and zero knowledge of message content by the server.

### 2. Core Principles

- **Zero Knowledge**: Server processes only ciphertext, never sees plaintext
- **Anonymous**: No accounts, phone numbers, emails, or PII
- **Ephemeral**: Messages auto-delete after 7 days or when both parties leave
- **Local-First**: Saved chats encrypted with user-derived passphrase
- **Platform-Native**: iOS, Android, Windows desktop apps (no web)

### 3. Technical Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Client Apps                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  iOS     │  │ Android  │  │ Windows  │          │
│  │ Flutter  │  │ Flutter  │  │ Flutter  │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │              │              │                │
│  ┌────┴──────────────┴──────────────┴─────┐         │
│  │         Shared Crypto Layer            │         │
│  │  X25519 · AES-256-GCM · HKDF · PBKDF2 │         │
│  └────────────────┬───────────────────────┘         │
│                   │ WSS (TLS 1.3)                   │
├───────────────────┼─────────────────────────────────┤
│                   │     Server (Node.js)             │
│  ┌────────────────┴────────────────┐                │
│  │  WebSocket Relay (Ciphertext)  │                │
│  │  Room State Management         │                │
│  │  TTL-Based Cleanup (7 days)    │                │
│  │  Rate Limiting                 │                │
│  └────────────────┬────────────────┘                │
│                   │                                  │
│  ┌────────────────┴────────────────┐                │
│  │   Encrypted Blob Storage       │                │
│  │   (Never decrypted by server)  │                │
│  └─────────────────────────────────┘                │
└─────────────────────────────────────────────────────┘
```

### 4. Encryption Flow

```
User A                          Server                    User B
  │                              │                         │
  │  1. Generate X25519 keys     │                         │
  │  2. Create room (get code)   │                         │
  │───create_room───────────────>│                         │
  │                              │                         │
  │  3. Share room code          │                         │
  │  <──room_code─────────────── │                         │
  │                              │                         │
  │  4. User B joins room        │                         │
  │                              │                         │
  │                              │<──join_room─────────────│
  │  5. X25519 key exchange      │                         │
  │  6. Derive session keys      │                         │
  │───encrypted_message─────────>│───relay────────────────>│
  │  (ciphertext only)           │  (ciphertext only)      │
  │                              │                         │
  │  7. Receiver decrypts        │                         │
  │                              │                         │
  │  8. Both leave → delete      │                         │
  │───participant_left─────────>│───delete────────────────>│
```

### 5. Data Model

#### Server-Side (Ciphertext Only)
| Field | Type | Description |
|-------|------|-------------|
| room_id_hash | string | SHA-256 hash of room ID (first 16 chars) |
| message_id | string | UUID |
| ciphertext | string | Base64 encrypted payload |
| nonce | string | Base64 encryption nonce |
| sender_ephemeral_id | string | Hash of ephemeral public key |
| type | string | text/image/video/document/file |
| created_at | timestamp | UTC epoch ms |
| expires_at | timestamp | UTC epoch ms (created_at + 7 days) |
| delivery_status | string | sent/delivered/read |
| encrypted_file_id | string? | UUID for attached file |
| file_size | int? | Size in bytes |

#### Client-Side (Local Encrypted Storage)
| Field | Type | Description |
|-------|------|-------------|
| msg_id | string | UUID |
| room_hash | string | Room identifier |
| ciphertext | string | Encrypted message |
| nonce | string | Encryption nonce |
| timestamp | int | Epoch ms |
| display_content | string? | Decrypted content (cached) |

### 6. Security Architecture

See [SECURITY_ARCHITECTURE.md](./SECURITY_ARCHITECTURE.md) for complete threat model and security details.

### 7. API / WebSocket Events

#### Client → Server
| Event | Payload | Description |
|-------|---------|-------------|
| create_room | {} | Create new encrypted room |
| join_room | {room_id} | Join existing room |
| encrypted_message_send | {...} | Send encrypted message |
| encrypted_file_upload_request | {...} | Request file upload slot |
| encrypted_file_chunk | {...} | Send encrypted file chunk |
| encrypted_file_complete | {file_id} | Signal file upload complete |
| participant_left | {} | Leave current room |
| room_destroy | {} | Destroy room and all data |
| screenshot_detected | {} | Security event: screenshot |
| screen_recording_detected | {} | Security event: recording |
| security_warning | {...} | Generic security alert |
| message_delivered | {msg_id} | Delivery receipt |
| message_read | {msg_id} | Read receipt (optional) |

#### Server → Client
| Event | Payload | Description |
|-------|---------|-------------|
| connected | {client_id} | Connection established |
| room_created | {room_id, room_code, invite_link} | New room created |
| room_ready | {room_id, room_hash} | Room is active |
| participant_joined | {participant_id, count} | Other user joined |
| encrypted_message_receive | {...} | Received encrypted message |
| message_sent | {msg_id, status} | Message acknowledged |
| file_upload_accepted | {file_id, total_chunks} | File upload approved |
| file_chunk_received | {file_id, chunk_index} | Chunk acknowledged |
| file_upload_complete | {file_id} | File upload complete |
| participant_left | {participant_id} | Other user left |
| room_destroyed | {room_hash} | Room destroyed |
| screenshot_detected | {...} | Security event forwarded |
| error | {message} | Error message |

### 8. Project Structure

```
encrypted-chat/
├── server/                    # Node.js WebSocket server
│   ├── src/
│   │   ├── server.ts          # Main server entry
│   │   ├── routes/            # HTTP routes
│   │   ├── middleware/        # Auth/rate-limit middleware
│   │   └── utils/             # Utility functions
│   ├── uploads/               # Encrypted file storage
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   └── package.json
├── shared/
│   └── crypto/                # Shared encryption library
│       ├── src/
│       │   └── index.ts       # Encryption primitives
│       └── package.json
├── app/                       # Flutter cross-platform app
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── main/
│   │   │   ├── app_locator.dart    # DI / services
│   │   │   ├── app_router.dart     # Navigation
│   │   │   └── app_theme.dart      # Theme definitions
│   │   ├── screens/
│   │   │   ├── splash/
│   │   │   ├── room/
│   │   │   ├── chat/
│   │   │   ├── settings/
│   │   │   └── local_records/
│   │   ├── widgets/
│   │   │   ├── message_bubble.dart
│   │   │   └── security_banner.dart
│   │   ├── models/
│   │   │   ├── message.dart
│   │   │   └── room.dart
│   │   ├── services/
│   │   │   ├── crypto_service.dart
│   │   │   ├── ws_service.dart
│   │   │   └── storage_service.dart
│   │   ├── i18n/
│   │   │   ├── app_localizations.dart
│   │   │   └── app_localizations_zh.dart
│   │   └── crypto/
│   ├── android/
│   ├── ios/
│   ├── windows/
│   └── pubspec.yaml
└── docs/
    ├── SECURITY_ARCHITECTURE.md
    ├── DEPLOYMENT.md
    └── TESTING.md
```

### 9. Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete server deployment instructions.

### 10. Testing Plan

1. **Unit Tests**: Crypto service (encrypt/decrypt roundtrip)
2. **Integration Tests**: WebSocket room lifecycle
3. **Security Tests**: Key exchange verification, nonce uniqueness
4. **Performance Tests**: File encryption throughput
5. **Cross-Platform Tests**: iOS, Android, Windows UI parity
6. **Penetration Tests**: Server-side data isolation

### 11. Future Extensions

- Group rooms (3+ participants)
- Message reactions and replies
- Voice/video calls (WebRTC with E2EE)
- Disappearing messages timer
- Message forwarding prevention
- Proof of existence / audit log
- Multi-device sync (via encrypted backup)
- Onion routing integration
