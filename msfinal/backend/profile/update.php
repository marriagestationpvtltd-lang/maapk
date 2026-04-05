<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

// Database connection
$host = "localhost";
$user = "ms";
$pass = "ms";
$dbname = "ms";

$conn = new mysqli($host, $user, $pass, $dbname);

// ✅ Show DB connection errors
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Database connection failed"]);
    exit;
}

// ✅ Read and decode JSON input
$raw = file_get_contents("php://input");
if (!$raw) {
    echo json_encode(["error" => "No input data received"]);
    exit;
}

$data = json_decode($raw, true);

// ✅ Check JSON parse errors
if ($data === null) {
    echo json_encode(["error" => "Invalid JSON format"]);
    exit;
}

// ✅ Validate userId
if (empty($data['userId'])) {
    echo json_encode(["error" => "Missing required field: userId"]);
    exit;
}

// ✅ Sanitize inputs
$userId = intval($data['userId']);
$firstName = isset($data['firstName']) ? $data['firstName'] : null;
$middleName = isset($data['middleName']) ? $data['middleName'] : null;
$lastName = isset($data['lastName']) ? $data['lastName'] : null;
$imageUrl = isset($data['imageUrl']) ? $data['imageUrl'] : null;

// ✅ Begin transaction
$conn->begin_transaction();

try {
    // Update users table
    $stmtUser = $conn->prepare("UPDATE users SET 
                    firstName = IFNULL(?, firstName),
                    middleName = IFNULL(?, middleName),
                    lastName = IFNULL(?, lastName)
                WHERE id = ?");
    $stmtUser->bind_param("sssi", $firstName, $middleName, $lastName, $userId);
    $userUpdate = $stmtUser->execute();
    $stmtUser->close();

    if (!$userUpdate) {
        throw new Exception("Failed to update users table: " . $conn->error);
    }

    // Update image if provided
    if ($imageUrl !== null && $imageUrl !== '') {
        $stmtImg = $conn->prepare("UPDATE images SET imageUrl = ? WHERE createdBy = ?");
        $stmtImg->bind_param("si", $imageUrl, $userId);
        $imgUpdate = $stmtImg->execute();
        $stmtImg->close();

        if (!$imgUpdate) {
            throw new Exception("Failed to update images table: " . $conn->error);
        }
    }

    // ✅ Commit transaction
    $conn->commit();

    // ✅ Fetch updated data
    $stmtSel = $conn->prepare("SELECT 
                    u.id,
                    u.firstName,
                    u.middleName,
                    u.lastName,
                    i.imageUrl
                  FROM users u
                  LEFT JOIN images i ON i.createdBy = u.id
                  WHERE u.id = ?");
    $stmtSel->bind_param("i", $userId);
    $stmtSel->execute();
    $result = $stmtSel->get_result();
    $stmtSel->close();

    if ($result && $result->num_rows > 0) {
        $user = $result->fetch_assoc();
        echo json_encode(["success" => true, "user" => $user]);
    } else {
        echo json_encode(["error" => "User not found"]);
    }

} catch (Exception $e) {
    $conn->rollback();
    http_response_code(500);
    error_log('update.php Exception: ' . $e->getMessage());
    echo json_encode(["error" => "Update failed"]);
}

$conn->close();
?>
