/// Room state model

enum RoomStateEnum {
  waiting,      // Waiting for partner
  active,       // Chat active
  ended,        // Both left
  destroyed,    // Room destroyed
  saved,        // Saved locally
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class RoomInfo {
  final String roomId;
  final String roomCode;
  final String roomHash;
  final String? inviteLink;
  final RoomStateEnum state;
  final bool bothParticipantsLeft;
  final DateTime createdAt;
  
  const RoomInfo({
    required this.roomId,
    required this.roomCode,
    required this.roomHash,
    this.inviteLink,
    this.state = RoomStateEnum.waiting,
    this.bothParticipantsLeft = false,
    required this.createdAt,
  });
}
