# PHP Email API with DKIM for Google Cloud Run

This project sets up a PHP REST API for sending emails in batches with DKIM signing, containerized with Docker and deployed to Google Cloud Run.

## Features

- Sends emails in batches (e.g., 500 recipients at a time)
- DKIM signing for improved deliverability
- Scalable on-demand deployment with Google Cloud Run

---

## Prerequisites

- PHP and Docker installed on your local machine
- Google Cloud SDK installed and configured
- [Google Cloud Project](https://console.cloud.google.com/) with billing enabled

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-repo/php-email-api.git
cd php-email-api
```

### 2. Set Up Docker Environment

#### Dockerfile

The `Dockerfile` sets up a PHP environment with Apache and installs necessary dependencies:

```Dockerfile
# Use an official PHP image with Apache
FROM php:8.1-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    curl \
    unzip \
    git \
    && docker-php-ext-install pdo_mysql mbstring

# Enable Apache rewrite module
RUN a2enmod rewrite

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy the app files
COPY . .

# Install PHP dependencies (PHPMailer)
RUN composer install

# Expose port 8080 for Cloud Run
EXPOSE 8080

# Set up the Apache server to listen on port 8080
CMD ["apache2-foreground"]
```

#### composer.json

To install `PHPMailer`, the `composer.json` file includes:

```json
{
  "require": {
    "phpmailer/phpmailer": "^6.5"
  }
}
```

#### Email API Endpoint

The core API logic is implemented in `sendEmail.php`:

```php
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
            $mail->Port = 25;

            // DKIM settings (as a mounted file or environment variable)
            $mail->DKIM_domain = getenv('DKIM_DOMAIN');
            $mail->DKIM_selector = getenv('DKIM_SELECTOR');
            $mail->DKIM_private = getenv('DKIM_PRIVATE_KEY_PATH');
            $mail->DKIM_passphrase = '';
            $mail->DKIM_identity = $mail->From;

            // Set email content
            $mail->setFrom('your-email@example.com', 'Your Name');
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

```

---

## DKIM Configuration

### 1. Generate a DKIM Key Pair

```bash
openssl genpkey -algorithm RSA -out dkim_private.key -pkeyopt rsa_keygen_bits:2048
openssl rsa -in dkim_private.key -pubout -out dkim_public.key
```

### 2. Add DKIM to Your DNS

- Add the public key (`dkim_public.key`) to your DNS as a TXT record with a selector (e.g., `selector._domainkey.yourdomain.com`).

### 3. Store DKIM Private Key in Google Secret Manager (Optional)

```bash
echo -n "YOUR_PRIVATE_KEY_CONTENT" | gcloud secrets create dkim_private_key --data-file=-
```

Grant access to Cloud Run:

```bash
gcloud secrets add-iam-policy-binding dkim_private_key     --member="serviceAccount:[CLOUD_RUN_SERVICE_ACCOUNT]"     --role="roles/secretmanager.secretAccessor"
```

---

## Building and Running Locally

1. **Build the Docker Image**

   ```bash
   docker build -t php-email-api .
   ```

2. **Run the Docker Container Locally**

   ```bash
   docker run -p 8080:8080 --env-file .env php-email-api
   ```

3. **Test the API**

   ```bash
   curl -X POST http://localhost:8080/sendEmail.php         -H "Content-Type: application/json"         -d '{
              "payload": {
                  "subject": "Test Email",
                  "text": "This is a test email.",
                  "html": "<p>This is a test email.</p>"
              },
              "emailAddresses": ["user1@example.com", "user2@example.com"]
            }'
   ```

---

## Deploy to Google Cloud Run

1. **Authenticate with Google Cloud**

   ```bash
   gcloud auth login
   gcloud config set project [YOUR_PROJECT_ID]
   ```

2. **Push the Docker Image to Google Container Registry**

   ```bash
   docker tag php-email-api gcr.io/[YOUR_PROJECT_ID]/php-email-api
   docker push gcr.io/[YOUR_PROJECT_ID]/php-email-api
   ```

3. **Deploy the Image to Cloud Run**

   ```bash
   gcloud run deploy php-email-api        --image gcr.io/[YOUR_PROJECT_ID]/php-email-api        --platform managed        --region [YOUR_REGION]        --allow-unauthenticated        --set-env-vars DKIM_DOMAIN=yourdomain.com,DKIM_SELECTOR=selector        --set-secrets DKIM_PRIVATE_KEY_PATH=dkim_private_key:latest
   ```

---

## Environment Variables

- **DKIM_DOMAIN**: Your domain name (e.g., `yourdomain.com`)
- **DKIM_SELECTOR**: The DKIM selector set up in DNS (e.g., `selector`)
- **DKIM_PRIVATE_KEY_PATH**: Path to the private DKIM key or mounted secret

---

## Security and Best Practices

1. **Use Google Secret Manager** for storing sensitive information, such as the DKIM private key.
2. **Configure SPF, DKIM, and DMARC** in your DNS for improved email security.
3. **Scale and Optimize** using Cloud Run's on-demand scaling.

---

## License

This project is licensed under the MIT License.

---

## Contributing

Feel free to open issues and submit pull requests to help improve the functionality and robustness of this email API.
