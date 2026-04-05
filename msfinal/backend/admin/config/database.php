<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_NAME', 'ms');
define('DB_USER', 'ms');
define('DB_PASS', 'ms');
define('SECRET_KEY', 'CHANGE_THIS_SECRET_KEY');

// Base URL configuration - UPDATE THIS
define('BASE_URL', 'https://' . $_SERVER['HTTP_HOST'] . '/admin/');
define('SITE_URL', 'https://' . $_SERVER['HTTP_HOST'] . '/');

// Create database connection
function getPDO() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
        return $pdo;
    } catch (PDOException $e) {
        die("Connection failed: " . $e->getMessage());
    }
}

// Generate token
function generateToken($adminData) {
    $payload = [
        'admin_id' => $adminData['id'],
        'email' => $adminData['email'],
        'role' => $adminData['role'],
        'iat' => time(),
        'exp' => time() + (60 * 60 * 24) // 24 hours
    ];
    
    return base64_encode(json_encode($payload)) . '.' . hash_hmac('sha256', json_encode($payload), SECRET_KEY);
}

// Verify token
function verifyToken($token) {
    if (!$token) return false;
    
    $parts = explode('.', $token);
    if (count($parts) !== 2) return false;
    
    list($payload, $signature) = $parts;
    
    // Verify signature
    if (hash_hmac('sha256', $payload, SECRET_KEY) !== $signature) {
        return false;
    }
    
    $data = json_decode(base64_decode($payload), true);
    
    // Check expiration
    if (isset($data['exp']) && $data['exp'] < time()) {
        return false;
    }
    
    return $data;
}
?>