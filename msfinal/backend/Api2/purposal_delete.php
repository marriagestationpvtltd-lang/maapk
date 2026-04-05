<?php
header("Content-Type: application/json");

// DB CONNECTION
$host = "localhost";
$user = "ms";
$pass = "ms";
$dbname = "ms";

$conn = new mysqli($host, $user, $pass, $dbname);
if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "DB connection failed"]);
    exit;
}

// CHECK REQUIRED PARAMS
if (!isset($_POST['user_id']) || !isset($_POST['proposal_id'])) {
    echo json_encode(["status" => "error", "message" => "Missing parameters"]);
    exit;
}

$user_id = intval($_POST['user_id']);
$proposal_id = intval($_POST['proposal_id']);

// CHECK IF PROPOSAL EXISTS AND BELONGS TO USER
$stmt_check = $conn->prepare("SELECT id FROM proposals 
              WHERE id = ? 
              AND (
                    sender_id = ? 
                    OR receiver_id = ?
                  )
              AND status IN ('pending','rejected')");
$stmt_check->bind_param("iii", $proposal_id, $user_id, $user_id);
$stmt_check->execute();
$result = $stmt_check->get_result();
$stmt_check->close();

if ($result->num_rows == 0) {
    echo json_encode(["status" => "error", "message" => "Proposal not found or cannot be deleted"]);
    exit;
}

// DELETE PROPOSAL
$stmt_delete = $conn->prepare("DELETE FROM proposals WHERE id = ?");
$stmt_delete->bind_param("i", $proposal_id);
if ($stmt_delete->execute()) {
    echo json_encode(["status" => "success", "message" => "Proposal deleted successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to delete proposal"]);
}
$stmt_delete->close();
$conn->close();
