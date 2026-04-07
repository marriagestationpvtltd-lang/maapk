# Socket.IO Chat Server

Real-time chat server for the Marriage Station Flutter app, replacing Firebase Firestore with Socket.IO + MySQL.

## Requirements
- Node.js >= 18
- MySQL >= 5.7

## Setup

### 1. Database
Run the migration SQL on your MySQL server:
```bash
mysql -u root -p marriagestation < sql/chat_tables.sql
```

### 2. Environment
```bash
cp .env.example .env
# Edit .env with your MySQL credentials and server URL
```

### 3. Install & start
```bash
npm install
npm start        # production
npm run dev      # development (auto-reload)
```

## Events Reference

### Client → Server
| Event | Payload |
|---|---|
| `authenticate` | `{userId}` |
| `join_room` | `{chatRoomId}` |
| `leave_room` | `{chatRoomId}` |
| `send_message` | `{chatRoomId, senderId, receiverId, message, messageType, messageId?, repliedTo?, isReceiverViewing?}` |
| `typing_start` | `{chatRoomId, userId}` |
| `typing_stop` | `{chatRoomId, userId}` |
| `mark_read` | `{chatRoomId, userId}` |
| `set_active_chat` | `{userId, chatRoomId, isActive}` |
| `get_messages` | `{chatRoomId, page, limit}` + ack callback |
| `get_chat_rooms` | `{userId}` + ack callback |
| `edit_message` | `{chatRoomId, messageId, newMessage}` |
| `delete_message` | `{chatRoomId, messageId, userId, deleteForEveryone}` |

### Server → Client
| Event | Payload |
|---|---|
| `authenticated` | `{success, userId}` |
| `new_message` | message object |
| `message_edited` | `{chatRoomId, messageId, newMessage, editedAt}` |
| `message_deleted` | `{chatRoomId, messageId, deleteForEveryone, userId}` |
| `typing_start` | `{chatRoomId, userId}` |
| `typing_stop` | `{chatRoomId, userId}` |
| `messages_read` | `{chatRoomId, userId}` |
| `user_status_change` | `{userId, isOnline, lastSeen}` |
| `chat_rooms_update` | `{chatRooms: [...]}` |
| `error` | `{message}` |

## REST Endpoints
| Method | Path | Description |
|---|---|---|
| `POST` | `/upload?type=image\|voice` | Upload chat media. Returns `{url}` |
| `GET` | `/health` | Health check |

## Flutter Integration
Set `kSocketServerUrl` in `lib/service/socket_service.dart` to the server's URL.
