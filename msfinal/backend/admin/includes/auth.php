<?php
// Simple session start
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Database connection
function getPDO() {
    try {
        $pdo = new PDO(
            "mysql:host=localhost;dbname=ms;charset=utf8mb4",
            "ms",
            "ms",
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
            ]
        );
        return $pdo;
    } catch (PDOException $e) {
        die("Database connection failed: " . $e->getMessage());
    }
}

// Simple login check
function isLoggedIn() {
    if (isset($_SESSION['admin_id']) && $_SESSION['admin_id'] > 0) {
        return true;
    }
    return false;
}

// Get admin data
function getCurrentAdmin() {
    if (isset($_SESSION['admin_id'])) {
        return [
            'id' => $_SESSION['admin_id'],
            'name' => $_SESSION['admin_name'] ?? 'Admin',
            'email' => $_SESSION['admin_email'] ?? '',
            'role' => $_SESSION['admin_role'] ?? 'admin'
        ];
    }
    return null;
}

// Login function
function login($email, $password, $remember = false) {
    try {
        $pdo = getPDO();
        
        $stmt = $pdo->prepare("
            SELECT id, name, email, password, role, is_active
            FROM admins
            WHERE email = :email
            LIMIT 1
        ");
        
        $stmt->execute(['email' => $email]);
        $admin = $stmt->fetch();
        
        if (!$admin) {
            return ['success' => false, 'message' => 'Invalid credentials'];
        }
        
        if (!$admin['is_active']) {
            return ['success' => false, 'message' => 'Admin account disabled'];
        }
        
        if (password_verify($password, $admin['password'])) {
            // Set session
            $_SESSION['admin_id'] = $admin['id'];
            $_SESSION['admin_name'] = $admin['name'];
            $_SESSION['admin_email'] = $admin['email'];
            $_SESSION['admin_role'] = $admin['role'];
            $_SESSION['last_activity'] = time();
            
            return ['success' => true, 'message' => 'Login successful'];
        } else {
            return ['success' => false, 'message' => 'Invalid credentials'];
        }
    } catch (Exception $e) {
        error_log('Admin login error occurred');
        return ['success' => false, 'message' => 'Database error'];
    }
}

// Logout
function logout() {
    session_destroy();
    header('Location: index.php');
    exit;
}

// Require login
function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: index.php');
        exit;
    }
}
?>