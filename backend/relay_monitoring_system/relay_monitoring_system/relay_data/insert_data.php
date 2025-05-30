<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

include_once("../dbconnect.php");

$device_id = $_GET['device_id'];
$temp = $_GET['temp'];
$hum = $_GET['hum'];
$relay_status = $_GET['relay_status'];

$sqlinsert = "INSERT INTO `tbl_dht11` (`device_id`, `temperature`, `humidity`, `relay_status`) 
              VALUES ('$device_id', '$temp', '$hum', '$relay_status')";

if ($conn->query($sqlinsert) === TRUE) {
    echo "success";
} else {
    echo "failed: " . $conn->error;
}
?>