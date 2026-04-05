<?php
// ================= CORS =================
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ================= DB CONFIG =================
define('DB_HOST', 'localhost');
define('DB_NAME', 'ms');
define('DB_USER', 'ms');
define('DB_PASS', 'ms');

$input = json_decode(file_get_contents("php://input"), true);

$userId = $input['user_id'] ?? null;
$action = $input['action'] ?? null;
$rejectReason = trim($input['reject_reason'] ?? '');

if (!$userId || !$action) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => 'user_id and action are required'
    ]);
    exit;
}

try {
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME,
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Check user exists
    $check = $pdo->prepare("SELECT id FROM users WHERE id = ?");
    $check->execute([$userId]);

    if (!$check->fetch()) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'User not found'
        ]);
        exit;
    }

    // ================= APPROVE =================
    if ($action === 'approve') {

        $stmt = $pdo->prepare("
            UPDATE users
            SET 
                status = 'approved',
                isVerified = 1,
                reject_reason = NULL
            WHERE id = ?
        ");
        $stmt->execute([$userId]);

        echo json_encode([
            'success' => true,
            'message' => 'User approved and verified successfully'
        ]);
        exit;
    }

    // ================= REJECT =================
    if ($action === 'reject') {

        if ($rejectReason === '') {
            http_response_code(422);
            echo json_encode([
                'success' => false,
                'message' => 'Reject reason is required'
            ]);
            exit;
        }

        $stmt = $pdo->prepare("
            UPDATE users
            SET 
                status = 'rejected',
                isVerified = 0,
                reject_reason = ?
            WHERE id = ?
        ");
        $stmt->execute([$rejectReason, $userId]);

        echo json_encode([
            'success' => true,
            'message' => 'User rejected successfully'
        ]);
        exit;
    }

    // ================= INVALID =================
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid action'
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error'
    ]);
}
