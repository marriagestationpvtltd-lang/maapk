'use strict';

require('dotenv').config();
const express   = require('express');
const http      = require('http');
const { Server } = require('socket.io');
const mysql     = require('mysql2/promise');
const cors      = require('cors');
const multer    = require('multer');
const path      = require('path');
const fs        = require('fs');
const { v4: uuidv4 } = require('uuid');

// ──────────────────────────────────────────────────────────────────────────────
// Configuration
// ──────────────────────────────────────────────────────────────────────────────
const PORT        = process.env.PORT || 3001;
const UPLOAD_DIR  = process.env.UPLOAD_DIR || './uploads';
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '*').split(',').map(s => s.trim());

// Ensure upload directory exists
['chat_images', 'voice_messages'].forEach(sub => {
  const dir = path.join(UPLOAD_DIR, sub);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// ──────────────────────────────────────────────────────────────────────────────
// MySQL connection pool
// ──────────────────────────────────────────────────────────────────────────────
const pool = mysql.createPool({
  host:               process.env.DB_HOST     || 'localhost',
  port:               parseInt(process.env.DB_PORT || '3306'),
  user:               process.env.DB_USER     || 'root',
  password:           process.env.DB_PASSWORD || '',
  database:           process.env.DB_NAME     || 'marriagestation',
  waitForConnections: true,
  connectionLimit:    20,
  charset:            'utf8mb4',
});

// Test DB connection on startup and run safe schema migrations
pool.getConnection()
  .then(async conn => {
    console.log('✅ MySQL connected');
    // Add `liked` column to chat_messages if not present (idempotent migration).
    // Check INFORMATION_SCHEMA for compatibility with MySQL 5.7, MariaDB, and MySQL 8+.
    const dbName = process.env.DB_NAME || 'marriagestation';
    const [[col]] = await conn.query(
      `SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'chat_messages' AND COLUMN_NAME = 'liked'
        LIMIT 1`,
      [dbName],
    );
    if (!col) {
      await conn.query(
        `ALTER TABLE chat_messages ADD COLUMN liked TINYINT(1) NOT NULL DEFAULT 0`
      );
      console.log('✅ Added liked column to chat_messages');
    }
    conn.release();
  })
  .catch(err => { console.error('❌ MySQL connection failed:', err.message); });

// ──────────────────────────────────────────────────────────────────────────────
// Express + Socket.IO setup
// ──────────────────────────────────────────────────────────────────────────────
const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: {
    origin: ALLOWED_ORIGINS.includes('*') ? '*' : ALLOWED_ORIGINS,
    methods: ['GET', 'POST'],
  },
  pingTimeout:  60000,
  pingInterval: 25000,
});

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(UPLOAD_DIR));

// ──────────────────────────────────────────────────────────────────────────────
// File upload (multer)
// ──────────────────────────────────────────────────────────────────────────────
const storage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const type = req.query.type || 'chat_images';
    cb(null, path.join(UPLOAD_DIR, type === 'voice' ? 'voice_messages' : 'chat_images'));
  },
  filename: (_req, file, cb) => {
    const ext  = path.extname(file.originalname) || '.jpg';
    cb(null, `${uuidv4()}${ext}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 25 * 1024 * 1024 } }); // 25 MB

// POST /upload?type=image|voice
app.post('/upload', upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const subDir = req.query.type === 'voice' ? 'voice_messages' : 'chat_images';
  const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${subDir}/${req.file.filename}`;
  res.json({ url: fileUrl });
});

// GET /health
app.get('/health', (_req, res) => res.json({ status: 'ok', time: new Date() }));

// ──────────────────────────────────────────────────────────────────────────────
// In-memory maps: userId → socketId, userId → Set<chatRoomId>
// ──────────────────────────────────────────────────────────────────────────────
const userSockets    = new Map(); // userId → socketId
const userActiveChatRoom = new Map(); // userId → chatRoomId | null

// ──────────────────────────────────────────────────────────────────────────────
// DB helpers
// ──────────────────────────────────────────────────────────────────────────────

