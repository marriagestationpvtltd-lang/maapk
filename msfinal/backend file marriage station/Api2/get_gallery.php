<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$host     = "localhost";
$dbname   = "ms";
$username = "ms";
$password = "ms";

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database connection failed"]);
    exit;
}

$userid = isset($_GET['userid']) ? intval($_GET['userid']) : 0;
if ($userid <= 0) {
    echo json_encode(["status" => "error", "message" => "Invalid userid"]);
    exit;
}

try {
    // Fetch approved gallery images for the user
    $stmt = $pdo->prepare("SELECT id, userid, imageurl, status, created_at FROM user_gallery WHERE userid = ? AND status = 'approved' ORDER BY created_at DESC");
    $stmt->execute([$userid]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "status"  => "success",
        "gallery" => $rows,
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
