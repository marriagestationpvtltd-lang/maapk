<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

$conn = new mysqli("localhost", "ms", "ms", "ms");
if ($conn->connect_error) {
    die(json_encode(["status"=>"error","message"=>$conn->connect_error]));
}

$data = json_decode(file_get_contents("php://input"), true);
if (!$data) {
    die(json_encode(["status"=>"error","message"=>"Invalid JSON"]));
}

$userid           = isset($data["userid"]) ? intval($data["userid"]) : 0;
$minage           = $data["minage"] ?? '';
$maxage           = $data["maxage"] ?? '';
$minheight        = $data["minheight"] ?? '';
$maxheight        = $data["maxheight"] ?? '';
$maritalstatus    = $data["maritalstatus"] ?? '';
$profilewithchild = $data["profilewithchild"] ?? '';
$familytype       = $data["familytype"] ?? '';
$religion         = $data["religion"] ?? '';
$caste            = $data["caste"] ?? '';
$subcaste         = $data["subcaste"] ?? '';
$mothertoungue    = $data["mothertoungue"] ?? '';
$herscopeblief    = $data["herscopeblief"] ?? '';
$manglik          = $data["manglik"] ?? '';
$country          = $data["country"] ?? '';
$state            = $data["state"] ?? '';
$city             = $data["city"] ?? '';
$qualification    = $data["qualification"] ?? '';
$educationmedium  = $data["educationmedium"] ?? '';
$proffession      = $data["proffession"] ?? '';
$workingwith      = $data["workingwith"] ?? '';
$annualincome     = $data["annualincome"] ?? '';
$diet             = $data["diet"] ?? '';
$smokeaccept      = $data["smokeaccept"] ?? '';
$drinkaccept      = $data["drinkaccept"] ?? '';
$disabilityaccept = $data["disabilityaccept"] ?? '';
$complexion       = $data["complexion"] ?? '';
$bodytype         = $data["bodytype"] ?? '';
$otherexpectation = $data["otherexpectation"] ?? '';

if ($userid <= 0) {
    die(json_encode(["status"=>"error","message"=>"userid required"]));
}

$check = $conn->prepare("SELECT id FROM user_partner WHERE userid = ?");
$check->bind_param("i", $userid);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    $check->close();
    $stmt = $conn->prepare("UPDATE user_partner SET
        minage=?, maxage=?,
        minheight=?, maxheight=?,
        maritalstatus=?,
        profilewithchild=?,
        familytype=?,
        religion=?,
        caste=?,
        subcaste=?,
        mothertoungue=?,
        herscopeblief=?,
        manglik=?,
        country=?,
        state=?,
        city=?,
        qualification=?,
        educationmedium=?,
        proffession=?,
        workingwith=?,
        annualincome=?,
        diet=?,
        smokeaccept=?,
        drinkaccept=?,
        disabilityaccept=?,
        complexion=?,
        bodytype=?,
        otherexpectation=?
        WHERE userid=?");
    $stmt->bind_param(
        "ssssssssssssssssssssssssssssi",
        $minage, $maxage,
        $minheight, $maxheight,
        $maritalstatus,
        $profilewithchild,
        $familytype,
        $religion,
        $caste,
        $subcaste,
        $mothertoungue,
        $herscopeblief,
        $manglik,
        $country,
        $state,
        $city,
        $qualification,
        $educationmedium,
        $proffession,
        $workingwith,
        $annualincome,
        $diet,
        $smokeaccept,
        $drinkaccept,
        $disabilityaccept,
        $complexion,
        $bodytype,
        $otherexpectation,
        $userid
    );
} else {
    $check->close();
    $stmt = $conn->prepare("INSERT INTO user_partner(
        userid,minage,maxage,minheight,maxheight,maritalstatus,profilewithchild,
        familytype,religion,caste,subcaste,mothertoungue,herscopeblief,manglik,
        country,state,city,qualification,educationmedium,proffession,workingwith,
        annualincome,diet,smokeaccept,drinkaccept,disabilityaccept,complexion,
        bodytype,otherexpectation
    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    $stmt->bind_param(
        "isssssssssssssssssssssssssss",
        $userid,
        $minage, $maxage,
        $minheight, $maxheight,
        $maritalstatus,
        $profilewithchild,
        $familytype,
        $religion,
        $caste,
        $subcaste,
        $mothertoungue,
        $herscopeblief,
        $manglik,
        $country,
        $state,
        $city,
        $qualification,
        $educationmedium,
        $proffession,
        $workingwith,
        $annualincome,
        $diet,
        $smokeaccept,
        $drinkaccept,
        $disabilityaccept,
        $complexion,
        $bodytype,
        $otherexpectation
    );
}

if ($stmt->execute()) {
    echo json_encode(["status"=>"success"]);
} else {
    echo json_encode(["status"=>"error","message"=>$stmt->error]);
}
$stmt->close();
$conn->close();
