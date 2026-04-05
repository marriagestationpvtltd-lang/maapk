<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
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
    echo json_encode(["status" => "error", "message" => "Database connection failed"]);
    exit;
}

$userid    = $_GET['userid']    ?? null;
$paidby    = $_GET['paidby']    ?? null;
$packageid = $_GET['packageid'] ?? null;
$status    = $_GET['status']    ?? 'cancelled';

if (!$userid || !$packageid) {
    echo json_encode(["status" => "error", "message" => "userid and packageid are required"]);
    exit;
}

try {
    // Log the cancellation (optional audit table – falls back gracefully if missing)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS payment_cancellations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            userid INT NOT NULL,
            packageid INT NOT NULL,
            paidby VARCHAR(50) DEFAULT NULL,
            status VARCHAR(50) DEFAULT 'cancelled',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (userid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ");

    $stmt = $pdo->prepare(
        "INSERT INTO payment_cancellations (userid, packageid, paidby, status) VALUES (?, ?, ?, ?)"
    );
    $stmt->execute([$userid, $packageid, $paidby, $status]);

    echo json_encode([
        "status"  => "success",
        "message" => "Payment cancellation recorded",
        "data"    => [
            "userid"    => $userid,
            "packageid" => $packageid,
            "status"    => $status,
        ],
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
