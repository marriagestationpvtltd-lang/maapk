<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $pdo = new PDO(
        "mysql:host=localhost;dbname=ms;charset=utf8mb4",
        "ms",
        "ms",
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

try {
    // Ensure app_settings table exists
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS app_settings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            `key` VARCHAR(100) NOT NULL UNIQUE,
            `value` TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ");

    // Insert defaults if table is empty
    $count = $pdo->query("SELECT COUNT(*) FROM app_settings")->fetchColumn();
    if ($count == 0) {
        $pdo->exec("
            INSERT INTO app_settings (`key`, `value`) VALUES
            ('vat_enabled', '0'),
            ('vat_rate', '13'),
            ('currency', 'NPR'),
            ('app_name', 'Marriage Station')
        ");
    }

    // Fetch all settings
    $rows = $pdo->query("SELECT `key`, `value` FROM app_settings")->fetchAll();
    $settings = [];
    foreach ($rows as $row) {
        $settings[$row['key']] = $row['value'];
    }

    echo json_encode(['success' => true, 'data' => $settings]);

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
