<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET");
header("Access-Control-Allow-Headers: Content-Type");

$conn = new mysqli("localhost", "ms", "ms", "ms");
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => $conn->connect_error]));
}

// Handle both GET and POST requests
$userid = 0;

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $userid = isset($_GET['userid']) ? intval($_GET['userid']) : 0;
} else {
    $data = json_decode(file_get_contents("php://input"), true);
    if ($data) {
        $userid = isset($data['userid']) ? intval($data['userid']) : 0;
    }
}

if ($userid <= 0) {
    die(json_encode(["status" => "error", "message" => "userid required"]));
}

// Query to get partner preferences
$stmt = $conn->prepare("SELECT * FROM user_partner WHERE userid = ?");
$stmt->bind_param("i", $userid);
$stmt->execute();
$result = $stmt->get_result();

if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();

    // Function to get country names from IDs
    function getCountryNames($conn, $ids) {
        if (empty($ids) || $ids == '0') return ['Any'];
        $idArray = explode(',', $ids);
        $names = [];
        foreach ($idArray as $id) {
            $id = intval($id);
            if ($id === 0) {
                $names[] = 'Any';
            } else {
                $s = $conn->prepare("SELECT name FROM countries WHERE id = ?");
                $s->bind_param("i", $id);
                $s->execute();
                $r = $s->get_result();
                if ($r && $r->num_rows > 0) {
                    $names[] = $r->fetch_assoc()['name'];
                } else {
                    $names[] = (string)$id;
                }
                $s->close();
            }
        }
        return $names;
    }

    // Function to get state names from IDs (table name is 'state')
    function getStateNames($conn, $ids) {
        if (empty($ids) || $ids == '0') return ['Any'];
        $idArray = explode(',', $ids);
        $names = [];
        foreach ($idArray as $id) {
            $id = intval($id);
            if ($id === 0) {
                $names[] = 'Any';
            } else {
                $s = $conn->prepare("SELECT name FROM state WHERE id = ?");
                $s->bind_param("i", $id);
                $s->execute();
                $r = $s->get_result();
                if ($r && $r->num_rows > 0) {
                    $names[] = $r->fetch_assoc()['name'];
                } else {
                    $names[] = (string)$id;
                }
                $s->close();
            }
        }
        return $names;
    }

    // Function to get district/city names from IDs (table name is 'districts')
    function getDistrictNames($conn, $ids) {
        if (empty($ids) || $ids == '0') return ['Any'];
        $idArray = explode(',', $ids);
        $names = [];
        foreach ($idArray as $id) {
            $id = intval($id);
            if ($id === 0) {
                $names[] = 'Any';
            } else {
                $s = $conn->prepare("SELECT name FROM districts WHERE id = ?");
                $s->bind_param("i", $id);
                $s->execute();
                $r = $s->get_result();
                if ($r && $r->num_rows > 0) {
                    $names[] = $r->fetch_assoc()['name'];
                } else {
                    $names[] = (string)$id;
                }
                $s->close();
            }
        }
        return $names;
    }
    
    // Get names for location fields
    $countryNames = getCountryNames($conn, $row['country']);
    $stateNames = getStateNames($conn, $row['state']);
    $districtNames = getDistrictNames($conn, $row['city']); // city column stores district IDs
    
    // Also return the IDs for reference (useful for loading dependent dropdowns)
    $countryIds = explode(',', $row['country']);
    $stateIds = explode(',', $row['state']);
    $districtIds = explode(',', $row['city']);
    
    $response = [
        "status" => "success",
        "data" => [
            "userid" => $row['userid'],
            "minage" => $row['minage'],
            "maxage" => $row['maxage'],
            "minheight" => $row['minheight'],
            "maxheight" => $row['maxheight'],
            "maritalstatus" => explode(',', $row['maritalstatus']),
            "profilewithchild" => $row['profilewithchild'],
            "familytype" => explode(',', $row['familytype']),
            "religion" => explode(',', $row['religion']),
            "caste" => explode(',', $row['caste']),
            "subcaste" => explode(',', $row['subcaste']),
            "mothertongue" => explode(',', $row['mothertoungue']), // Corrected API key name
            "horoscopebelief" => $row['herscopeblief'], // Corrected API key name
            "manglik" => $row['manglik'],
            "country" => $countryNames, // Returns country names
            "country_ids" => $countryIds, // Optional: keep IDs if needed
            "state" => $stateNames, // Returns state names
            "state_ids" => $stateIds, // Optional: keep IDs if needed
            "city" => $districtNames, // Returns district names (from districts table)
            "city_ids" => $districtIds, // Optional: keep district IDs if needed
            "qualification" => explode(',', $row['qualification']),
            "educationmedium" => explode(',', $row['educationmedium']),
            "profession" => explode(',', $row['proffession']), // Corrected API key name
            "workingwith" => explode(',', $row['workingwith']),
            "annualincome" => explode(',', $row['annualincome']),
            "diet" => explode(',', $row['diet']),
            "smokeaccept" => $row['smokeaccept'],
            "drinkaccept" => $row['drinkaccept'],
            "disabilityaccept" => $row['disabilityaccept'],
            "complexion" => explode(',', $row['complexion']),
            "bodytype" => explode(',', $row['bodytype']),
            "otherexpectation" => $row['otherexpectation']
        ]
    ];
    
    echo json_encode($response);
} else {
    echo json_encode([
        "status" => "success", 
        "data" => null,
        "message" => "No data found for this user"
    ]);
}

$conn->close();
?>