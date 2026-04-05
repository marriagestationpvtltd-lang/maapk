<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$conn = new mysqli("localhost", "ms", "ms", "ms");

$input = json_decode(file_get_contents('php://input'), true);
$myId = intval($input['my_id'] ?? 0);
$userId = intval($input['user_id'] ?? 0);

if ($myId <= 0 || $userId <= 0) {
    echo json_encode(["status" => "error", "is_blocked" => false]);
    exit;
}

$stmt = $conn->prepare("SELECT id FROM blocks WHERE blocker_id = ? AND blocked_id = ?");
$stmt->bind_param("ii", $myId, $userId);
$stmt->execute();
$result = $stmt->get_result();

echo json_encode([
    "status" => "success",
    "is_blocked" => $result->num_rows > 0
]);

$stmt->close();
$conn->close();
?>