async function ensureChatRoom({ chatRoomId, user1Id, user2Id, user1Name, user2Name, user1Image, user2Image }) {
  const [rows] = await pool.query('SELECT id FROM chat_rooms WHERE id = ?', [chatRoomId]);
  if (rows.length) return;

  await pool.query(
    `INSERT INTO chat_rooms
       (id, participants, participant_names, participant_images, last_message, last_message_type, last_message_time, last_message_sender_id)
     VALUES (?, ?, ?, ?, '', 'text', NOW(), '')`,
    [
      chatRoomId,
      JSON.stringify([user1Id, user2Id]),
      JSON.stringify({ [user1Id]: user1Name, [user2Id]: user2Name }),
      JSON.stringify({ [user1Id]: user1Image, [user2Id]: user2Image }),
    ],
  );

  // Initialise unread counters
  await pool.query(
    'INSERT IGNORE INTO chat_unread_counts (chat_room_id, user_id, unread_count) VALUES (?,?,0),(?,?,0)',
    [chatRoomId, user1Id, chatRoomId, user2Id],
  );
}

async function saveMessage(msg) {
  await pool.query(
    `INSERT INTO chat_messages
       (message_id, chat_room_id, sender_id, receiver_id, message, message_type,
        is_read, is_delivered, replied_to, created_at, liked)
     VALUES (?,?,?,?,?,?,?,?,?,?,0)`,
    [
      msg.messageId,
      msg.chatRoomId,
      msg.senderId,
      msg.receiverId,
      msg.message || '',
      msg.messageType || 'text',
      msg.isRead    ? 1 : 0,
      msg.isDelivered ? 1 : 0,
      msg.repliedTo ? JSON.stringify(msg.repliedTo) : null,
      msg.timestamp ? new Date(msg.timestamp) : new Date(),
    ],
  );
}

async function updateChatRoomLastMessage({ chatRoomId, message, messageType, senderId, receiverId, isReceiverViewing }) {
  await pool.query(
    `UPDATE chat_rooms
        SET last_message = ?, last_message_type = ?, last_message_time = NOW(), last_message_sender_id = ?
      WHERE id = ?`,
    [message, messageType || 'text', senderId, chatRoomId],
  );

  if (!isReceiverViewing) {
    await pool.query(
      `INSERT INTO chat_unread_counts (chat_room_id, user_id, unread_count)
         VALUES (?, ?, 1)
       ON DUPLICATE KEY UPDATE unread_count = unread_count + 1`,
      [chatRoomId, receiverId],
    );
  }
}

async function getChatRooms(userId) {
  const [rooms] = await pool.query(
    `SELECT cr.*,
            COALESCE(uc.unread_count, 0) AS unread_count
       FROM chat_rooms cr
       LEFT JOIN chat_unread_counts uc ON uc.chat_room_id = cr.id AND uc.user_id = ?
      WHERE JSON_CONTAINS(cr.participants, JSON_QUOTE(?))
      ORDER BY cr.last_message_time DESC`,
    [userId, userId],
  );
  return rooms.map(r => ({
    chatRoomId:          r.id,
    participants:        JSON.parse(r.participants),
    participantNames:    JSON.parse(r.participant_names),
    participantImages:   JSON.parse(r.participant_images),
    lastMessage:         r.last_message,
    lastMessageType:     r.last_message_type,
    lastMessageTime:     r.last_message_time,
    lastMessageSenderId: r.last_message_sender_id,
    unreadCount:         r.unread_count,
  }));
}

async function getMessages({ chatRoomId, page = 1, limit = 20 }) {
  const offset = (page - 1) * limit;
  const [rows] = await pool.query(
    `SELECT * FROM chat_messages
      WHERE chat_room_id = ?
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?`,
    [chatRoomId, limit + 1, offset],
  );
  const hasMore = rows.length > limit;
  const messages = rows.slice(0, limit).reverse().map(toMessageMap);
  return { messages, hasMore, page };
}

async function markMessagesRead({ chatRoomId, userId }) {
  await pool.query(
    'UPDATE chat_unread_counts SET unread_count = 0 WHERE chat_room_id = ? AND user_id = ?',
    [chatRoomId, userId],
  );
  await pool.query(
    `UPDATE chat_messages
        SET is_read = 1, is_delivered = 1
      WHERE chat_room_id = ? AND receiver_id = ? AND (is_read = 0 OR is_delivered = 0)`,
    [chatRoomId, userId],
  );
}

