<?php
require_once '/www/wwwroot/digitallami.com/api/vendor/autoload.php';

use Kreait\Firebase\Factory;
use Kreait\Firebase\ServiceAccount;

class FirebaseConfig {
    private static $firebase;
    
    public static function init() {
        if (self::$firebase === null) {
            $serviceAccount = ServiceAccount::fromJsonFile(__DIR__ . '/../../firebase-credentials.json');
            self::$firebase = (new Factory)
                ->withServiceAccount($serviceAccount)
                ->withDatabaseUri('https://digitallamicomnp-default-rtdb.firebaseio.com/')
                ->create();
        }
        return self::$firebase;
    }
    
    public static function getDatabase() {
        $firebase = self::init();
        return $firebase->getDatabase();
    }
}
?>