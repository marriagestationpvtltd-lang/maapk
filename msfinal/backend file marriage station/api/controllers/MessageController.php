<?php
require_once __DIR__ . '/../models/Message.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../config/firebase.php';

class MessageController {
    private $messageModel;
    private $firebase;
    
    public function __construct() {
        $this->messageModel = new Message();
        $this->firebase = FirebaseConfig::getDatabase();
    }
    
    public function getByChat($chatId) {
        $userId = $_SESSION['user_id'];
        $page = $_GET['page'] ?? 1;
        $limit = $_GET['limit'] ?? 50;
        
        // Verify user has access to this chat
        if (!$this->messageModel->hasAccess($chatId, $userId)) {
            Response::error('Access denied', 403);
            return;
        }
        
        $messages = $this->messageModel->getByChat($chatId, $page, $limit);
        
        Response::success(['messages' => $messages]);
    }
    
    public function send() {
        $data = json_decode(file_get_contents('php://input'), true);
        $userId = $_SESSION['user_id'];
        
        if (!isset($data['chat_id']) || !isset($data['text'])) {
            Response::error('Chat ID and text are required', 400);
            return;
        }
        
        // Save to MySQL
        $messageId = $this->messageModel->create([
            'chat_id' => $data['chat_id'],
            'sender_id' => $userId,
            'sender_type' => 'agent',
            'text_content' => $data['text'],
            'message_type' => $data['type'] ?? 'text',
            'shared_profile_id' => $data['shared_profile_id'] ?? null
        ]);
        
        // Save to Firebase for real-time
        $firebaseData = [
            'messageId' => $messageId,
            'text' => $data['text'],
            'senderId' => $userId,
            'senderType' => 'agent',
            'type' => $data['type'] ?? 'text',
            'createdAt' => time() * 1000,
            'isRead' => false
        ];
        
        if (isset($data['shared_profile_id'])) {
            $firebaseData['sharedProfileId'] = $data['shared_profile_id'];
        }
        
        $this->firebase
            ->getReference("chats/{$data['chat_id']}/messages")
            ->push($firebaseData);
        
        // Update chat last message
        $this->messageModel->updateChatLastMessage(
            $data['chat_id'],
            $data['text'],
            date('H:i A')
        );
        
        Response::success([
            'message_id' => $messageId,
            'message' => 'Message sent'
        ], 201);
    }
    
    public function update($messageId) {
        $data = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($data['text'])) {
            Response::error('Text is required', 400);
            return;
        }
        
        $success = $this->messageModel->update($messageId, [
            'text_content' => $data['text'],
            'is_edited' => true
        ]);
        
        if ($success) {
            Response::success(['message' => 'Message updated']);
        } else {
            Response::error('Failed to update message', 500);
        }
    }
    
    public function delete($messageId) {
        $success = $this->messageModel->softDelete($messageId);
        
        if ($success) {
            Response::success(['message' => 'Message deleted']);
        } else {
            Response::error('Failed to delete message', 500);
        }
    }
}
?>