async function editMessage({ chatRoomId, messageId, newMessage }) {
  await pool.query(
    `UPDATE chat_messages
        SET message = ?, is_edited = 1, edited_at = NOW()
      WHERE message_id = ? AND chat_room_id = ?`,
    [newMessage, messageId, chatRoomId],
  );
  // Update last_message if it was the last one
  await pool.query(
    `UPDATE chat_rooms cr
        SET last_message = ?
      WHERE cr.id = ?
        AND last_message_sender_id = (
              SELECT sender_id FROM chat_messages WHERE message_id = ? LIMIT 1
            )
        AND last_message_time = (
              SELECT MAX(created_at) FROM chat_messages WHERE chat_room_id = ?
            )`,
    [newMessage, chatRoomId, messageId, chatRoomId],
  );
}

async function deleteMessage({ chatRoomId, messageId, userId, deleteForEveryone }) {
  if (deleteForEveryone) {
    await pool.query(
      'DELETE FROM chat_messages WHERE message_id = ? AND chat_room_id = ?',
      [messageId, chatRoomId],
    );
  } else {
    // Determine if user is sender or receiver
    const [rows] = await pool.query(
      'SELECT sender_id FROM chat_messages WHERE message_id = ?',
      [messageId],
    );
    if (!rows.length) return;
    const senderIdStr = rows[0].sender_id != null ? rows[0].sender_id.toString() : '';
    const userIdStr   = userId != null ? userId.toString() : '';
    const isSender    = senderIdStr === userIdStr;
    // Use a strict whitelist to avoid any SQL injection risk from the field name.
    const field = isSender ? 'is_deleted_for_sender' : 'is_deleted_for_receiver';
    const allowedFields = ['is_deleted_for_sender', 'is_deleted_for_receiver'];
    if (!allowedFields.includes(field)) return; // should never happen, but guard anyway
    await pool.query(
      `UPDATE chat_messages SET ${field} = 1 WHERE message_id = ? AND chat_room_id = ?`,
      [messageId, chatRoomId],
    );
  }
}

async function upsertOnlineStatus(userId, isOnline, activeChatRoomId = null) {
  await pool.query(
    `INSERT INTO user_online_status (user_id, is_online, last_seen, active_chat_room_id)
       VALUES (?, ?, NOW(), ?)
     ON DUPLICATE KEY UPDATE
       is_online           = VALUES(is_online),
       last_seen           = IF(VALUES(is_online) = 0, NOW(), last_seen),
       active_chat_room_id = VALUES(active_chat_room_id)`,
    [userId, isOnline ? 1 : 0, activeChatRoomId],
  );
}

