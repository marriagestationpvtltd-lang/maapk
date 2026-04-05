<?php
// generate_password.php
$password = 'admin123';
$hashed = password_hash($password, PASSWORD_DEFAULT);
echo "Password: $password\n";
echo "Hashed: $hashed\n";
?>