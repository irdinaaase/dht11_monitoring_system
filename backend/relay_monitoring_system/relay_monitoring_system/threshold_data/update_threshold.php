<?php
header('Content-Type: application/json'); 
header("Access-Control-Allow-Origin: *");
error_reporting(E_ALL);
ini_set('display_errors', 1);

include_once("../dbconnect.php");

// Get POST data instead of GET
$data = json_decode(file_get_contents('php://input'), true);

$temp_threshold = isset($data['temp_threshold']) ? floatval($data['temp_threshold']) : null;
$hum_threshold = isset($data['hum_threshold']) ? floatval($data['hum_threshold']) : null;

if ($temp_threshold === null || $hum_threshold === null) {
    http_response_code(400);
    echo json_encode(["status" => "failed", "error" => "Missing parameters"]);
    exit();
}

// Add timestamp update
$sqlupdate = "UPDATE `tbl_threshold` SET `temp_threshold`=?, `hum_threshold`=?, `timestamp`=CURRENT_TIMESTAMP";
$stmt = $conn->prepare($sqlupdate);
$stmt->bind_param("dd", $temp_threshold, $hum_threshold);

if ($stmt->execute()) {
    echo json_encode(["status" => "success"]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "failed", "error" => $stmt->error]);
}

$stmt->close();
$conn->close();
?>