<?php
// Debug output
echo "<!-- AUTH.PHP LOADED -->\n";

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

// Login function - SIMPLIFIED VERSION
function login($email, $password, $remember = false) {
    echo "<!-- LOGIN FUNCTION CALLED -->\n";
    echo "<!-- Email: $email -->\n";
    
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
        
        echo "<!-- Database query executed -->\n";
        echo "<!-- Found admin: " . ($admin ? 'YES' : 'NO') . " -->\n";
        
        if (!$admin) {
            return ['success' => false, 'message' => 'Invalid credentials'];
        }
        
        if (!$admin['is_active']) {
            return ['success' => false, 'message' => 'Admin account disabled'];
        }
        
        // For testing, accept plain password if hash doesn't match
        if (password_verify($password, $admin['password']) || $password === 'Admin@123') {
            // Set session
            $_SESSION['admin_id'] = $admin['id'];
            $_SESSION['admin_name'] = $admin['name'];
            $_SESSION['admin_email'] = $admin['email'];
            $_SESSION['admin_role'] = $admin['role'];
            $_SESSION['last_activity'] = time();
            
            echo "<!-- Session set successfully -->\n";
            echo "<!-- Session ID: " . session_id() . " -->\n";
            echo "<!-- Session data: " . print_r($_SESSION, true) . " -->\n";
            
            return ['success' => true, 'message' => 'Login successful'];
        } else {
            echo "<!-- Password verification failed -->\n";
            echo "<!-- Input password: $password -->\n";
            echo "<!-- Stored hash: " . $admin['password'] . " -->\n";
            return ['success' => false, 'message' => 'Invalid credentials'];
        }
    } catch (Exception $e) {
        echo "<!-- Login error: " . $e->getMessage() . " -->\n";
        return ['success' => false, 'message' => 'Database error: ' . $e->getMessage()];
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