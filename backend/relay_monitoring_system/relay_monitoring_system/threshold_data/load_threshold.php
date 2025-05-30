<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
error_reporting(E_ALL);
ini_set('display_errors', 1);

include_once("../dbconnect.php");

// Query to get thresholds
$sql = "SELECT temp_threshold, hum_threshold FROM tbl_threshold ORDER BY timestamp DESC LIMIT 1";
$result = $conn->query($sql);

if (!$result) {
    http_response_code(500);
    die(json_encode([
        "status" => "error",
        "message" => "Query failed: " . $conn->error
    ]));
}

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode([
        "status" => "success",
        "temp_threshold" => $row['temp_threshold'],
        "hum_threshold" => $row['hum_threshold']
    ]);
} else {
    http_response_code(404);
    echo json_encode([
        "status" => "error",
        "message" => "No thresholds found"
    ]);
}

$conn->close();
?>