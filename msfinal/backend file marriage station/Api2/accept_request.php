<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

$conn = new mysqli("localhost", "ms", "ms", "ms");

if ($conn->connect_error) {
    echo json_encode(["status"=>"error","message"=>"DB connection failed"]);
    exit;
}

$myid = isset($_POST['myid']) ? intval($_POST['myid']) : 0;
$sender_id = isset($_POST['sender_id']) ? intval($_POST['sender_id']) : 0;
$request_type = isset($_POST['request_type']) ? $_POST['request_type'] : '';

if ($myid <= 0 || $sender_id <= 0 || empty($request_type)) {
    echo json_encode(["status"=>"error","message"=>"Invalid params"]);
    exit;
}

// 🔥 Only receiver can accept
$stmt = $conn->prepare("
UPDATE proposals 
SET status='accepted', updated_at=NOW()
WHERE sender_id=? AND receiver_id=? 
AND request_type=? AND status='pending'
ORDER BY id DESC LIMIT 1
");

$stmt->bind_param("iis", $sender_id, $myid, $request_type);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode([
            "status"=>"success",
            "message"=>"Request accepted successfully"
        ]);
    } else {
        echo json_encode([
            "status"=>"error",
            "message"=>"No pending request found"
        ]);
    }
} else {
    echo json_encode([
        "status"=>"error",
        "message"=>"Failed to update request"
    ]);
}

$stmt->close();
$conn->close();
?>