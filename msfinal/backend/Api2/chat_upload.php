<?php
/**
 * chat_upload.php
 * Upload chat images or voice messages to the server.
 * Used by the Flutter app when the Socket.IO server is separate from the PHP backend.
 *
 * POST parameters (multipart/form-data):
 *   - file   : the binary file
 *   - type   : "image" | "voice"
 *   - userId : uploader's user ID (for path namespacing)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$type   = isset($_POST['type'])   ? $_POST['type']   : 'image';
$userId = isset($_POST['userId']) ? $_POST['userId'] : 'unknown';

if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['error' => 'No file uploaded or upload error']);
    exit;
}

// Validate type
$allowed = ['image', 'voice'];
if (!in_array($type, $allowed)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid type']);
    exit;
}

// Allowed MIME types
$allowedMimeTypes = [
    'image' => ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    'voice' => ['audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/webm', 'audio/aac', 'audio/wav', 'audio/x-m4a'],
];

// Validate file extension FIRST before inspecting content
$ext      = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
$safeExts = ['image' => ['jpg','jpeg','png','gif','webp'], 'voice' => ['mp3','mp4','ogg','webm','aac','wav','m4a']];
if (!in_array($ext, $safeExts[$type])) {
    http_response_code(400);
    echo json_encode(['error' => 'File extension not allowed: ' . $ext]);
    exit;
}

// Validate MIME type by inspecting actual file content
$finfo    = new finfo(FILEINFO_MIME_TYPE);
$mimeType = $finfo->file($_FILES['file']['tmp_name']);

if (!in_array($mimeType, $allowedMimeTypes[$type])) {
    http_response_code(400);
    echo json_encode(['error' => 'File type not allowed: ' . $mimeType]);
    exit;
}

// Max file sizes
$maxSizes = ['image' => 10 * 1024 * 1024, 'voice' => 25 * 1024 * 1024];
if ($_FILES['file']['size'] > $maxSizes[$type]) {
    http_response_code(400);
    echo json_encode(['error' => 'File too large']);
    exit;
}

// Build destination path
$subDir   = ($type === 'voice') ? 'voice_messages' : 'chat_images';
$uploadDir = __DIR__ . '/../../uploads/chat/' . $subDir . '/';

if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Generate unique filename (extension already validated above)
$filename    = sprintf('%s_%s.%s', $userId, bin2hex(random_bytes(8)), $ext);
$destination = $uploadDir . $filename;

if (!move_uploaded_file($_FILES['file']['tmp_name'], $destination)) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to save file']);
    exit;
}

// Build public URL
$protocol  = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host      = $_SERVER['HTTP_HOST'];
$publicUrl = $protocol . '://' . $host . '/uploads/chat/' . $subDir . '/' . $filename;

echo json_encode(['success' => true, 'url' => $publicUrl]);
