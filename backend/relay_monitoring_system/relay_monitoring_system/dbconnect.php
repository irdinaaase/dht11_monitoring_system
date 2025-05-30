<?php
$servername = "localhost";
$username   = "humancmt_dina_admin";
$password   = '4S=#@R_K3{N7';
$dbname     = "humancmt_dina_relaymonitordb";

$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    file_put_contents('php_errors.log', "Connection failed: " . $conn->connect_error . "\n", FILE_APPEND);
    die("Connection failed: " . $conn->connect_error);
}
?>