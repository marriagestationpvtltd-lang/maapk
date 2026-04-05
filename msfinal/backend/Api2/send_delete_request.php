<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$conn = new mysqli("localhost", "ms", "ms", "ms");
if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "DB Connection failed"]);
    exit;
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);
if (empty($data)) {
    $data = $_POST;
}

$userid = intval($data['userid'] ?? 0);
$delete_reason = substr(trim($data['delete_reason'] ?? ''), 0, 500);
$feedback = substr(trim($data['feedback'] ?? ''), 0, 1000);

if ($userid <= 0) {
    echo json_encode(["status" => "error", "message" => "Invalid user ID"]);
    exit;
}

try {
    // Disable foreign key checks
    $conn->query("SET FOREIGN_KEY_CHECKS = 0");

    // Log deletion
    $stmt_log = $conn->prepare("INSERT INTO deletion_log (userid, reason, feedback, deleted_at) VALUES (?, ?, ?, NOW())");
    $stmt_log->bind_param("iss", $userid, $delete_reason, $feedback);
    $stmt_log->execute();
    $stmt_log->close();

    // Delete from userblock
    $stmt_block = $conn->prepare("DELETE FROM userblock WHERE userId = ? OR userBlockId = ?");
    $stmt_block->bind_param("ii", $userid, $userid);
    $stmt_block->execute();
    $stmt_block->close();

    // Delete the user
    $stmt_user = $conn->prepare("DELETE FROM users WHERE id = ?");
    $stmt_user->bind_param("i", $userid);
    $stmt_user->execute();
    $stmt_user->close();

    // Re-enable foreign key checks
    $conn->query("SET FOREIGN_KEY_CHECKS = 1");
    
    echo json_encode([
        "status" => "success",
        "message" => "Your account has been permanently deleted"
    ]);
    
} catch (Exception $e) {
    $conn->query("SET FOREIGN_KEY_CHECKS = 1");
    echo json_encode([
        "status" => "error",
        "message" => "Failed to delete account: " . $e->getMessage()
    ]);
}

$conn->close();
?>