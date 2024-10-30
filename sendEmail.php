<?php
require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

header("Content-Type: application/json");

function sendBatchedEmails($payload, $emailAddresses, $batchSize = 500) {
    $results = [];
    $batches = array_chunk($emailAddresses, $batchSize);

    foreach ($batches as $index => $batch) {
        $mail = new PHPMailer(true);
        try {
            $mail->isSMTP();
            $mail->Host = 'localhost';
            $mail->Port = 587; // Use port 587 for STARTTLS
            $mail->SMTPAuth = false; // No SMTP authentication for localhost
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS; // Use STARTTLS for port 587

            // DKIM settings (as a mounted file or environment variable)
            $mail->DKIM_domain = getenv('DKIM_DOMAIN');
            $mail->DKIM_selector = getenv('DKIM_SELECTOR');
            $mail->DKIM_private = getenv('DKIM_PRIVATE_KEY_PATH');
            $mail->DKIM_passphrase = '';
            $mail->DKIM_identity = $mail->From;

            // Set email content
            $mail->setFrom('contact@bursax.ro', 'Bursa X');
            foreach ($batch as $address) {
                $mail->addAddress($address);
            }
            $mail->Subject = $payload['subject'];
            $mail->Body    = $payload['html'];
            $mail->AltBody = $payload['text'];

            // Send email
            $mail->send();
            $results[] = "Batch " . ($index + 1) . " sent successfully.";
        } catch (Exception $e) {
            $results[] = "Batch " . ($index + 1) . " failed: {$mail->ErrorInfo}";
        }
        $mail->clearAddresses();
    }
    return $results;
}

$input = json_decode(file_get_contents('php://input'), true);
if (isset($input['payload']) && isset($input['emailAddresses'])) {
    $payload = $input['payload'];
    $emailAddresses = $input['emailAddresses'];
    $results = sendBatchedEmails($payload, $emailAddresses);
    echo json_encode(["results" => $results]);
} else {
    echo json_encode(["error" => "Invalid request"]);
}
?>
