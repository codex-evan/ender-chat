/**
 * WebSocket message types for server-client communication
 */

// Client -> Server events
export interface CreateRoomEvent {
  type: 'create_room';
}

export interface JoinRoomEvent {
  type: 'join_room';
  room_id: string;
}

export interface EncryptedMessageEvent {
  type: 'encrypted_message_send';
  ciphertext: string;
  nonce: string;
  sender_ephemeral_pk: string;
  type: 'text' | 'image' | 'video' | 'document' | 'file';
  timestamp: number;
  msg_id: string;
  original_filename?: string;
  file_size?: number;
}

export interface FileUploadRequestEvent {
  type: 'encrypted_file_upload_request';
  file_id: string;
  total_chunks: number;
  file_size: number;
  mime_type: string;
}

export interface FileChunkEvent {
  type: 'encrypted_file_chunk';
  file_id: string;
  chunk_index: number;
  ciphertext: string;
  nonce: string;
}

export interface FileCompleteEvent {
  type: 'encrypted_file_complete';
  file_id: string;
}

export interface ParticipantLeftEvent {
  type: 'participant_left';
}

export interface RoomDestroyEvent {
  type: 'room_destroy';
}

export interface SecurityEvent {
  type: 'screenshot_detected' | 'screen_recording_detected' | 'security_warning';
  timestamp: number;
  details?: Record<string, unknown>;
}

export interface DeliveryReceiptEvent {
  type: 'message_delivered';
  msg_id: string;
}

export interface ReadReceiptEvent {
  type: 'message_read';
  msg_id: string;
  timestamp: number;
}

// Server -> Client events
export interface ConnectedEvent {
  type: 'connected';
  client_id: string;
}

export interface RoomCreatedEvent {
  type: 'room_created';
  room_id: string;
  room_hash: string;
  room_code: string;
  invite_link: string;
}

export interface RoomReadyEvent {
  type: 'room_ready';
  room_id: string;
  room_hash: string;
}

export interface ParticipantJoinedEvent {
  type: 'participant_joined';
  participant_id: string;
  participant_count: number;
}

export interface EncryptedMessageReceiveEvent {
  type: 'encrypted_message_receive';
  msg_id: string;
  room_hash: string;
  ciphertext: string;
  nonce: string;
  sender_ephemeral_id: string;
  type: string;
  timestamp: number;
  expires_at: number;
  delivery_status: string;
  encrypted_file_id?: string;
  file_size?: number;
}

export interface MessageSentEvent {
  type: 'message_sent';
  msg_id: string;
  status: string;
}

export interface ParticipantLeftEvent {
  type: 'participant_left';
  participant_id: string;
}

export interface RoomDestroyedEvent {
  type: 'room_destroyed';
  room_hash: string;
}

export interface FileUploadAcceptedEvent {
  type: 'file_upload_accepted';
  file_id: string;
  room_hash: string;
  total_chunks: number;
}

export interface FileChunkReceivedEvent {
  type: 'file_chunk_received';
  file_id: string;
  chunk_index: number;
  total_chunks: number;
}

export interface FileUploadedEvent {
  type: 'file_uploaded';
  file_id: string;
  room_hash: string;
  total_chunks: number;
}

export interface ErrorEvent {
  type: 'error';
  message: string;
}

// Union type for all events
export type ServerEvent =
  | ConnectedEvent
  | RoomCreatedEvent
  | RoomReadyEvent
  | ParticipantJoinedEvent
  | EncryptedMessageReceiveEvent
  | MessageSentEvent
  | ParticipantLeftEvent
  | RoomDestroyedEvent
  | FileUploadAcceptedEvent
  | FileChunkReceivedEvent
  | FileUploadedEvent
  | ErrorEvent;

export type ClientEvent =
  | CreateRoomEvent
  | JoinRoomEvent
  | EncryptedMessageEvent
  | FileUploadRequestEvent
  | FileChunkEvent
  | FileCompleteEvent
  | ParticipantLeftEvent
  | RoomDestroyEvent
  | SecurityEvent
  | DeliveryReceiptEvent
  | ReadReceiptEvent;
