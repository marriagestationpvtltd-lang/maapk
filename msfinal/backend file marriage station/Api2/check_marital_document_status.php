<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$host     = 'localhost';
$dbname   = 'ms';
$username = 'ms';
$password = 'ms';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $e->getMessage()]);
    exit;
}

// Ensure marital_documents table exists
$pdo->exec("
    CREATE TABLE IF NOT EXISTS marital_documents (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userid INT NOT NULL,
        documenttype VARCHAR(100),
        documentidnumber VARCHAR(100),
        photo VARCHAR(255),
        status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
        reject_reason VARCHAR(255) DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (userid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$input  = json_decode(file_get_contents('php://input'), true);
$userId = isset($input['user_id']) ? intval($input['user_id']) : null;

if (!$userId) {
    echo json_encode(['success' => false, 'message' => 'User ID is required']);
    exit;
}

try {
    $stmt = $pdo->prepare("SELECT status, reject_reason, created_at FROM marital_documents WHERE userid = :uid ORDER BY id DESC LIMIT 1");
    $stmt->execute([':uid' => $userId]);
    $doc = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$doc) {
        echo json_encode([
            'success'      => true,
            'status'       => 'not_uploaded',
            'reject_reason'=> '',
            'upload_date'  => null,
            'has_uploaded' => false,
            'message'      => 'No document uploaded',
        ]);
        exit;
    }

    echo json_encode([
        'success'      => true,
        'status'       => $doc['status'],
        'reject_reason'=> $doc['reject_reason'] ?? '',
        'upload_date'  => $doc['created_at'] ?? null,
        'has_uploaded' => true,
        'message'      => 'Document found',
    ]);

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
