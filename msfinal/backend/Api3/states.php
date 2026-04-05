<?php
include 'db.php';

if (!isset($_GET['country_id'])) {
    echo json_encode([
        "status" => "error",
        "message" => "country_id is required"
    ]);
    exit;
}

$country_id = intval($_GET['country_id']);

$stmt = $conn->prepare(
    "SELECT id, name FROM state WHERE countryId = ? ORDER BY name ASC"
);
$stmt->bind_param("i", $country_id);
$stmt->execute();
$result = $stmt->get_result();

$states = [];
while ($row = $result->fetch_assoc()) {
    $states[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $states
]);
?>
