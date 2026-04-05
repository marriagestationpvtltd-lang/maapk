<?php
header("Content-Type: application/json; charset=utf-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Accepts POST fields: myid, userid, like (1=add, 0=remove)
try {
    $dbHost = "127.0.0.1";
    $dbName = "ms";
    $dbUser = "ms";
    $dbPass = "ms";

    $pdo = new PDO(
        "mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4",
        $dbUser,
        $dbPass,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    $sender_id   = isset($_POST['myid'])   ? intval($_POST['myid'])   : 0;
    $receiver_id = isset($_POST['userid']) ? intval($_POST['userid']) : 0;
    $like        = isset($_POST['like'])   ? intval($_POST['like'])   : 1;

    if ($sender_id <= 0 || $receiver_id <= 0) {
        echo json_encode(["success" => false, "message" => "Invalid myid or userid"]);
        exit;
    }

    if ($like == 1) {
        // Add like — prevent duplicate
        $check = $pdo->prepare("SELECT id FROM likes WHERE sender_id = ? AND receiver_id = ? LIMIT 1");
        $check->execute([$sender_id, $receiver_id]);
        if ($check->fetch()) {
            echo json_encode(["status" => "success", "message" => "Already liked", "like" => true]);
            exit;
        }
        $ins = $pdo->prepare("INSERT INTO likes (sender_id, receiver_id) VALUES (?, ?)");
        $ins->execute([$sender_id, $receiver_id]);
        echo json_encode(["status" => "success", "message" => "Liked successfully", "like" => true]);
    } else {
        $del = $pdo->prepare("DELETE FROM likes WHERE sender_id = ? AND receiver_id = ?");
        $del->execute([$sender_id, $receiver_id]);
        echo json_encode(["status" => "success", "message" => "Like removed", "like" => false]);
    }

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
