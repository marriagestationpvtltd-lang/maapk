<?php
require __DIR__ . '/vendor/autoload.php';
use Google\Auth\Credentials\ServiceAccountCredentials;

function getAccessToken() {
    $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    $credentials = new ServiceAccountCredentials(
        $scopes,
        __DIR__ . '/service-account-key.json'
    );
    $token = $credentials->fetchAuthToken();
    return $token['access_token'];
}

function sendFCM($fcm_token, $title, $body, $data = []) {
    $projectId = "digitallami1";
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    $message = [
        "message" => [
            "token" => $fcm_token,
            "notification" => [
                "title" => $title,
                "body" => $body
            ],
            "data" => $data,
            "android" => [
                "priority" => "HIGH"
            ],
            "apns" => [
                "payload" => [
                    "aps" => [
                        "alert" => [
                            "title" => $title,
                            "body" => $body
                        ],
                        "sound" => "default",
                        "badge" => 1
                    ]
                ]
            ]
        ]
    ];

    $accessToken = getAccessToken();
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer $accessToken",
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));

    $response = curl_exec($ch);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) throw new Exception($error);

    return json_decode($response, true);
}
