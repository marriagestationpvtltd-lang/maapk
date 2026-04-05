<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");

// ---------- DB CONNECTION ----------
try {
    $pdo = new PDO(
        "mysql:host=localhost;dbname=ms;charset=utf8mb4",
        "ms",
        "ms",
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
} catch (PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Database connection failed"
    ]);
    exit;
}

// ---------- INPUT ----------
$userid  = $_GET['userid'] ?? null;
$privacy = $_GET['privacy'] ?? null;

// Validate input
$validPrivacy = ['free', 'paid', 'private', 'verified'];

if (!$userid || !$privacy) {
    echo json_encode([
        "status" => "error",
        "message" => "userid and privacy are required"
    ]);
    exit;
}

if (!in_array(strtolower($privacy), $validPrivacy)) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid privacy value. Allowed: free, paid, private, verified"
    ]);
    exit;
}

try {
    $stmt = $pdo->prepare("
        UPDATE users 
        SET privacy = ? 
        WHERE id = ?
    ");
    $stmt->execute([$privacy, $userid]);

    if ($stmt->rowCount() === 0) {
        echo json_encode([
            "status" => "error",
            "message" => "User not found or privacy already set"
        ]);
        exit;
    }

    echo json_encode([
        "status" => "success",
        "message" => "User privacy updated successfully",
        "data" => [
            "userid" => $userid,
            "privacy" => $privacy
        ]
    ]);
} catch (Exception $e) {
    error_log('privacy.php Exception: ' . $e->getMessage());
    echo json_encode([
        "status" => "error",
        "message" => "Failed to update privacy"
    ]);
}
