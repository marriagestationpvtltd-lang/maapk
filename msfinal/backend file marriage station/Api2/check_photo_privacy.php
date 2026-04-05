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
    echo json_encode(["show_blur" => true, "has_requested" => false, "message" => "Invalid userid"]);
    exit;
}

try {
    // Get privacy setting from users table
    $stmt = $pdo->prepare("SELECT privacy FROM users WHERE id = ?");
    $stmt->execute([$userid]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode(["show_blur" => false, "has_requested" => false]);
        exit;
    }

    $privacy   = $user['privacy'] ?? 'private';
    $show_blur = ($privacy !== 'free');

    echo json_encode([
        "show_blur"     => $show_blur,
        "has_requested" => false,
        "privacy"       => $privacy,
    ]);

} catch (PDOException $e) {
    echo json_encode(["show_blur" => true, "has_requested" => false]);
}
?>
