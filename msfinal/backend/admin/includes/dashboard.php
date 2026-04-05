<?php
// Start session
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Check if logged in
if (!isset($_SESSION['admin_id']) || $_SESSION['admin_id'] <= 0) {
    header('Location: index.php');
    exit;
}

$admin = [
    'name' => $_SESSION['admin_name'] ?? 'Admin',
    'email' => $_SESSION['admin_email'] ?? '',
    'role' => $_SESSION['admin_role'] ?? 'admin'
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background: #f8f9fa;
            padding: 20px;
        }
        .dashboard-card {
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-top: 50px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-8">
                <div class="dashboard-card">
                    <h1 class="text-center mb-4">Welcome to Admin Dashboard!</h1>
                    
                    <div class="alert alert-success">
                        <h4>Login Successful!</h4>
                        <p>You are logged in as: <strong><?php echo htmlspecialchars($admin['name']); ?></strong></p>
                        <p>Email: <?php echo htmlspecialchars($admin['email']); ?></p>
                        <p>Role: <?php echo htmlspecialchars($admin['role']); ?></p>
                    </div>
                    
                    <div class="mt-4">
                        <a href="documents.php" class="btn btn-primary">Go to Documents</a>
                        <a href="logout.php" class="btn btn-danger">Logout</a>
                    </div>
                    

                </div>
            </div>
        </div>
    </div>
</body>
</html>