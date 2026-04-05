<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");

include("db.php"); // your DB connection

if (!isset($_GET['userid'])) {
    echo json_encode([
        "status" => false,
        "message" => "userid is required"
    ]);
    exit;
}

$userid = isset($_GET['userid']) ? intval($_GET['userid']) : 0;

if (!$userid) {
    echo json_encode([
        "status" => false,
        "message" => "userid is required"
    ]);
    exit;
}

$sql = "
SELECT 
    u.userid,
    u.maritalStatusId,
    m.name AS maritalStatusName
FROM userpersonaldetail u
LEFT JOIN maritalstatus m 
    ON u.maritalStatusId = m.id
WHERE u.userid = ?
LIMIT 1
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $userid);
$stmt->execute();

$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    echo json_encode([
        "status" => true,
        "data" => $row
    ]);
} else {
    echo json_encode([
        "status" => false,
        "message" => "No record found"
    ]);
}

$stmt->close();
$conn->close();
