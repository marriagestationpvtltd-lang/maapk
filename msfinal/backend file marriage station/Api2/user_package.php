<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

// Database configuration
$dbHost = "127.0.0.1";
$dbName = "ms";
$dbUser = "ms";
$dbPass = "ms";

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName", $dbUser, $dbPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Get userid from GET parameters
    $userid = $_GET['userid'] ?? null;

    if (!$userid) {
        echo json_encode(["success" => false, "message" => "Missing userid parameter"]);
        exit;
    }

    // Query to get user packages with package details
    $stmt = $pdo->prepare("
        SELECT 
            up.id AS user_package_id,
            up.userid,
            up.packageid,
            up.purchasedate,
            up.expiredate,
            up.paidby,
            pl.name AS package_name,
            pl.duration,
            pl.description,
            pl.price
        FROM user_package up
        LEFT JOIN packagelist pl ON up.packageid = pl.id
        WHERE up.userid = :userid
        ORDER BY up.purchasedate DESC
    ");

    $stmt->execute(['userid' => $userid]);
    $packages = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$packages) {
        echo json_encode(["success" => true, "message" => "No packages found for this user", "data" => []]);
        exit;
    }

    echo json_encode([
        "success" => true,
        "message" => "User packages retrieved successfully",
        "data" => $packages
    ]);

} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
