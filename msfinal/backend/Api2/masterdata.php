<?php
// get_master_data.php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

$resp = [
    'success' => false,
    'message' => '',
    'data' => null
];

try {
    $dbHost = 'localhost';
    $dbName = 'ms';
    $dbUser = 'ms';
    $dbPass = 'ms';
    $dbCharset = 'utf8mb4';

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        $resp['message'] = 'Method not allowed — use GET';
        echo json_encode($resp, JSON_UNESCAPED_UNICODE);
        exit;
    }

    if (!isset($_GET['userid']) || trim($_GET['userid']) === '') {
        http_response_code(400);
        $resp['message'] = 'Missing required parameter: userid';
        echo json_encode($resp, JSON_UNESCAPED_UNICODE);
        exit;
    }

    $userid = $_GET['userid'];

    $dsn = "mysql:host={$dbHost};dbname={$dbName};charset={$dbCharset}";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];
    $pdo = new PDO($dsn, $dbUser, $dbPass, $options);

    // Fetch user data
    $sql = "
        SELECT
            u.id,
            u.email,
            u.firstName,
            u.lastName,
            u.profile_picture,
            u.usertype,
            u.pageno,
            u.createdDate,
            COALESCE(u.status, 'not_uploaded') AS docstatus
        FROM users u
        LEFT JOIN user_documents ud ON u.id = ud.userid
        WHERE u.id = :userid
        LIMIT 1
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':userid', $userid);
    $stmt->execute();
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(404);
        $resp['message'] = 'User not found';
        echo json_encode($resp, JSON_UNESCAPED_UNICODE);
        exit;
    }

    $resp['success'] = true;
    $resp['message'] = 'User master data retrieved';
    $resp['data'] = $user;

    echo json_encode($resp, JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    error_log('masterdata.php PDOException: ' . $e->getMessage());
    $resp['message'] = 'Database error';
    echo json_encode($resp, JSON_UNESCAPED_UNICODE);
    exit;
} catch (Throwable $t) {
    http_response_code(500);
    error_log('masterdata.php Throwable: ' . $t->getMessage());
    $resp['message'] = 'Server error';
    echo json_encode($resp, JSON_UNESCAPED_UNICODE);
    exit;
}
