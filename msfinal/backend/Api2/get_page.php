<?php
header("Content-Type: application/json");

// DATABASE CONNECTION --------------------
$host = "localhost";
$user = "ms";
$pass = "ms";
$dbname = "ms";

$conn = new mysqli($host, $user, $pass, $dbname);

if ($conn->connect_error) {
    echo json_encode([
        "status" => "error",
        "message" => "Database connection failed"
    ]);
    exit;
}

// CHECK USER_ID PARAM ---------------------
if (!isset($_GET['user_id'])) {
    echo json_encode([
        "status" => "error",
        "message" => "Missing user_id parameter"
    ]);
    exit;
}

$user_id = intval($_GET['user_id']);

// FETCH PAGE NO ---------------------------
$stmt = $conn->prepare("SELECT pageno FROM users WHERE id = ? LIMIT 1");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {

    $row = $result->fetch_assoc();

    echo json_encode([
        "status" => "success",
        "data" => [
            "pageno" => intval($row['pageno'])
        ]
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "User not found"
    ]);
}

$conn->close();
?>
