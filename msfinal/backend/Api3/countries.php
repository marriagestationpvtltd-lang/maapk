<?php
include 'db.php';

$sql = "SELECT id, name FROM countries ORDER BY name ASC";
$result = $conn->query($sql);

$countries = [];

while ($row = $result->fetch_assoc()) {
    $countries[] = $row;
}

echo json_encode([
    "status" => "success",
    "data" => $countries
]);
?>