// Convert a DB row to the format Flutter expects (mirrors Firestore document shape)
function toMessageMap(row) {
  return {
    messageId:             row.message_id,
    chatRoomId:            row.chat_room_id,
    senderId:              row.sender_id,
    receiverId:            row.receiver_id,
    message:               row.message,
    messageType:           row.message_type,
    isRead:                row.is_read === 1,
    isDelivered:           row.is_delivered === 1,
    isDeletedForSender:    row.is_deleted_for_sender === 1,
    isDeletedForReceiver:  row.is_deleted_for_receiver === 1,
    isEdited:              row.is_edited === 1,
    editedAt:              row.edited_at ? row.edited_at.toISOString() : null,
    repliedTo:             row.replied_to ? JSON.parse(row.replied_to) : null,
    timestamp:             row.created_at ? row.created_at.toISOString() : null,
    liked:                 row.liked === 1,
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// Socket.IO events
// ──────────────────────────────────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`🔌 Socket connected: ${socket.id}`);
  let authenticatedUserId = null;

  // ── authenticate ──────────────────────────────────────────────────────────
  socket.on('authenticate', async ({ userId }) => {
    if (!userId) return;
    authenticatedUserId = userId.toString();
    userSockets.set(authenticatedUserId, socket.id);

    // Join a personal room so we can push status changes to this user
    socket.join(`user:${authenticatedUserId}`);

    await upsertOnlineStatus(authenticatedUserId, true);

    // Notify the user's contacts that they are online
    socket.broadcast.emit('user_status_change', {
      userId:   authenticatedUserId,
      isOnline: true,
      lastSeen: new Date().toISOString(),
    });

    socket.emit('authenticated', { success: true, userId: authenticatedUserId });
    console.log(`✅ Authenticated: userId=${authenticatedUserId}`);
  });

  // ── join_room ─────────────────────────────────────────────────────────────
  socket.on('join_room', ({ chatRoomId }) => {
    if (chatRoomId) socket.join(chatRoomId);
  });

  // ── leave_room ────────────────────────────────────────────────────────────
  socket.on('leave_room', ({ chatRoomId }) => {
    if (chatRoomId) socket.leave(chatRoomId);
  });

  // ── set_active_chat ───────────────────────────────────────────────────────
  socket.on('set_active_chat', async ({ userId, chatRoomId, isActive }) => {
    const uid = (userId || authenticatedUserId || '').toString();
    if (!uid) return;

    const activeChatRoomId = isActive && chatRoomId ? chatRoomId : null;
    userActiveChatRoom.set(uid, activeChatRoomId);
    await upsertOnlineStatus(uid, true, activeChatRoomId);
  });

  // ── send_message ──────────────────────────────────────────────────────────
  socket.on('send_message', async (data) => {
    try {
      const {
        chatRoomId, senderId, receiverId,
        message, messageType = 'text',
        messageId = uuidv4(),
        repliedTo, isReceiverViewing = false,
        user1Name, user2Name, user1Image, user2Image,
      } = data;

      if (!chatRoomId || !senderId || !receiverId) return;

      // Resolve names/images from data or use empty defaults
      const names  = { [senderId]: user1Name || '', [receiverId]: user2Name || '' };
      const images = { [senderId]: user1Image || '', [receiverId]: user2Image || '' };

      await ensureChatRoom({
        chatRoomId,
        user1Id: senderId,    user2Id: receiverId,
        user1Name: names[senderId],  user2Name: names[receiverId],
        user1Image: images[senderId], user2Image: images[receiverId],
      });

      const timestamp = new Date().toISOString();
      const isReceiverCurrentlyViewing = isReceiverViewing ||
        userActiveChatRoom.get(receiverId.toString()) === chatRoomId;

      const msgDoc = {
        messageId, chatRoomId, senderId, receiverId,
        message:    message || '',
        messageType,
        timestamp,
        isRead:                isReceiverCurrentlyViewing,
        isDelivered:           isReceiverCurrentlyViewing,
        isDeletedForSender:    false,
        isDeletedForReceiver:  false,
        repliedTo:             repliedTo || null,
      };

      await saveMessage(msgDoc);
      await updateChatRoomLastMessage({
        chatRoomId, message: message || '', messageType,
        senderId, receiverId,
        isReceiverViewing: isReceiverCurrentlyViewing,
      });

      // Broadcast to all room members (including sender for confirmation)
      io.to(chatRoomId).emit('new_message', msgDoc);

      // Update chat-list for both participants
      const rooms1 = await getChatRooms(senderId);
      io.to(`user:${senderId}`).emit('chat_rooms_update', { chatRooms: rooms1 });

      const rooms2 = await getChatRooms(receiverId);
      io.to(`user:${receiverId}`).emit('chat_rooms_update', { chatRooms: rooms2 });

    } catch (err) {
      console.error('send_message error:', err.message);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  // ── get_messages ──────────────────────────────────────────────────────────
  socket.on('get_messages', async ({ chatRoomId, page = 1, limit = 20 }, ack) => {
    try {
      const result = await getMessages({ chatRoomId, page, limit });
      if (typeof ack === 'function') ack({ success: true, ...result });
    } catch (err) {
      console.error('get_messages error:', err.message);
      if (typeof ack === 'function') ack({ success: false, error: err.message });
    }
  });

  // ── get_chat_rooms ────────────────────────────────────────────────────────
  socket.on('get_chat_rooms', async ({ userId }, ack) => {
    try {
      const uid = (userId || authenticatedUserId || '').toString();
      if (!uid) { if (typeof ack === 'function') ack({ success: false, error: 'No userId' }); return; }
      const chatRooms = await getChatRooms(uid);
      if (typeof ack === 'function') ack({ success: true, chatRooms });
    } catch (err) {
      console.error('get_chat_rooms error:', err.message);
      if (typeof ack === 'function') ack({ success: false, error: err.message });
    }
  });

  // ── typing_start ──────────────────────────────────────────────────────────
  socket.on('typing_start', ({ chatRoomId, userId }) => {
    if (!chatRoomId || !userId) return;
    socket.to(chatRoomId).emit('typing_start', { chatRoomId, userId });
  });

  // ── typing_stop ───────────────────────────────────────────────────────────
  socket.on('typing_stop', ({ chatRoomId, userId }) => {
    if (!chatRoomId || !userId) return;
    socket.to(chatRoomId).emit('typing_stop', { chatRoomId, userId });
  });

  // ── mark_read ─────────────────────────────────────────────────────────────
  socket.on('mark_read', async ({ chatRoomId, userId }) => {
    try {
      if (!chatRoomId || !userId) return;
      await markMessagesRead({ chatRoomId, userId });

      // Notify sender that their messages were read
      socket.to(chatRoomId).emit('messages_read', { chatRoomId, userId });

      // Refresh chat list for this user
      const rooms = await getChatRooms(userId);
      socket.emit('chat_rooms_update', { chatRooms: rooms });
    } catch (err) {
      console.error('mark_read error:', err.message);
    }
  });

  // ── edit_message ──────────────────────────────────────────────────────────
  socket.on('edit_message', async ({ chatRoomId, messageId, newMessage }) => {
    try {
      if (!chatRoomId || !messageId || !newMessage) return;
      await editMessage({ chatRoomId, messageId, newMessage });
      const editedAt = new Date().toISOString();
      io.to(chatRoomId).emit('message_edited', { chatRoomId, messageId, newMessage, editedAt });
    } catch (err) {
      console.error('edit_message error:', err.message);
      socket.emit('error', { message: 'Failed to edit message' });
    }
  });

  // ── delete_message ────────────────────────────────────────────────────────
  socket.on('delete_message', async ({ chatRoomId, messageId, userId, deleteForEveryone }) => {
    try {
      if (!chatRoomId || !messageId) return;
      await deleteMessage({ chatRoomId, messageId, userId, deleteForEveryone });
      io.to(chatRoomId).emit('message_deleted', { chatRoomId, messageId, deleteForEveryone, userId });
    } catch (err) {
      console.error('delete_message error:', err.message);
      socket.emit('error', { message: 'Failed to delete message' });
    }
  });

  // ── toggle_like ───────────────────────────────────────────────────────────
  socket.on('toggle_like', async ({ chatRoomId, messageId }) => {
    try {
      if (!chatRoomId || !messageId) return;
      if (!authenticatedUserId) return; // Require authentication

      // Verify the authenticated user is a participant in the chat room
      const [[room]] = await pool.query(
        `SELECT 1 FROM chat_rooms
          WHERE chat_room_id = ?
            AND (user1_id = ? OR user2_id = ?)
          LIMIT 1`,
        [chatRoomId, authenticatedUserId, authenticatedUserId],
      );
      if (!room) return; // Not a participant — silently ignore

      // Flip the liked flag atomically
      await pool.query(
        `UPDATE chat_messages SET liked = IF(liked = 1, 0, 1)
          WHERE message_id = ? AND chat_room_id = ?`,
        [messageId, chatRoomId],
      );
      const [[row]] = await pool.query(
        'SELECT liked FROM chat_messages WHERE message_id = ?',
        [messageId],
      );
      if (row) {
        io.to(chatRoomId).emit('message_liked', {
          chatRoomId,
          messageId,
          liked: row.liked === 1,
        });
      }
    } catch (err) {
      console.error('toggle_like error:', err.message);
    }
  });

  // ── disconnect ────────────────────────────────────────────────────────────
  socket.on('disconnect', async () => {
    console.log(`🔌 Socket disconnected: ${socket.id}`);
    if (!authenticatedUserId) return;

    userSockets.delete(authenticatedUserId);
    userActiveChatRoom.delete(authenticatedUserId);

    await upsertOnlineStatus(authenticatedUserId, false);

    // Notify contacts
    socket.broadcast.emit('user_status_change', {
      userId:   authenticatedUserId,
      isOnline: false,
      lastSeen: new Date().toISOString(),
    });
  });
});

// ──────────────────────────────────────────────────────────────────────────────
// Start server
// ──────────────────────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`🚀 Socket.IO server running on port ${PORT}`);
});
