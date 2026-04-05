<?php
// Start session with debug
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

session_name('admin_panel_session');
session_set_cookie_params([
    'lifetime' => 86400,
    'path' => '/admin/',
    'domain' => $_SERVER['HTTP_HOST'],
    'secure' => isset($_SERVER['HTTPS']),
    'httponly' => true,
    'samesite' => 'Strict'
]);

session_start();

echo "<!-- SESSION DEBUG START -->\n";
echo "<!-- Session ID: " . session_id() . " -->\n";
echo "<!-- Session Status: " . session_status() . " -->\n";
echo "<!-- Session Data: " . print_r($_SESSION, true) . " -->\n";
echo "<!-- Cookie Data: " . print_r($_COOKIE, true) . " -->\n";
echo "<!-- Current URL: " . $_SERVER['REQUEST_URI'] . " -->\n";
echo "<!-- POST Data: " . print_r($_POST, true) . " -->\n";
echo "<!-- SESSION DEBUG END -->\n";

require_once __DIR__ . '/includes/auth.php';

// If already logged in, redirect to dashboard
if (isLoggedIn()) {
    echo "<!-- User is logged in, redirecting to dashboard -->\n";
    $redirect = isset($_SESSION['redirect_url']) ? $_SESSION['redirect_url'] : 'dashboard.php';
    unset($_SESSION['redirect_url']);
    header("Location: $redirect");
    exit;
} else {
    echo "<!-- User is NOT logged in -->\n";
}

$error = '';
$success = '';

// Handle login
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    echo "<!-- Processing POST request -->\n";
    
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $remember = isset($_POST['remember']);
    
    echo "<!-- Email: $email -->\n";
    echo "<!-- Password provided: " . (!empty($password) ? 'YES' : 'NO') . " -->\n";
    
    if (empty($email) || empty($password)) {
        $error = 'Email and password are required';
        echo "<!-- Validation error: $error -->\n";
    } else {
        // Simple login check first
        echo "<!-- Attempting login -->\n";
        
        if ($email === 'admin@ms.com' && $password === 'Admin@123') {
            echo "<!-- Hardcoded credentials matched -->\n";
            
            // Create session data
            $_SESSION['admin_id'] = 1;
            $_SESSION['admin_name'] = 'System Admin';
            $_SESSION['admin_email'] = $email;
            $_SESSION['admin_role'] = 'super_admin';
            $_SESSION['last_activity'] = time();
            
            echo "<!-- Session set: " . print_r($_SESSION, true) . " -->\n";
            
            // Simple redirect
            header('Location: dashboard.php');
            exit;
        } else {
            echo "<!-- Hardcoded credentials failed, trying database login -->\n";
            
            $result = login($email, $password, $remember);
            
            echo "<!-- Login result: " . print_r($result, true) . " -->\n";
            
            if ($result['success']) {
                $redirect = isset($_SESSION['redirect_url']) ? $_SESSION['redirect_url'] : 'dashboard.php';
                unset($_SESSION['redirect_url']);
                
                echo "<!-- Login successful, redirecting to: $redirect -->\n";
                echo "<!-- Current session: " . print_r($_SESSION, true) . " -->\n";
                
                header("Location: $redirect");
                exit;
            } else {
                $error = $result['message'];
                echo "<!-- Login failed: $error -->\n";
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Panel - Login</title>
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root {
            --primary-color: #667eea;
            --secondary-color: #764ba2;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
        }
        
        .login-container {
            width: 100%;
            max-width: 420px;
        }
        
        .login-card {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
            padding: 40px;
        }
        
        .login-header {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .login-icon {
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            width: 70px;
            height: 70px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
        }
        
        .btn-login {
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            border: none;
            color: white;
            padding: 12px;
            border-radius: 10px;
            font-weight: 600;
            width: 100%;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-card">
            <div class="login-header">
                <div class="login-icon">
                    <i class="fas fa-shield-alt"></i>
                </div>
                <h2 class="fw-bold mb-2">Admin Panel</h2>
                <p class="text-muted">Sign in to your account</p>
            </div>
            
            <?php if ($error): ?>
                <div class="alert alert-danger alert-dismissible fade show" role="alert">
                    <i class="fas fa-exclamation-circle me-2"></i>
                    <?php echo htmlspecialchars($error); ?>
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
            <?php endif; ?>
            
            <form method="POST" action="">
                <div class="mb-3">
                    <label for="email" class="form-label">Email Address</label>
                    <input type="email" class="form-control" id="email" name="email" 
                           placeholder="admin@ms.com" required value="admin@ms.com">
                </div>
                
                <div class="mb-3">
                    <label for="password" class="form-label">Password</label>
                    <input type="password" class="form-control" id="password" name="password" 
                           placeholder="••••••••" required value="Admin@123">
                </div>
                
                <button type="submit" class="btn btn-login mb-3">
                    <i class="fas fa-sign-in-alt me-2"></i> Sign In
                </button>
            </form>
        </div>
    </div>
</body>
</html>