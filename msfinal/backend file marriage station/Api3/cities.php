<?php
include 'db.php';

if (!isset($_GET['state_id'])) {
    echo json_encode([
        "status" => "error",
        "message" => "state_id is required"
    ]);
    exit;
}

$state_id = intval($_GET['state_id']);

$stmt = $conn->prepare(
    "SELECT id, name FROM districts WHERE stateId = ? ORDER BY name ASC"
);
$stmt->bind_param("i", $state_id);
$stmt->execute();
$result = $stmt->get_result();

$cities = [];
while ($row = $result->fetch_assoc()) {
    $cities[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $cities
]);
?>
