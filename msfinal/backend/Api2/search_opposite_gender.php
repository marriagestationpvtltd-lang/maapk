<?php
header('Content-Type: application/json; charset=utf-8');

try {
    // === DATABASE CONFIG ===
    $dbHost = "127.0.0.1";
    $dbName = "ms"; 
    $dbUser = "ms"; 
    $dbPass = "ms"; 

    $pdo = new PDO(
        "mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4",
        $dbUser,
        $dbPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );

    // === INPUT CHECK ===
    if (!isset($_GET['user_id']) || !is_numeric($_GET['user_id'])) {
        echo json_encode(["success" => false, "message" => "user_id is required and must be numeric"]);
        exit;
    }
    $userId = (int) $_GET['user_id'];

    // Optional filters
    $minAge = isset($_GET['minage']) ? (int)$_GET['minage'] : null;
    $maxAge = isset($_GET['maxage']) ? (int)$_GET['maxage'] : null;
    $minHeight = isset($_GET['minheight']) ? (int)$_GET['minheight'] : null;
    $maxHeight = isset($_GET['maxheight']) ? (int)$_GET['maxheight'] : null;
    $religion = isset($_GET['religion']) ? (int)$_GET['religion'] : null;

    // New filter parameters
    $hasPhoto = isset($_GET['has_photo']) && $_GET['has_photo'] == '1';
    $userType = isset($_GET['usertype']) ? strtolower(trim($_GET['usertype'])) : null;
    $isVerified = isset($_GET['is_verified']) && $_GET['is_verified'] == '1';
    $daysSinceRegistration = isset($_GET['days_since_registration']) ? (int)$_GET['days_since_registration'] : null;

    // Quick search parameters
    $searchType = isset($_GET['search_type']) ? strtolower(trim($_GET['search_type'])) : null;
    $searchValue = isset($_GET['search_value']) ? trim($_GET['search_value']) : null;

    // === GET USER GENDER ===
    $stmt = $pdo->prepare("SELECT gender FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if (!$user) {
        echo json_encode(["success" => false, "message" => "User not found"]);
        exit;
    }

    $gender = strtolower(trim($user['gender']));
    $oppositeGender = ($gender === 'male') ? 'female' : 'male';

    // === FETCH OPPOSITE GENDER USERS ===
    $sql = "
        SELECT
            u.id,
            u.firstName,
            u.lastName,
            u.email,
            u.gender,
            u.usertype,
            u.isVerified,
            u.profile_picture,
            u.privacy,
            u.created_at,
            ud.birthDate,
            TIMESTAMPDIFF(YEAR, ud.birthDate, CURDATE()) AS age,
            pa.city,
            ud.height_name,
            ud.religionId,
            ec.degree AS education,
            ec.annualincome,
            ul.drinks,
            ul.smoke
        FROM users u
        LEFT JOIN userpersonaldetail ud ON ud.userId = u.id
        LEFT JOIN permanent_address pa ON pa.userId = u.id
        LEFT JOIN educationcareer ec ON ec.userId = u.id
        LEFT JOIN user_lifestyle ul ON ul.userId = u.id
        WHERE TRIM(LOWER(u.gender)) = :opp_gender
          AND u.id != :me
    ";

    $params = [
        ':opp_gender' => $oppositeGender,
        ':me' => $userId
    ];

    // === APPLY FILTERS ===
    // Age filters
    if ($minAge !== null) {
        $sql .= " AND TIMESTAMPDIFF(YEAR, ud.birthDate, CURDATE()) >= :minAge";
        $params[':minAge'] = $minAge;
    }
    if ($maxAge !== null) {
        $sql .= " AND TIMESTAMPDIFF(YEAR, ud.birthDate, CURDATE()) <= :maxAge";
        $params[':maxAge'] = $maxAge;
    }

    // Height filters
    if ($minHeight !== null) {
        $sql .= " AND CAST(SUBSTRING_INDEX(ud.height_name, ' ', 1) AS UNSIGNED) >= :minHeight";
        $params[':minHeight'] = $minHeight;
    }
    if ($maxHeight !== null) {
        $sql .= " AND CAST(SUBSTRING_INDEX(ud.height_name, ' ', 1) AS UNSIGNED) <= :maxHeight";
        $params[':maxHeight'] = $maxHeight;
    }

    // Religion filter
    if ($religion !== null) {
        $sql .= " AND ud.religionId = :religion";
        $params[':religion'] = $religion;
    }

    // === NEW FILTERS ===
    // Has photo filter
    if ($hasPhoto) {
        $sql .= " AND u.profile_picture IS NOT NULL AND u.profile_picture != ''";
    }

    // User type filter (paid/free)
    if ($userType !== null && in_array($userType, ['paid', 'free'])) {
        $sql .= " AND TRIM(LOWER(u.usertype)) = :usertype";
        $params[':usertype'] = $userType;
    }

    // Verified filter
    if ($isVerified) {
        $sql .= " AND u.isVerified = 1";
    }

    // Days since registration filter
    if ($daysSinceRegistration !== null) {
        $sql .= " AND DATEDIFF(CURDATE(), u.created_at) <= :days_since_reg";
        $params[':days_since_reg'] = $daysSinceRegistration;
    }

    // === QUICK SEARCH FILTERS ===
    if ($searchType !== null && $searchValue !== null && $searchValue !== '') {
        switch ($searchType) {
            case 'phone':
                $sql .= " AND u.phone LIKE :search_value";
                $params[':search_value'] = '%' . $searchValue . '%';
                break;
            case 'id':
                if (is_numeric($searchValue)) {
                    $sql .= " AND u.id = :search_value";
                    $params[':search_value'] = (int)$searchValue;
                }
                break;
            case 'email':
                $sql .= " AND u.email LIKE :search_value";
                $params[':search_value'] = '%' . $searchValue . '%';
                break;
            case 'name':
                $sql .= " AND (u.firstName LIKE :search_value OR u.lastName LIKE :search_value)";
                $params[':search_value'] = '%' . $searchValue . '%';
                break;
        }
    }

    $sql .= " ORDER BY u.id DESC";

    $stmt2 = $pdo->prepare($sql);
    $stmt2->execute($params);

    $rows = $stmt2->fetchAll();

    $imageBaseUrl = 'https://digitallami.com/Api2/';

    foreach ($rows as &$row) {
        // Prepend base URL to profile picture
        if (!empty($row['profile_picture']) && !preg_match('/^https?:\/\//', $row['profile_picture'])) {
            $row['profile_picture'] = $imageBaseUrl . $row['profile_picture'];
        }

        // === PHOTO REQUEST LOGIC ===
        $stmtPhoto = $pdo->prepare("
            SELECT status
            FROM proposals
            WHERE request_type = 'Photo'
            AND (
                (sender_id = :me AND receiver_id = :other)
                OR
                (sender_id = :other AND receiver_id = :me)
            )
            ORDER BY id DESC
            LIMIT 1
        ");
        $stmtPhoto->execute([
            ":me"=>$userId,
            ":other"=>$row['id']
        ]);
        $photo_request = "not sent";
        if($r = $stmtPhoto->fetch()){
            $photo_request = ($r['status'] === 'accepted') ? 'accepted' : 'pending';
        }
        $row['photo_request'] = $photo_request;
    }

    $totalCount = count($rows);

    echo json_encode([
        "success" => true,
        "message" => "Opposite gender users fetched successfully",
        "total_count" => $totalCount,
        "data" => $rows
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => "Server error: " . $e->getMessage()
    ]);
}
?>
