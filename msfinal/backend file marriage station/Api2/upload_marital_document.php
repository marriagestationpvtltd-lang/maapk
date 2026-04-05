<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

$host   = "localhost";
$user   = "ms";
$pass   = "ms";
$dbname = "ms";

$conn = new mysqli($host, $user, $pass, $dbname);
if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "DB connect failed"]);
    exit;
}

// Ensure marital_documents table exists
$conn->query("
    CREATE TABLE IF NOT EXISTS marital_documents (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userid INT NOT NULL,
        documenttype VARCHAR(100),
        documentidnumber VARCHAR(100),
        photo VARCHAR(255),
        status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
        reject_reason VARCHAR(255) DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX (userid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$userid = isset($_POST['userid']) ? intval($_POST['userid']) : 0;
if ($userid <= 0) {
    echo json_encode(["status" => "error", "message" => "Invalid userid"]);
    exit;
}

$documenttype     = $_POST['documenttype'] ?? null;
$documentidnumber = $_POST['documentidnumber'] ?? null;

$photoPath = null;
if (isset($_FILES['photo']) && $_FILES['photo']['error'] === UPLOAD_ERR_OK) {
    $folder = "uploads/marital_documents/";
    if (!is_dir($folder)) {
        mkdir($folder, 0777, true);
    }
    $ext      = pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION);
    $filename = "marital_" . $userid . "_" . time() . "." . $ext;
    $filepath = $folder . $filename;
    if (move_uploaded_file($_FILES['photo']['tmp_name'], $filepath)) {
        $photoPath = $filepath;
    }
}

$check = $conn->prepare("SELECT id FROM marital_documents WHERE userid = ?");
$check->bind_param("i", $userid);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    $sql  = "UPDATE marital_documents SET documenttype = ?, documentidnumber = ?, photo = IFNULL(?, photo), status = 'pending', reject_reason = NULL WHERE userid = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssi", $documenttype, $documentidnumber, $photoPath, $userid);
} else {
    $sql  = "INSERT INTO marital_documents (userid, documenttype, documentidnumber, photo) VALUES (?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("isss", $userid, $documenttype, $documentidnumber, $photoPath);
}

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Marital document uploaded, status set to pending"]);
} else {
    echo json_encode(["status" => "error", "message" => "Database error"]);
}

$conn->close();
?>
