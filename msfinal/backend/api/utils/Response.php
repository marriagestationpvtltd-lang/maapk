<?php
namespace App\Utils;

class Response {
    /**
     * Send a JSON success response
     */
    public static function success($data = null, $message = 'Success', $statusCode = 200) {
        http_response_code($statusCode);
        header('Content-Type: application/json');
        
        $response = [
            'success' => true,
            'message' => $message,
            'data' => $data,
            'timestamp' => time()
        ];
        
        echo json_encode($response, JSON_PRETTY_PRINT);
        exit;
    }
    
    /**
     * Send a JSON error response
     */
    public static function error($message = 'An error occurred', $statusCode = 400, $errors = null) {
        http_response_code($statusCode);
        header('Content-Type: application/json');
        
        $response = [
            'success' => false,
            'message' => $message,
            'errors' => $errors,
            'timestamp' => time()
        ];
        
        echo json_encode($response, JSON_PRETTY_PRINT);
        exit;
    }
    
    /**
     * Send a paginated response
     */
    public static function paginated($data, $total, $page, $perPage, $message = 'Data retrieved successfully') {
        $totalPages = ceil($total / $perPage);
        
        $response = [
            'data' => $data,
            'pagination' => [
                'total' => $total,
                'per_page' => $perPage,
                'current_page' => $page,
                'total_pages' => $totalPages,
                'has_next' => $page < $totalPages,
                'has_previous' => $page > 1
            ]
        ];
        
        self::success($response, $message);
    }
    
    /**
     * Send a validation error response
     */
    public static function validationError($errors) {
        self::error('Validation failed', 422, $errors);
    }
    
    /**
     * Send a not found response
     */
    public static function notFound($resource = 'Resource') {
        self::error("$resource not found", 404);
    }
    
    /**
     * Send an unauthorized response
     */
    public static function unauthorized($message = 'Unauthorized access') {
        self::error($message, 401);
    }
    
    /**
     * Send a forbidden response
     */
    public static function forbidden($message = 'Forbidden') {
        self::error($message, 403);
    }
    
    /**
     * Send a server error response
     */
    public static function serverError($message = 'Internal server error') {
        self::error($message, 500);
    }
    
    /**
     * Send a created response
     */
    public static function created($data = null, $message = 'Resource created successfully') {
        self::success($data, $message, 201);
    }
    
    /**
     * Send a no content response
     */
    public static function noContent() {
        http_response_code(204);
        exit;
    }
}
?>