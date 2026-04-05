<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$conn = new mysqli("localhost", "ms", "ms", "ms");

$input = json_decode(file_get_contents('php://input'), true);
$myId = intval($input['my_id'] ?? 0);
$userId = intval($input['user_id'] ?? 0);

if ($myId <= 0 || $userId <= 0) {
    echo json_encode(["status" => "error", "message" => "Invalid user ID"]);
    exit;
}

// Check if already blocked
$check = $conn->prepare("SELECT id FROM blocks WHERE blocker_id = ? AND blocked_id = ?");
$check->bind_param("ii", $myId, $userId);
$check->execute();
$result = $check->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "User already blocked"]);
    exit;
}

$stmt = $conn->prepare("INSERT INTO blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, NOW())");
$stmt->bind_param("ii", $myId, $userId);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "User blocked"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to block user"]);
}

$stmt->close();
$conn->close();
?>