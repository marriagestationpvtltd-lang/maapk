<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Base URL for profile pictures
$base_url = "https://digitallami.com/Api2/";

// Database configuration
$host = "localhost"; 
$db_name = "ms";
$username = "ms";
$password = "ms";

// Create connection
$conn = new mysqli($host, $username, $password, $db_name);

// Check connection
if ($conn->connect_error) {
    die(json_encode([
        "status" => "error",
        "message" => "Database connection failed: " . $conn->connect_error
    ]));
}

// Get userid from GET or POST
$userid = isset($_GET['userid']) ? intval($_GET['userid']) : 0;
$myid   = isset($_GET['myid']) ? intval($_GET['myid']) : 0;
if ($userid <= 0 || $myid <= 0) {
    echo json_encode([
        "status" => "error",
        "message" => "Invalid user ID"
    ]);
    exit;
}


$photo_request = "not sent";

$photoSql = "
SELECT status 
FROM proposals
WHERE request_type = 'Photo'
AND (
    (sender_id = ? AND receiver_id = ?)
    OR
    (sender_id = ? AND receiver_id = ?)
)
ORDER BY id DESC
LIMIT 1
";

$photoStmt = $conn->prepare($photoSql);
$photoStmt->bind_param("iiii", $myid, $userid, $userid, $myid);
$photoStmt->execute();
$photoResult = $photoStmt->get_result();

if ($photoResult->num_rows > 0) {
    $photoRow = $photoResult->fetch_assoc();
    $photo_request = ($photoRow['status'] === 'accepted') ? 'accepted' : 'pending';
}
$photoStmt->close();

// Prepare SQL statement for full profile including partner preferences
$sql = "
SELECT 
    u.firstName, u.lastName, u.profile_picture, u.usertype, u.isVerified,
    u.privacy,  -- added privacy

    -- Permanent address
    pa.city, pa.country,

    -- Education career / Profession
    ec.educationmedium AS ec_educationmedium,
    ec.educationtype, ec.faculty, ec.degree,
    ec.areyouworking, ec.occupationtype, ec.companyname,
    ec.designation AS ec_designation,
    ec.workingwith AS ec_workingwith, ec.annualincome AS ec_annualincome, ec.businessname,

    -- Personal details
    up.memberid, up.height_name, up.maritalStatusId, ms.name AS maritalStatusName,
    up.motherTongue, up.aboutMe, up.birthDate, up.Disability, up.bloodGroup,
    r.name AS religionName,
    c.name AS communityName,
    sc.name AS subCommunityName,

    -- Astrologic details
    ua.manglik, ua.birthtime, ua.birthcity,

    -- Family details
    uf.id AS familyId, uf.familytype, uf.familybackground,
    uf.fatherstatus, uf.fathername, uf.fathereducation, uf.fatheroccupation,
    uf.motherstatus, uf.mothercaste, uf.mothereducation, uf.motheroccupation, uf.familyorigin,

    -- Lifestyle details
    ul.id AS lifestyleId, ul.smoketype, ul.diet, ul.drinks, ul.drinktype, ul.smoke,

    -- Partner preferences
    upa.minage, upa.maxage, upa.maritalstatus, upa.profilewithchild,
    upa.familytype AS partnerFamilyType, upa.religion AS partnerReligion, upa.caste AS partnerCaste,
    upa.mothertoungue AS partnerMotherTongue, upa.herscopeblief, upa.manglik AS partnerManglik,
    upa.country AS partnerCountry, upa.state AS partnerState, upa.city AS partnerCity,
    upa.qualification AS partnerQualification, upa.educationmedium AS partnerEducationMedium,
    upa.proffession AS partnerProfession, upa.workingwith AS partnerWorkingWith, upa.annualincome AS partnerAnnualIncome,
    upa.diet AS partnerDiet, upa.smokeaccept, upa.drinkaccept, upa.disabilityaccept,
    upa.complexion AS partnerComplexion, upa.bodytype AS partnerBodyType, upa.otherexpectation AS partnerOtherExpectation

