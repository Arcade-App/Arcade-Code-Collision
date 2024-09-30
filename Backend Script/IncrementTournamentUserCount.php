
<?php
// Include the database connection settings
require 'ConnectionSettings.php';

// Check if the connection is successful
if ($conn->connect_error) {
    echo json_encode(array("status" => "error", "message" => "Database connection failed: " . $conn->connect_error));
    exit();
}

// Sanitize and validate inputs
$tournamentId = filter_input(INPUT_POST, 'tournamentId', FILTER_VALIDATE_INT);

// Validate required fields
if (!$tournamentId) {
    echo json_encode(array("status" => "error", "message" => "Invalid input. Please provide a valid tournamentId."));
    exit();
}

// Prepare the SQL statement to fetch current playCount, prizePool, and playerJoiningFee for the specified tournamentId
$stmt = $conn->prepare("SELECT playCount, prizePool, playerJoiningFee FROM tournaments WHERE tournamentId = ?");
if (!$stmt) {
    echo json_encode(array("status" => "error", "message" => "Failed to prepare the SQL statement."));
    exit();
}

$stmt->bind_param("i", $tournamentId);
$stmt->execute();
$stmt->bind_result($playCount, $prizePool, $playerJoiningFee);

// Check if the tournament entry exists
if ($stmt->fetch()) {
    // Increment playCount and increase prizePool by playerJoiningFee
    $newPlayCount = $playCount + 1;
    $newPrizePool = $prizePool + $playerJoiningFee;

    // Close the previous statement
    $stmt->close();

    // Prepare the SQL statement to update playCount and prizePool
    $updateStmt = $conn->prepare("UPDATE tournaments SET playCount = ?, prizePool = ? WHERE tournamentId = ?");
    if (!$updateStmt) {
        echo json_encode(array("status" => "error", "message" => "Failed to prepare the SQL statement for update."));
        exit();
    }

    $updateStmt->bind_param("idi", $newPlayCount, $newPrizePool, $tournamentId);

    if ($updateStmt->execute()) {
        // Respond with success message and the updated playCount and prizePool
        echo json_encode(array(
            "status" => "success",
            "message" => "Play count and prize pool updated successfully.",
            "newPlayCount" => $newPlayCount,
            "newPrizePool" => $newPrizePool
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Failed to update play count and prize pool."));
    }

    $updateStmt->close();
} else {
    echo json_encode(array("status" => "error", "message" => "Tournament not found for the provided tournamentId."));
}

$conn->close();
?>
