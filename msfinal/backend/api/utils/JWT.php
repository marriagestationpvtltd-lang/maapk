<?php
namespace App\Utils;

use \Firebase\JWT\JWT as FirebaseJWT;
use \Firebase\JWT\Key;

class JWT {
    private static $secretKey;
    private static $algorithm = 'HS256';
    
    public static function init($secretKey) {
        self::$secretKey = $secretKey;
    }
    
    public static function encode($payload) {
        if (empty(self::$secretKey)) {
            throw new \Exception('JWT secret key not set');
        }
        
        $payload['iat'] = time();
        $payload['iss'] = $_SERVER['HTTP_HOST'] ?? 'memorial-chat-api';
        
        return FirebaseJWT::encode($payload, self::$secretKey, self::$algorithm);
    }
    
    public static function decode($token) {
        if (empty(self::$secretKey)) {
            throw new \Exception('JWT secret key not set');
        }
        
        try {
            $decoded = FirebaseJWT::decode($token, new Key(self::$secretKey, self::$algorithm));
            return (array) $decoded;
        } catch (\Exception $e) {
            throw new \Exception('Invalid token: ' . $e->getMessage());
        }
    }
    
    public static function validate($token) {
        try {
            $decoded = self::decode($token);
            
            // Check expiration
            if (isset($decoded['exp']) && $decoded['exp'] < time()) {
                return ['valid' => false, 'reason' => 'Token expired'];
            }
            
            // Check issuer
            if (isset($decoded['iss']) && $decoded['iss'] !== ($_SERVER['HTTP_HOST'] ?? 'memorial-chat-api')) {
                return ['valid' => false, 'reason' => 'Invalid issuer'];
            }
            
            return ['valid' => true, 'data' => $decoded];
        } catch (\Exception $e) {
            return ['valid' => false, 'reason' => $e->getMessage()];
        }
    }
    
    public static function getBearerToken() {
        $headers = null;
        
        if (isset($_SERVER['Authorization'])) {
            $headers = trim($_SERVER['Authorization']);
        } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $headers = trim($_SERVER['HTTP_AUTHORIZATION']);
        } elseif (function_exists('apache_request_headers')) {
            $requestHeaders = apache_request_headers();
            $requestHeaders = array_combine(
                array_map('ucwords', array_keys($requestHeaders)),
                array_values($requestHeaders)
            );
            if (isset($requestHeaders['Authorization'])) {
                $headers = trim($requestHeaders['Authorization']);
            }
        }
        
        if (!empty($headers) && preg_match('/Bearer\s(\S+)/', $headers, $matches)) {
            return $matches[1];
        }
        
        return null;
    }
}
?>