FROM users u
LEFT JOIN permanent_address pa ON u.id = pa.userid
LEFT JOIN educationcareer ec ON u.id = ec.userid
LEFT JOIN userpersonaldetail up ON u.id = up.userid
LEFT JOIN maritalstatus ms ON up.maritalStatusId = ms.id
LEFT JOIN religion r ON up.religionId = r.id
LEFT JOIN community c ON up.communityId = c.id
LEFT JOIN subcommunity sc ON up.subCommunityId = sc.id
LEFT JOIN user_astrologic ua ON u.id = ua.userid
LEFT JOIN user_family uf ON u.id = uf.userid
LEFT JOIN user_lifestyle ul ON u.id = ul.userid
LEFT JOIN user_partner upa ON u.id = upa.userid
WHERE u.id = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $userid);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();

    // Prefix profile picture with base URL if not empty
    $profile_picture = !empty($row['profile_picture']) ? $base_url . $row['profile_picture'] : "";

    // Restructure JSON into sections
   // Prefix profile picture with base URL if not empty
$profile_picture = !empty($row['profile_picture']) ? $base_url . $row['profile_picture'] : "";

// Define a default value
$default = "Not available"; // You can change this to any default value you like

// Privacy filtering: Determine what information to show based on privacy settings
$privacy = $row['privacy'] ?? 'free';
$showFullDetails = ($privacy === 'free') || ($photo_request === 'accepted');

// Helper function to apply privacy filter
function applyPrivacy($value, $showFull, $default = "Not available") {
    return $showFull ? ($value ?? $default) : $default;
}

// For sensitive data, always hide unless access is granted
function applySensitivePrivacy($value, $showFull, $default = "Hidden") {
    return $showFull ? ($value ?? $default) : $default;
}

