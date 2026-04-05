<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once 'database.php';

$data = json_decode(file_get_contents("php://input"));

if (!empty($data->user_id)) {
    $database = new Database();
    $db = $database->getConnection();
    
    // Check if settings exist for user
    $check_query = "SELECT id FROM user_notification_settings WHERE user_id = :user_id";
    $check_stmt = $db->prepare($check_query);
    $check_stmt->bindParam(':user_id', $data->user_id);
    $check_stmt->execute();
    
    if ($check_stmt->rowCount() > 0) {
        // Update existing settings
        $query = "UPDATE user_notification_settings SET 
                  push_enabled = :push_enabled,
                  email_enabled = :email_enabled,
                  sms_enabled = :sms_enabled
                  WHERE user_id = :user_id";
    } else {
        // Insert new settings
        $query = "INSERT INTO user_notification_settings 
                  (user_id, push_enabled, email_enabled, sms_enabled) 
                  VALUES (:user_id, :push_enabled, :email_enabled, :sms_enabled)";
    }
    
    $stmt = $db->prepare($query);
    
    // Bind parameters
    $stmt->bindParam(':user_id', $data->user_id);
    $stmt->bindParam(':push_enabled', $data->push_enabled, PDO::PARAM_INT);
    $stmt->bindParam(':email_enabled', $data->email_enabled, PDO::PARAM_INT);
    $stmt->bindParam(':sms_enabled', $data->sms_enabled, PDO::PARAM_INT);
    
    if ($stmt->execute()) {
        http_response_code(200);
        echo json_encode(array("message" => "Notification settings updated successfully."));
    } else {
        http_response_code(503);
        echo json_encode(array("message" => "Unable to update notification settings."));
    }
} else {
    http_response_code(400);
    echo json_encode(array("message" => "User ID is required."));
}
?>