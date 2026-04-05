<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Only POST allowed']);
    exit;
}

$host   = 'localhost';
$user   = 'ms';
$pass   = 'ms';
$dbname = 'ms';

$conn = new mysqli($host, $user, $pass, $dbname);
if ($conn->connect_error) {
    echo json_encode(['status' => 'error', 'message' => 'DB connection failed']);
    exit;
}
$conn->set_charset('utf8mb4');

$userid           = isset($_POST['userid'])           ? intval($_POST['userid'])           : 0;
$documenttype     = isset($_POST['documenttype'])     ? trim($_POST['documenttype'])       : null;
$documentidnumber = isset($_POST['documentidnumber']) ? trim($_POST['documentidnumber'])   : null;

if ($userid <= 0) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid userid']);
    exit;
}

// Handle file upload
$photoPath = null;
$allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
if (isset($_FILES['photo']) && $_FILES['photo']['error'] === UPLOAD_ERR_OK) {
    $folder = "uploads/user_marital_documents/";
    if (!is_dir($folder)) {
        mkdir($folder, 0755, true);
    }
    $ext = strtolower(pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, $allowedExtensions, true)) {
        echo json_encode(['status' => 'error', 'message' => 'Invalid file type. Allowed: jpg, jpeg, png, pdf']);
        exit;
    }
    $filename = "marital_" . $userid . "_" . time() . "." . $ext;
    $filepath = $folder . $filename;
    if (move_uploaded_file($_FILES['photo']['tmp_name'], $filepath)) {
        $photoPath = $filepath;
    } else {
        echo json_encode(['status' => 'error', 'message' => 'File upload failed']);
        exit;
    }
} else {
    echo json_encode(['status' => 'error', 'message' => 'Document photo is required']);
    exit;
}

// Check if record already exists for this user
$check = $conn->prepare("SELECT id FROM user_marital_documents WHERE userid = ?");
$check->bind_param("i", $userid);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    $sql  = "UPDATE user_marital_documents SET documenttype = ?, documentidnumber = ?, photo = ?, status = 'pending', reject_reason = NULL, updated_at = NOW() WHERE userid = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssi", $documenttype, $documentidnumber, $photoPath, $userid);
} else {
    $sql  = "INSERT INTO user_marital_documents (userid, documenttype, documentidnumber, photo, status) VALUES (?, ?, ?, ?, 'pending')";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("isss", $userid, $documenttype, $documentidnumber, $photoPath);
}

$check->close();

if ($stmt->execute()) {
    echo json_encode(['status' => 'success', 'message' => 'Marital document submitted for review']);
} else {
    echo json_encode(['status' => 'error', 'message' => 'Database error']);
}

$stmt->close();
$conn->close();
?>