// Restructure JSON into sections with null coalescing and privacy filtering
$data = [
    "personalDetail" => [
        "photo_request" => $photo_request, // ✅ INCLUDED

        "firstName" => $row['firstName'] ?? $default,
        "lastName" => $row['lastName'] ?? $default,
        "profile_picture" => $profile_picture,
        "usertype" => $row['usertype'] ?? $default,
        "isVerified" => $row['isVerified'] ?? $default,
        "privacy" => $privacy,

        // Public info - always show
        "city" => $row['city'] ?? $default,
        "country" => $row['country'] ?? $default,
        "height_name" => $row['height_name'] ?? $default,
        "maritalStatusId" => $row['maritalStatusId'] ?? $default,
        "maritalStatusName" => $row['maritalStatusName'] ?? $default,
        "motherTongue" => $row['motherTongue'] ?? $default,
        "aboutMe" => $row['aboutMe'] ?? $default,
        "religionName" => $row['religionName'] ?? $default,
        "communityName" => $row['communityName'] ?? $default,
        "subCommunityName" => $row['subCommunityName'] ?? $default,

        // Education/Career - show based on privacy
        "educationmedium" => applyPrivacy($row['ec_educationmedium'], $showFullDetails, $default),
        "educationtype" => applyPrivacy($row['educationtype'], $showFullDetails, $default),
        "faculty" => applyPrivacy($row['faculty'], $showFullDetails, $default),
        "degree" => applyPrivacy($row['degree'], $showFullDetails, $default),
        "areyouworking" => applyPrivacy($row['areyouworking'], $showFullDetails, $default),
        "occupationtype" => applyPrivacy($row['occupationtype'], $showFullDetails, $default),
        "companyname" => applyPrivacy($row['companyname'], $showFullDetails, $default),
        "designation" => applyPrivacy($row['ec_designation'], $showFullDetails, $default),
        "workingwith" => applyPrivacy($row['ec_workingwith'], $showFullDetails, $default),
        "annualincome" => applyPrivacy($row['ec_annualincome'], $showFullDetails, $default),
        "businessname" => applyPrivacy($row['businessname'], $showFullDetails, $default),

        // Personal details - show based on privacy
        "memberid" => $row['memberid'] ?? $default,
        "Disability" => applyPrivacy($row['Disability'], $showFullDetails, $default),
        "bloodGroup" => applyPrivacy($row['bloodGroup'], $showFullDetails, $default),

        // Sensitive info - hide exact birthdate, show only age-related info with privacy
        "birthDate" => applySensitivePrivacy($row['birthDate'], $showFullDetails, "Hidden"),

        // Astrological - show based on privacy
        "manglik" => applyPrivacy($row['manglik'], $showFullDetails, $default),
        "birthtime" => applySensitivePrivacy($row['birthtime'], $showFullDetails, "Hidden"),
        "birthcity" => applyPrivacy($row['birthcity'], $showFullDetails, $default)
    ],
    "familyDetail" => [
        "familyId" => applyPrivacy($row['familyId'], $showFullDetails, $default),
        "familytype" => applyPrivacy($row['familytype'], $showFullDetails, $default),
        "familybackground" => applyPrivacy($row['familybackground'], $showFullDetails, $default),

        // Sensitive family info - hide names
        "fatherstatus" => applyPrivacy($row['fatherstatus'], $showFullDetails, $default),
        "fathername" => applySensitivePrivacy($row['fathername'], $showFullDetails, "Hidden"),
        "fathereducation" => applyPrivacy($row['fathereducation'], $showFullDetails, $default),
        "fatheroccupation" => applyPrivacy($row['fatheroccupation'], $showFullDetails, $default),
        "motherstatus" => applyPrivacy($row['motherstatus'], $showFullDetails, $default),
        "mothercaste" => applyPrivacy($row['mothercaste'], $showFullDetails, $default),
        "mothereducation" => applyPrivacy($row['mothereducation'], $showFullDetails, $default),
        "motheroccupation" => applyPrivacy($row['motheroccupation'], $showFullDetails, $default),
        "familyorigin" => applyPrivacy($row['familyorigin'], $showFullDetails, $default)
    ],
    "lifestyle" => [
        "lifestyleId" => applyPrivacy($row['lifestyleId'], $showFullDetails, $default),
        "smoketype" => applyPrivacy($row['smoketype'], $showFullDetails, $default),
        "diet" => applyPrivacy($row['diet'], $showFullDetails, $default),
        "drinks" => applyPrivacy($row['drinks'], $showFullDetails, $default),
        "drinktype" => applyPrivacy($row['drinktype'], $showFullDetails, $default),
        "smoke" => applyPrivacy($row['smoke'], $showFullDetails, $default)
    ],
    "partner" => [
        "minage" => $row['minage'] ?? $default,
        "maxage" => $row['maxage'] ?? $default,
        "minweight" => $row['minweight'] ?? $default,
        "maxweight" => $row['maxweight'] ?? $default,
        "maritalstatus" => $row['maritalstatus'] ?? $default,
        "profilewithchild" => $row['profilewithchild'] ?? $default,
        "familytype" => $row['partnerFamilyType'] ?? $default,
        "religion" => $row['partnerReligion'] ?? $default,
        "caste" => $row['partnerCaste'] ?? $default,
        "mothertoungue" => $row['partnerMotherTongue'] ?? $default,
        "herscopeblief" => $row['herscopeblief'] ?? $default,
        "manglik" => $row['partnerManglik'] ?? $default,
        "country" => $row['partnerCountry'] ?? $default,
        "state" => $row['partnerState'] ?? $default,
        "city" => $row['partnerCity'] ?? $default,
        "qualification" => $row['partnerQualification'] ?? $default,
        "educationmedium" => $row['partnerEducationMedium'] ?? $default,
        "proffession" => $row['partnerProfession'] ?? $default,
        "workingwith" => $row['partnerWorkingWith'] ?? $default,
        "annualincome" => $row['partnerAnnualIncome'] ?? $default,
        "diet" => $row['partnerDiet'] ?? $default,
        "smokeaccept" => $row['smokeaccept'] ?? $default,
        "drinkaccept" => $row['drinkaccept'] ?? $default,
        "disabilityaccept" => $row['disabilityaccept'] ?? $default,
        "complexion" => $row['partnerComplexion'] ?? $default,
        "bodytype" => $row['partnerBodyType'] ?? $default,
        "otherexpectation" => $row['partnerOtherExpectation'] ?? $default
    ]
];

    echo json_encode([
        "status" => "success",
        "data" => $data
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "User not found"
    ]);
}

$stmt->close();
$conn->close();
?>
