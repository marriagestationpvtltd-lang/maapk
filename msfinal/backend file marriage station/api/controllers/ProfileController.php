<?php
require_once __DIR__ . '/../models/Profile.php';
require_once __DIR__ . '/../utils/Response.php';

class ProfileController {
    private $profileModel;
    
    public function __construct() {
        $this->profileModel = new Profile();
    }
    
    public function getAll() {
        $search = $_GET['search'] ?? '';
        $filter = $_GET['filter'] ?? 'all';
        $page = $_GET['page'] ?? 1;
        $perPage = $_GET['per_page'] ?? 10;
        
        $profiles = $this->profileModel->getAll($search, $filter, $page, $perPage);
        $total = $this->profileModel->getCount($search, $filter);
        
        Response::success([
            'profiles' => $profiles,
            'total' => $total,
            'page' => $page,
            'per_page' => $perPage,
            'has_more' => ($page * $perPage) < $total
        ]);
    }
    
    public function getByChat($chatId) {
        $profiles = $this->profileModel->getByChat($chatId);
        
        Response::success(['profiles' => $profiles]);
    }
    
    public function share() {
        $data = json_decode(file_get_contents('php://input'), true);
        $userId = $_SESSION['user_id'];
        
        if (!isset($data['chat_id']) || !isset($data['profile_id'])) {
            Response::error('Chat ID and Profile ID are required', 400);
            return;
        }
        
        $shareId = $this->profileModel->share(
            $data['chat_id'],
            $data['profile_id'],
            $userId
        );
        
        Response::success([
            'share_id' => $shareId,
            'message' => 'Profile shared successfully'
        ], 201);
    }
    
    public function updateStatus($profileId) {
        $data = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($data['status'])) {
            Response::error('Status is required', 400);
            return;
        }
        
        $success = $this->profileModel->updateStatus(
            $profileId,
            $_SESSION['user_id'],
            $data['status']
        );
        
        if ($success) {
            Response::success(['message' => 'Status updated']);
        } else {
            Response::error('Failed to update status', 500);
        }
    }
}
?>