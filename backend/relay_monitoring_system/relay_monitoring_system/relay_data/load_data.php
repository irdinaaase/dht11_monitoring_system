<?php
// Enable error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Log errors to a file
file_put_contents('php_errors.log', "Script accessed at " . date('Y-m-d H:i:s') . "\n", FILE_APPEND);
file_put_contents('php_errors.log', print_r($_GET, true), FILE_APPEND);

header('Content-Type: application/json');
include_once("../dbconnect.php");

$startDate = $_GET['start_date'] ?? date('Y-m-d', strtotime('-1 day'));
$endDate = $_GET['end_date'] ?? date('Y-m-d');


// Validate date format
function isValidDate($date) {
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) && strtotime($date);
}

if (!isValidDate($startDate) || !isValidDate($endDate)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid date format (YYYY-MM-DD required)']);
    exit;
}

// Convert to DateTime objects for additional validation
try {
    $startDateTime = new DateTime($startDate);
    $endDateTime = new DateTime($endDate);
    
    // Ensure end date is not before start date
    if ($endDateTime < $startDateTime) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'End date cannot be before start date']);
        exit;
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid date values']);
    exit;
}

// Use prepared statement to prevent SQL injection
$stmt = $conn->prepare("SELECT device_id, temperature, humidity, relay_status, timestamp 
                       FROM tbl_dht11 
                       WHERE timestamp BETWEEN ? AND ? 
                       ORDER BY timestamp DESC");

if (!$stmt) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database preparation error: ' . $conn->error]);
    exit;
}

// Bind parameters
$startDateTimeStr = $startDate . ' 00:00:00';
$endDateTimeStr = $endDate . ' 23:59:59';
$stmt->bind_param('ss', $startDateTimeStr, $endDateTimeStr);

// Execute query
if (!$stmt->execute()) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database execution error: ' . $stmt->error]);
    exit;
}

$result = $stmt->get_result();
$devices = [];

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $devices[] = [
            'device_id' => $row['device_id'],
            'temperature' => $row['temperature'],
            'humidity' => $row['humidity'],
            'relay_status' => $row['relay_status'],
            'timestamp' => $row['timestamp']
        ];
    }
}

// Return success response
echo json_encode([
    'status' => 'success',
    'data' => $devices
]);

$stmt->close();
$conn->close();
?>