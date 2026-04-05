<?php
namespace App\Utils;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Database;
use Kreait\Firebase\Database\Reference;
use Kreait\Firebase\Database\Transaction;
use Kreait\Firebase\Exception\DatabaseException;

class FirebaseService {
    private static $instance = null;
    private $database;
    private $auth;
    
    private function __construct() {
        $factory = (new Factory)
            ->withServiceAccount(__DIR__ . '/../../firebase-credentials.json')
            ->withDatabaseUri($_ENV['FIREBASE_DATABASE_URL'] ?? 'https://memorial-chat-default-rtdb.firebaseio.com/');
        
        $this->database = $factory->createDatabase();
        $this->auth = $factory->createAuth();
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Get database reference
     */
    public function getRef($path = '') {
        return $this->database->getReference($path);
    }
    
    /**
     * Send message to Firebase
     */
    public function sendMessage($chatId, $messageData) {
        try {
            $messageId = uniqid('msg_', true);
            
            $messageRef = $this->getRef("chats/{$chatId}/messages/{$messageId}");
            
            $messageData = array_merge($messageData, [
                'id' => $messageId,
                'timestamp' => time() * 1000, // Firebase uses milliseconds
                'createdAt' => date('Y-m-d H:i:s')
            ]);
            
            $messageRef->set($messageData);
            
            // Update chat last message
            $this->getRef("chats/{$chatId}")
                ->update([
                    'lastMessage' => $messageData['text'] ?? 'Media message',
                    'lastMessageTime' => date('H:i A'),
                    'updatedAt' => time() * 1000
                ]);
            
            return $messageId;
        } catch (DatabaseException $e) {
            error_log("Firebase sendMessage error: " . $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Update typing status
     */
    public function setTypingStatus($chatId, $userId, $isTyping) {
        try {
            $this->getRef("chats/{$chatId}/typingStatus/{$userId}")
                ->set($isTyping);
            
            // Auto-clear typing status after 3 seconds
            if ($isTyping) {
                sleep(3);
                $this->getRef("chats/{$chatId}/typingStatus/{$userId}")
                    ->getSnapshot();
                if ($this->getRef("chats/{$chatId}/typingStatus/{$userId}")->getValue() === true) {
                    $this->getRef("chats/{$chatId}/typingStatus/{$userId}")
                        ->set(false);
                }
            }
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase typing status error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Mark message as read
     */
    public function markMessageAsRead($chatId, $messageId, $userId) {
        try {
            $this->getRef("chats/{$chatId}/messages/{$messageId}/readBy/{$userId}")
                ->set([
                    'timestamp' => time() * 1000,
                    'readAt' => date('Y-m-d H:i:s')
                ]);
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase mark as read error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get chat messages with pagination
     */
    public function getMessages($chatId, $limit = 50, $lastMessageId = null) {
        try {
            $messagesRef = $this->getRef("chats/{$chatId}/messages");
            
            $query = $messagesRef
                ->orderByChild('timestamp')
                ->limitToLast($limit);
            
            if ($lastMessageId) {
                $lastMessage = $messagesRef->getChild($lastMessageId)->getSnapshot();
                if ($lastMessage->exists()) {
                    $query = $query->endAt($lastMessage->getValue()['timestamp'] - 1);
                }
            }
            
            $snapshot = $query->getSnapshot();
            $messages = [];
            
            foreach ($snapshot->getValue() as $messageId => $messageData) {
                $messages[$messageId] = $messageData;
            }
            
            // Sort by timestamp ascending
            uasort($messages, function($a, $b) {
                return ($a['timestamp'] ?? 0) <=> ($b['timestamp'] ?? 0);
            });
            
            return array_values($messages);
        } catch (DatabaseException $e) {
            error_log("Firebase getMessages error: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Subscribe to real-time updates
     */
    public function subscribe($path, callable $callback) {
        try {
            $this->getRef($path)
                ->onChildAdded(function ($snapshot) use ($callback) {
                    $callback('child_added', $snapshot->getKey(), $snapshot->getValue());
                });
            
            $this->getRef($path)
                ->onChildChanged(function ($snapshot) use ($callback) {
                    $callback('child_changed', $snapshot->getKey(), $snapshot->getValue());
                });
            
            $this->getRef($path)
                ->onChildRemoved(function ($snapshot) use ($callback) {
                    $callback('child_removed', $snapshot->getKey(), $snapshot->getValue());
                });
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase subscribe error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Create or update user presence
     */
    public function updateUserPresence($userId, $status = 'online', $chatId = null) {
        try {
            $presenceData = [
                'status' => $status,
                'lastOnline' => time() * 1000,
                'updatedAt' => date('Y-m-d H:i:s')
            ];
            
            if ($chatId) {
                $presenceData['currentChat'] = $chatId;
            }
            
            $this->getRef("presence/{$userId}")
                ->set($presenceData);
            
            // Set disconnect cleanup
            $this->getRef("presence/{$userId}")
                ->onDisconnect()
                ->update([
                    'status' => 'offline',
                    'lastOnline' => time() * 1000
                ]);
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase presence error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Create a new chat
     */
    public function createChat($chatData) {
        try {
            $chatId = 'chat_' . uniqid();
            
            $chatRef = $this->getRef("chats/{$chatId}");
            
            $chatData = array_merge($chatData, [
                'id' => $chatId,
                'createdAt' => time() * 1000,
                'updatedAt' => time() * 1000,
                'typingStatus' => [
                    'agent' => false,
                    'contact' => false
                ],
                'lastSeen' => [
                    'agent' => time() * 1000,
                    'contact' => time() * 1000
                ]
            ]);
            
            $chatRef->set($chatData);
            
            return $chatId;
        } catch (DatabaseException $e) {
            error_log("Firebase createChat error: " . $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Delete message (soft delete)
     */
    public function deleteMessage($chatId, $messageId, $deletedBy) {
        try {
            $this->getRef("chats/{$chatId}/messages/{$messageId}")
                ->update([
                    'isDeleted' => true,
                    'deletedBy' => $deletedBy,
                    'deletedAt' => time() * 1000
                ]);
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase deleteMessage error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Edit message
     */
    public function editMessage($chatId, $messageId, $newText, $editedBy) {
        try {
            $this->getRef("chats/{$chatId}/messages/{$messageId}")
                ->update([
                    'text' => $newText,
                    'isEdited' => true,
                    'editedBy' => $editedBy,
                    'editedAt' => time() * 1000
                ]);
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase editMessage error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Get online users
     */
    public function getOnlineUsers($excludeUserId = null) {
        try {
            $presenceRef = $this->getRef('presence');
            $snapshot = $presenceRef->getSnapshot();
            $users = $snapshot->getValue() ?? [];
            
            $onlineUsers = [];
            foreach ($users as $userId => $data) {
                if ($excludeUserId && $userId === $excludeUserId) {
                    continue;
                }
                
                if (($data['status'] ?? 'offline') === 'online') {
                    $onlineUsers[$userId] = $data;
                }
            }
            
            return $onlineUsers;
        } catch (DatabaseException $e) {
            error_log("Firebase getOnlineUsers error: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Start a call
     */
    public function startCall($chatId, $callData) {
        try {
            $callId = 'call_' . uniqid();
            
            $callRef = $this->getRef("calls/{$chatId}/{$callId}");
            
            $callData = array_merge($callData, [
                'id' => $callId,
                'status' => 'ringing',
                'startedAt' => time() * 1000,
                'participants' => [
                    'caller' => $callData['callerId'],
                    'receiver' => $callData['receiverId']
                ]
            ]);
            
            $callRef->set($callData);
            
            // Notify receiver
            $this->getRef("notifications/{$callData['receiverId']}/calls/{$callId}")
                ->set([
                    'chatId' => $chatId,
                    'callType' => $callData['callType'],
                    'callerId' => $callData['callerId'],
                    'timestamp' => time() * 1000
                ]);
            
            return $callId;
        } catch (DatabaseException $e) {
            error_log("Firebase startCall error: " . $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * End a call
     */
    public function endCall($chatId, $callId, $duration) {
        try {
            $this->getRef("calls/{$chatId}/{$callId}")
                ->update([
                    'status' => 'ended',
                    'endedAt' => time() * 1000,
                    'duration' => $duration
                ]);
            
            return true;
        } catch (DatabaseException $e) {
            error_log("Firebase endCall error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Remove expired data (cron job)
     */
    public function cleanupExpiredData($days = 30) {
        try {
            $cutoffTime = time() * 1000 - ($days * 24 * 60 * 60 * 1000);
            
            // Example: Clean old notifications
            $notificationsRef = $this->getRef('notifications');
            $snapshot = $notificationsRef->getSnapshot();
            $notifications = $snapshot->getValue() ?? [];
            
            foreach ($notifications as $userId => $userNotifications) {
                foreach ($userNotifications as $type => $items) {
                    foreach ($items as $itemId => $item) {
                        if (($item['timestamp'] ?? 0) < $cutoffTime) {
                            $this->getRef("notifications/{$userId}/{$type}/{$itemId}")
                                ->remove();
                        }
                    }
                }
            }
            
            return ['cleaned' => true];
        } catch (DatabaseException $e) {
            error_log("Firebase cleanup error: " . $e->getMessage());
            return ['cleaned' => false, 'error' => $e->getMessage()];
        }
    }
    
    /**
     * Batch operations in transaction
     */
    public function batchUpdate($updates) {
        try {
            return $this->database->runTransaction(function (Transaction $transaction) use ($updates) {
                foreach ($updates as $path => $value) {
                    $transaction->set($this->getRef($path), $value);
                }
                return true;
            });
        } catch (DatabaseException $e) {
            error_log("Firebase batch update error: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Create custom token for authentication
     */
    public function createCustomToken($userId, $claims = []) {
        try {
            return $this->auth->createCustomToken($userId, $claims);
        } catch (\Exception $e) {
            error_log("Firebase create token error: " . $e->getMessage());
            return null;
        }
    }
}
?>