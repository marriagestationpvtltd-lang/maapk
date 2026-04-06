<?php
header("Content-Type: application/json");
require 'common_fcm.php';
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Database connection
$host = "localhost";
$db   = "ms";
$user = "ms";
$pass = "ms";

$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
    echo json_encode(["status"=>false,"message"=>"DB connection failed"]);
    exit;
}

// Get parameters for call notification
$user_id = $_POST['user_id'] ?? '';
$title   = $_POST['title'] ?? 'Incoming Call';
$body    = $_POST['body'] ?? '';
$data_json = $_POST['data'] ?? '{}';
$data = json_decode($data_json, true);

// Validate
if (empty($user_id)) {
    echo json_encode(["status"=>false,"message"=>"user_id required"]);
    exit;
}

// Fetch FCM token from users table
$stmt = $conn->prepare("SELECT fcm_token FROM users WHERE id=?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$stmt->bind_result($fcm_token);
$stmt->fetch();
$stmt->close();

if (empty($fcm_token)) {
    echo json_encode(["status"=>false,"message"=>"FCM token not found for user"]);
    exit;
}

// Determine notification type and pick the right channel
$type = $data['type'] ?? '';
$is_call = ($type === 'call' || $type === 'video_call');

if ($is_call) {
    $channel_id = 'calls_channel';
} elseif ($type === 'chat_message' || $type === 'chat') {
    $channel_id = 'messages_channel';
} else {
    $channel_id = 'general_notifications';
}

// Merge click_action and sound into data so Flutter can use them
$notification_data = array_merge($data, [
    "click_action" => "FLUTTER_NOTIFICATION_CLICK",
    "sound" => "default",
]);

// Send FCM
try {
    $response = sendFCM($fcm_token, $title, $body, $notification_data, $channel_id, $is_call);

    echo json_encode([
        "status" => true,
        "response" => $response,
        "data_sent" => $notification_data
    ]);

} catch(Exception $e) {
    echo json_encode(["status"=>false,"error"=>$e->getMessage()]);
}


$conn->close();
?>
