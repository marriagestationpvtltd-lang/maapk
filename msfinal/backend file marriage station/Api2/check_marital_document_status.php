<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Only POST allowed']);
    exit;
}

try {
    $pdo = new PDO(
        "mysql:host=localhost;dbname=ms;charset=utf8mb4",
        "ms",
        "ms",
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$userId = isset($input['user_id']) ? intval($input['user_id']) : null;

if (!$userId) {
    echo json_encode(['success' => false, 'message' => 'user_id is required']);
    exit;
}

try {
    $stmt = $pdo->prepare(
        "SELECT status, reject_reason, created_at FROM user_marital_documents WHERE userid = :uid ORDER BY id DESC LIMIT 1"
    );
    $stmt->execute([':uid' => $userId]);
    $row = $stmt->fetch();

    if (!$row) {
        echo json_encode([
            'success'      => true,
            'status'       => 'not_uploaded',
            'reject_reason'=> '',
            'upload_date'  => null,
            'has_uploaded' => false,
            'message'      => 'No marital document uploaded',
        ]);
        exit;
    }

    echo json_encode([
        'success'      => true,
        'status'       => $row['status'],
        'reject_reason'=> $row['reject_reason'] ?? '',
        'upload_date'  => $row['created_at'],
        'has_uploaded' => true,
        'message'      => 'Marital document found',
    ]);

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
