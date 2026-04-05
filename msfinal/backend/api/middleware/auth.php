<?php
require_once __DIR__ . '/../utils/JWT.php';

function verifyJWT() {
    $token = JWT::getBearerToken();
    
    if (!$token) {
        return ['valid' => false, 'reason' => 'No token provided'];
    }
    
    return JWT::validate($token);
}

function requireAuth() {
    $auth = verifyJWT();
    
    if (!$auth['valid']) {
        Response::unauthorized($auth['reason'] ?? 'Unauthorized');
    }
    
    return $auth['data'];
}

function requireRole($role) {
    $auth = verifyJWT();
    
    if (!$auth['valid']) {
        Response::unauthorized($auth['reason'] ?? 'Unauthorized');
    }
    
    $userData = $auth['data'];
    
    if (!isset($userData['role']) || $userData['role'] !== $role) {
        Response::forbidden('Insufficient permissions');
    }
    
    return $userData;
}
?>