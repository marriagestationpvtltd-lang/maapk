<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");

// ---------- DB CONNECTION ----------
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
} catch (PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Database connection failed"
    ]);
    exit;
}

// ---------- INPUT (GET) ----------
$userid    = $_GET['userid']    ?? null;
$paidby    = $_GET['paidby']    ?? null;
$packageid = $_GET['packageid'] ?? null;

if (!$userid || !$paidby || !$packageid) {
    echo json_encode([
        "status" => "error",
        "message" => "userid, paidby and packageid are required"
    ]);
    exit;
}

try {
    $pdo->beginTransaction();

    // ---------- 1. GET PACKAGE VALIDITY ----------
    $pkgStmt = $pdo->prepare("SELECT duration FROM packagelist WHERE id = ?");
    $pkgStmt->execute([$packageid]);
    $package = $pkgStmt->fetch();

    if (!$package) {
        throw new Exception("Invalid package ID");
    }

    $validityMonths = (int)$package['duration'];

    // ---------- 2. UPDATE USER TYPE TO 'paid' IF NOT ALREADY ----------
    $updateUser = $pdo->prepare("
        UPDATE users 
        SET usertype = 'paid' 
        WHERE id = ? AND usertype != 'paid'
    ");
    $updateUser->execute([$userid]);
    // ✅ Even if rowCount() === 0, it's fine. User is already 'paid'

    // ---------- 3. DATE CALCULATION ----------
    $purchaseDate = date("Y-m-d");
    $expireDate   = date("Y-m-d", strtotime("+$validityMonths months"));

    // ---------- 4. ALWAYS INSERT NEW USER PACKAGE ----------
    $insertPackage = $pdo->prepare("
        INSERT INTO user_package
        (userid, paidby, packageid, purchasedate, expiredate)
        VALUES (?, ?, ?, ?, ?)
    ");
    $insertPackage->execute([
        $userid,
        $paidby,
        $packageid,
        $purchaseDate,
        $expireDate
    ]);

    $pdo->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Package purchased successfully",
        "data" => [
            "userid" => $userid,
            "packageid" => $packageid,
            "purchasedate" => $purchaseDate,
            "expiredate" => $expireDate
        ]
    ]);

} catch (Exception $e) {
    $pdo->rollBack();
    error_log('purchase_package.php Exception: ' . $e->getMessage());
    echo json_encode([
        "status" => "error",
        "message" => "Purchase failed"
    ]);
}
