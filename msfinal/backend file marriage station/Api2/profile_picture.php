<?php
header('Content-Type: application/json');

// Database configuration
$host = "localhost";
$db_name = "ms";
$username = "ms";
$password = "ms";

// Create connection
$conn = new mysqli($host, $username, $password, $db_name);

// Check connection
if ($conn->connect_error) {
    die(json_encode([
        "status" => "error",
        "message" => "Database connection failed: " . $conn->connect_error
    ]));
}

// Check if user ID is provided
$userid = isset($_POST['userid']) ? intval($_POST['userid']) : 0;
if ($userid <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid user ID"
    ]);
    exit;
}

// Check if file is uploaded
if (!isset($_FILES['profile_picture']) || $_FILES['profile_picture']['error'] != 0) {
    echo json_encode([
        "status" => "error",
        "message" => "No file uploaded or file upload error"
    ]);
    exit;
}

// File details
$fileTmpPath = $_FILES['profile_picture']['tmp_name'];
$fileName = $_FILES['profile_picture']['name'];
$fileSize = $_FILES['profile_picture']['size'];
$fileType = $_FILES['profile_picture']['type'];

// Create uploads directory if not exists
$uploadDir = __DIR__ . '/uploads/profile_pictures/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Generate unique file name to avoid overwriting
$fileExt = pathinfo($fileName, PATHINFO_EXTENSION);
$newFileName = 'profilepicture_' . $userid . '.' . $fileExt;
$destPath = $uploadDir . $newFileName;

// Move uploaded file
if(move_uploaded_file($fileTmpPath, $destPath)) {
    // Store relative path in DB
    $relativePath = 'uploads/profile_pictures/' . $newFileName;
    $sql = "UPDATE users SET profile_picture = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $relativePath, $userid);

    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Profile picture updated successfully",
            "path" => $relativePath
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Failed to update database"
        ]);
    }

    $stmt->close();
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Failed to move uploaded file"
    ]);
}

$conn->close();
?>
