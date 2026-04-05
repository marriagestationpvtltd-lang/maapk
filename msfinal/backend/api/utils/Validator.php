<?php
namespace App\Utils;

class Validator {
    /**
     * Validate required fields
     */
    public static function validateRequired($data, $fields) {
        $errors = [];
        
        foreach ($fields as $field) {
            if (!isset($data[$field]) || empty(trim($data[$field]))) {
                $errors[$field] = "The $field field is required";
            }
        }
        
        return empty($errors) ? null : $errors;
    }
    
    /**
     * Validate email format
     */
    public static function validateEmail($email) {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return 'Invalid email format';
        }
        return null;
    }
    
    /**
     * Validate password strength
     */
    public static function validatePassword($password) {
        if (strlen($password) < 8) {
            return 'Password must be at least 8 characters long';
        }
        
        if (!preg_match('/[A-Z]/', $password)) {
            return 'Password must contain at least one uppercase letter';
        }
        
        if (!preg_match('/[a-z]/', $password)) {
            return 'Password must contain at least one lowercase letter';
        }
        
        if (!preg_match('/[0-9]/', $password)) {
            return 'Password must contain at least one number';
        }
        
        return null;
    }
    
    /**
     * Validate phone number
     */
    public static function validatePhone($phone) {
        // Remove all non-digit characters
        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        
        if (strlen($cleanPhone) < 10 || strlen($cleanPhone) > 15) {
            return 'Invalid phone number length';
        }
        
        return null;
    }
    
    /**
     * Validate URL
     */
    public static function validateUrl($url) {
        if (!filter_var($url, FILTER_VALIDATE_URL)) {
            return 'Invalid URL format';
        }
        return null;
    }
    
    /**
     * Validate numeric range
     */
    public static function validateRange($value, $min, $max, $field) {
        if (!is_numeric($value)) {
            return "$field must be a number";
        }
        
        if ($value < $min || $value > $max) {
            return "$field must be between $min and $max";
        }
        
        return null;
    }
    
    /**
     * Validate string length
     */
    public static function validateLength($value, $field, $min = 1, $max = 255) {
        $length = strlen(trim($value));
        
        if ($length < $min) {
            return "$field must be at least $min characters long";
        }
        
        if ($length > $max) {
            return "$field must not exceed $max characters";
        }
        
        return null;
    }
    
    /**
     * Validate date format
     */
    public static function validateDate($date, $format = 'Y-m-d') {
        $d = \DateTime::createFromFormat($format, $date);
        if (!$d || $d->format($format) !== $date) {
            return "Date must be in format: $format";
        }
        return null;
    }
    
    /**
     * Validate array
     */
    public static function validateArray($value, $field) {
        if (!is_array($value)) {
            return "$field must be an array";
        }
        
        if (empty($value)) {
            return "$field must not be empty";
        }
        
        return null;
    }
    
    /**
     * Validate JSON string
     */
    public static function validateJson($value, $field) {
        json_decode($value);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return "$field must be valid JSON";
        }
        return null;
    }
    
    /**
     * Validate enum value
     */
    public static function validateEnum($value, $field, $allowedValues) {
        if (!in_array($value, $allowedValues)) {
            $allowed = implode(', ', $allowedValues);
            return "$field must be one of: $allowed";
        }
        return null;
    }
    
    /**
     * Validate alphanumeric
     */
    public static function validateAlphanumeric($value, $field) {
        if (!ctype_alnum(str_replace(['_', '-'], '', $value))) {
            return "$field must contain only letters, numbers, underscores and hyphens";
        }
        return null;
    }
    
    /**
     * Comprehensive validation method
     */
    public static function validate($data, $rules) {
        $errors = [];
        
        foreach ($rules as $field => $ruleSet) {
            $value = $data[$field] ?? null;
            $fieldErrors = [];
            
            foreach ($ruleSet as $rule => $params) {
                $error = null;
                
                switch ($rule) {
                    case 'required':
                        if (empty($value) && $value !== '0') {
                            $error = "The $field field is required";
                        }
                        break;
                        
                    case 'email':
                        if (!empty($value) && ($error = self::validateEmail($value))) {
                            $error = "Invalid email address";
                        }
                        break;
                        
                    case 'password':
                        if (!empty($value) && ($error = self::validatePassword($value))) {
                            // Keep the detailed error from validatePassword
                        }
                        break;
                        
                    case 'min':
                        $min = $params;
                        if (strlen($value) < $min) {
                            $error = "$field must be at least $min characters";
                        }
                        break;
                        
                    case 'max':
                        $max = $params;
                        if (strlen($value) > $max) {
                            $error = "$field must not exceed $max characters";
                        }
                        break;
                        
                    case 'numeric':
                        if (!empty($value) && !is_numeric($value)) {
                            $error = "$field must be a number";
                        }
                        break;
                        
                    case 'url':
                        if (!empty($value) && ($error = self::validateUrl($value))) {
                            $error = "Invalid URL format";
                        }
                        break;
                        
                    case 'date':
                        $format = $params ?? 'Y-m-d';
                        if (!empty($value) && ($error = self::validateDate($value, $format))) {
                            // Keep the detailed error
                        }
                        break;
                        
                    case 'in':
                        if (!empty($value) && !in_array($value, $params)) {
                            $allowed = implode(', ', $params);
                            $error = "$field must be one of: $allowed";
                        }
                        break;
                        
                    case 'regex':
                        if (!empty($value) && !preg_match($params, $value)) {
                            $error = "$field format is invalid";
                        }
                        break;
                        
                    case 'array':
                        if (!empty($value) && !is_array($value)) {
                            $error = "$field must be an array";
                        }
                        break;
                        
                    case 'boolean':
                        if (!is_bool($value) && $value !== '0' && $value !== '1' && $value !== 0 && $value !== 1) {
                            $error = "$field must be a boolean";
                        }
                        break;
                }
                
                if ($error) {
                    $fieldErrors[] = $error;
                }
            }
            
            if (!empty($fieldErrors)) {
                $errors[$field] = $fieldErrors;
            }
        }
        
        return empty($errors) ? null : $errors;
    }
    
    /**
     * Sanitize input data
     */
    public static function sanitize($data) {
        if (is_array($data)) {
            foreach ($data as $key => $value) {
                $data[$key] = self::sanitize($value);
            }
            return $data;
        }
        
        if (is_string($data)) {
            // Trim whitespace
            $data = trim($data);
            
            // Prevent XSS attacks
            $data = htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
            
            // Remove extra spaces
            $data = preg_replace('/\s+/', ' ', $data);
        }
        
        return $data;
    }
    
    /**
     * Get filtered input
     */
    public static function getFilteredInput($fields) {
        $input = [];
        
        foreach ($fields as $field) {
            if (isset($_POST[$field])) {
                $input[$field] = self::sanitize($_POST[$field]);
            } elseif (isset($_GET[$field])) {
                $input[$field] = self::sanitize($_GET[$field]);
            } else {
                $input[$field] = null;
            }
        }
        
        return $input;
    }
    
    /**
     * Get JSON input
     */
    public static function getJsonInput() {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            return null;
        }
        
        return self::sanitize($data);
    }
}
?>