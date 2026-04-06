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

/**
 * Send an FCM v1 message.
 *
 * @param string $fcm_token   Recipient FCM token.
 * @param string $title       Notification title.
 * @param string $body        Notification body.
 * @param array  $data        Extra data payload (all values must be strings).
 * @param string $channel_id  Android notification channel ID (default: general_notifications).
 * @param bool   $is_call     When true, sets max priority and visibility for call notifications.
 */
function sendFCM($fcm_token, $title, $body, $data = [], $channel_id = 'general_notifications', $is_call = false) {
    $projectId = "digitallami1";
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    // Ensure all data values are strings (FCM v1 requirement)
    $string_data = [];
    foreach ($data as $k => $v) {
        $string_data[$k] = is_string($v) ? $v : json_encode($v);
    }

    $android_notification = [
        'channel_id' => $channel_id,
        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
    ];

    if ($is_call) {
        $android_notification['notification_priority'] = 'PRIORITY_MAX';
        $android_notification['visibility'] = 'PUBLIC';
        $android_notification['default_sound'] = true;
        $android_notification['default_vibrate_timings'] = true;
    }

    $message = [
        "message" => [
            "token" => $fcm_token,
            "notification" => [
                "title" => $title,
                "body" => $body
            ],
            "data" => $string_data,
            "android" => [
                "priority" => "HIGH",
                "notification" => $android_notification
            ],
            "apns" => [
                "headers" => [
                    "apns-priority" => $is_call ? "10" : "5"
                ],
                "payload" => [
                    "aps" => [
                        "alert" => [
                            "title" => $title,
                            "body" => $body
                        ],
                        "sound" => "default",
                        "badge" => 1,
                        "content-available" => 1
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
