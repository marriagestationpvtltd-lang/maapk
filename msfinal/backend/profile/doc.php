<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

$servername = "localhost";
$username = "ms"; // change
$password = "ms"; // change
$dbname = "ms"; // change

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die(json_encode(["error" => "Database connection failed: " . $conn->connect_error]));
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method == 'GET') {

    // Optional filters (?status=pending or ?userId=10)
    $params = [];
    $types = '';
    $whereParts = [];

    if (isset($_GET['status'])) {
        $statusFilter = $_GET['status'];
        $whereParts[] = "ud.status = ?";
        $types .= 's';
        $params[] = $statusFilter;
    }
    if (isset($_GET['userId'])) {
        $userIdFilter = intval($_GET['userId']);
        $whereParts[] = "ud.userId = ?";
        $types .= 'i';
        $params[] = $userIdFilter;
    }

    $whereClause = !empty($whereParts) ? "WHERE " . implode(" AND ", $whereParts) : "";

    // 🔥 Main Query with All Joins
    $sql = "
        SELECT 
            ud.id,
            ud.userId,
            u.firstName,
            u.lastName,
            u.email,
            u.contactNo,
            i.imageUrl,
            ud.documentTypeId,
            dt.name AS documentTypeName,
            ud.documentUrl,
            ud.isVerified,
            ud.status,
            ud.reject_reason,

            upd.educationId,
            e.name AS educationName,

            upd.occupationId,
            o.name AS occupationName,

            upd.maritalStatusId,
            m.name AS maritalStatusName,
            upd.familyType,

            upd.addressId,
            a.countryId,
            c.name AS countryName

        FROM userdocument ud
        LEFT JOIN users u ON ud.userId = u.id
        LEFT JOIN documenttype dt ON ud.documentTypeId = dt.id
        LEFT JOIN userpersonaldetail upd ON ud.userId = upd.userId
        LEFT JOIN education e ON upd.educationId = e.id
        LEFT JOIN occupation o ON upd.occupationId = o.id
        LEFT JOIN maritalstatus m ON upd.maritalStatusId = m.id
        LEFT JOIN addresses a ON upd.addressId = a.id
        LEFT JOIN countries c ON a.countryId = c.id
        LEFT JOIN images i ON i.createdBy = u.id
        $whereClause
        ORDER BY ud.id DESC
    ";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $documents = [];
    $baseUploadUrl = "https://api.digitallami.com/"; // change this to your upload directory

    while ($row = $result->fetch_assoc()) {
        $documents[] = [
            "id" => $row['id'],
            "userId" => $row['userId'],

            // 🧍‍♂️ User Info
            "firstName" => $row['firstName'],
            "lastName" => $row['lastName'],
            "email" => $row['email'],
            "contactNo" => $row['contactNo'],
            "imageUrl" => $row['imageUrl'] ? $baseUploadUrl . $row['imageUrl'] : null,

            // 📄 Document Info
            "documentTypeId" => $row['documentTypeId'],
            "documentTypeName" => $row['documentTypeName'],
            "documentUrl" => $row['documentUrl'] ? $baseUploadUrl . $row['documentUrl'] : null,
            "status" => $row['status'],
            "isVerified" => (bool)$row['isVerified'],
            "reject_reason" => $row['reject_reason'],

            // 🎓 Personal Info
            "educationId" => $row['educationId'],
            "educationName" => $row['educationName'],

            "occupationId" => $row['occupationId'],
            "occupationName" => $row['occupationName'],

            "maritalStatusId" => $row['maritalStatusId'],
            "maritalStatusName" => $row['maritalStatusName'],
            "familyType" => $row['familyType'],

            // 🌍 Address & Country
            "addressId" => $row['addressId'],
            "countryId" => $row['countryId'],
            "countryName" => $row['countryName']
        ];
    }

    echo json_encode(["success" => true, "data" => $documents]);
}

elseif ($method == 'POST') {
    // Update document status and verification
    $input = json_decode(file_get_contents("php://input"), true);

    if (!isset($input['id']) || !isset($input['status'])) {
        echo json_encode(["success" => false, "message" => "Missing required fields"]);
        exit;
    }

    $id = intval($input['id']);
    $status = $input['status'];
    $reject_reason = isset($input['reject_reason']) ? $input['reject_reason'] : null;
    $isVerified = ($status == 'approved') ? 1 : 0;

    $stmt = $conn->prepare("UPDATE userdocument 
            SET status=?,
                reject_reason=?,
                isVerified=?
            WHERE id=?");
    $stmt->bind_param("ssii", $status, $reject_reason, $isVerified, $id);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Document updated successfully"]);
    } else {
        error_log('profile/doc.php execute error: ' . $stmt->error);
        echo json_encode(["success" => false, "message" => "Error updating document"]);
    }
    $stmt->close();
}

else {
    echo json_encode(["error" => "Invalid request method"]);
}

$conn->close();
?>
