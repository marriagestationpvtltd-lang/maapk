<?php
require_once __DIR__ . '/../models/Chat.php';
require_once __DIR__ . '/../utils/Response.php';

class ChatController {
    private $chatModel;
    
    public function __construct() {
        $this->chatModel = new Chat();
    }
    
    public function getAll() {
        $userId = $_SESSION['user_id'];
        $search = $_GET['search'] ?? '';
        $filter = $_GET['filter'] ?? 'all';
        
        $chats = $this->chatModel->getUserChats($userId, $search, $filter);
        
        Response::success(['chats' => $chats]);
    }
    
    public function getById($chatId) {
        $chat = $this->chatModel->findById($chatId);
        
        if (!$chat) {
            Response::error('Chat not found', 404);
            return;
        }
        
        Response::success(['chat' => $chat]);
    }
    
    public function create() {
        $data = json_decode(file_get_contents('php://input'), true);
        $userId = $_SESSION['user_id'];
        
        $required = ['name', 'contact_id'];
        foreach ($required as $field) {
            if (!isset($data[$field]) || empty($data[$field])) {
                Response::error("$field is required", 400);
                return;
            }
        }
        
        $chatId = $this->chatModel->create([
            'name' => $data['name'],
            'contact_id' => $data['contact_id'],
            'avatar_url' => $data['avatar_url'] ?? '',
            'assigned_to' => $userId,
            'membership_status' => $data['membership_status'] ?? 'free'
        ]);
        
        Response::success([
            'chat_id' => $chatId,
            'message' => 'Chat created successfully'
        ], 201);
    }
    
    public function markAsRead($chatId) {
        $success = $this->chatModel->markAsRead($chatId, $_SESSION['user_id']);
        
        if ($success) {
            Response::success(['message' => 'Chat marked as read']);
        } else {
            Response::error('Failed to update chat', 500);
        }
    }
}
?>