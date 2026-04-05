<?php
require_once 'auth.php';
requireLogin();
$admin = getCurrentAdmin();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Panel - <?php echo $title ?? 'Dashboard'; ?></title>
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <!-- DataTables CSS -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.4/css/dataTables.bootstrap5.min.css">
    <!-- SweetAlert2 -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
    <!-- Custom CSS -->
    <link href="../assets/css/style.css" rel="stylesheet">
    <style>
        :root {
            --primary-color: #667eea;
            --secondary-color: #764ba2;
            --success-color: #10b981;
            --danger-color: #ef4444;
            --warning-color: #f59e0b;
            --sidebar-width: 260px;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f8f9fa;
            min-height: 100vh;
        }
        
        .sidebar {
            width: var(--sidebar-width);
            background: white;
            border-right: 1px solid #e9ecef;
            position: fixed;
            top: 0;
            left: 0;
            height: 100vh;
            z-index: 100;
        }
        
        .main-content {
            margin-left: var(--sidebar-width);
            min-height: 100vh;
        }
        
        .navbar-top {
            height: 70px;
            background: white;
            border-bottom: 1px solid #e9ecef;
            padding: 0 30px;
        }
        
        .content-wrapper {
            padding: 30px;
        }
        
        .sidebar-header {
            padding: 20px;
            border-bottom: 1px solid #e9ecef;
        }
        
        .sidebar-nav {
            padding: 20px;
        }
        
        .nav-item {
            margin-bottom: 8px;
        }
        
        .nav-link {
            color: #4b5563;
            padding: 12px 16px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            transition: all 0.3s;
        }
        
        .nav-link:hover {
            background-color: #f0f4ff;
            color: var(--primary-color);
        }
        
        .nav-link.active {
            background-color: #f0f4ff;
            color: var(--primary-color);
            font-weight: 600;
        }
        
        .nav-link i {
            width: 20px;
            margin-right: 12px;
            font-size: 18px;
        }
        
        .admin-info {
            padding: 20px;
            border-bottom: 1px solid #e9ecef;
        }
        
        .logout-btn {
            padding: 20px;
            border-top: 1px solid #e9ecef;
        }
        
        .btn-logout {
            width: 100%;
            background: white;
            color: var(--danger-color);
            border: 1px solid var(--danger-color);
            padding: 10px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.3s;
        }
        
        .btn-logout:hover {
            background: var(--danger-color);
            color: white;
        }
        
        .card {
            border: none;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
            margin-bottom: 24px;
        }
        
        .card-header {
            background: white;
            border-bottom: 1px solid #e9ecef;
            padding: 20px;
            border-radius: 12px 12px 0 0 !important;
        }
        
        .card-title {
            color: #1f2937;
            font-weight: 600;
            margin: 0;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            font-weight: 500;
            transition: all 0.3s;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(102, 126, 234, 0.2);
        }
        
        .badge {
            padding: 6px 12px;
            border-radius: 20px;
            font-weight: 500;
        }
        
        .badge-pending {
            background-color: #fef3c7;
            color: #d97706;
        }
        
        .badge-approved {
            background-color: #d1fae5;
            color: #059669;
        }
        
        .badge-rejected {
            background-color: #fee2e2;
            color: #dc2626;
        }
        
        .document-image {
            height: 200px;
            object-fit: cover;
            border-radius: 8px;
            width: 100%;
            background-color: #f3f4f6;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #9ca3af;
        }
        
        .action-buttons .btn {
            padding: 8px 16px;
            font-weight: 500;
        }
        
        .table th {
            font-weight: 600;
            color: #4b5563;
            border-bottom: 2px solid #e5e7eb;
        }
        
        .table td {
            vertical-align: middle;
        }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">
            <div class="d-flex align-items-center">
                <div class="me-3">
                    <div style="width: 40px; height: 40px; background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); border-radius: 10px; display: flex; align-items: center; justify-content: center;">
                        <i class="fas fa-shield-alt text-white"></i>
                    </div>
                </div>
                <div>
                    <h5 class="fw-bold mb-0">Admin Panel</h5>
                </div>
            </div>
        </div>
        
        <div class="admin-info">
            <h6 class="fw-semibold mb-1"><?php echo htmlspecialchars($admin['name'] ?? 'Admin'); ?></h6>
            <p class="text-muted small mb-1"><?php echo htmlspecialchars($admin['email'] ?? 'admin@email.com'); ?></p>
            <span class="badge" style="background: linear-gradient(135deg, var(--primary-color), var(--secondary-color)); color: white;">
                <?php echo strtoupper(str_replace('_', ' ', $admin['role'] ?? 'admin')); ?>
            </span>
        </div>
        
        <div class="sidebar-nav">
            <ul class="nav flex-column">
                <li class="nav-item">
                    <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'dashboard.php' ? 'active' : ''; ?>" href="dashboard.php">
                        <i class="fas fa-dashboard"></i> Dashboard
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'documents.php' ? 'active' : ''; ?>" href="documents.php">
                        <i class="fas fa-file-alt"></i> Document Verification
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-users"></i> Users
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-chart-bar"></i> Analytics
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-cog"></i> Settings
                    </a>
                </li>
            </ul>
        </div>
        
        <div class="logout-btn">
            <a href="logout.php" class="btn-logout">
                <i class="fas fa-sign-out-alt me-2"></i> Logout
            </a>
        </div>
    </div>
    
    <div class="main-content">
        <nav class="navbar-top d-flex align-items-center justify-content-between">
            <h4 class="fw-bold mb-0"><?php echo $title ?? 'Dashboard'; ?></h4>
            <div>
                <button class="btn btn-light btn-sm me-2">
                    <i class="fas fa-bell"></i>
                </button>
                <button class="btn btn-light btn-sm">
                    <i class="fas fa-user"></i>
                </button>
            </div>
        </nav>
        
        <div class="content-wrapper">