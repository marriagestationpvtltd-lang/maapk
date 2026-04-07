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
    $projectId = "digitallamicomnp";
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    // Ensure all data values are strings (FCM v1 requirement).
    // Values that are already strings are passed through unchanged;
    // numbers and booleans are converted via strval(); other types
    // (arrays/objects) are JSON-encoded and a warning is logged.
    $string_data = [];
    foreach ($data as $k => $v) {
        if (is_string($v)) {
            $string_data[$k] = $v;
        } elseif (is_int($v) || is_float($v) || is_bool($v)) {
            $string_data[$k] = strval($v);
        } else {
            error_log("sendFCM: non-scalar value for key '$k' — encoding as JSON string");
            $string_data[$k] = json_encode($v);
        }
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
