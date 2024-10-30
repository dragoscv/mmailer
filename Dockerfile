# Use an official PHP image with Apache
FROM php:8.1-apache

# Install dependencies, including Postfix for SMTP
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    curl \
    unzip \
    git \
    postfix \
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

# Set the PORT environment variable
ENV PORT 8080

# Configure Apache to listen on port 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Configure Postfix for SMTPS (port 465)
RUN echo "relayhost = " >> /etc/postfix/main.cf \
    && echo "smtpd_tls_cert_file=/etc/ssl/certs/postfix_cert.pem" >> /etc/postfix/main.cf \
    && echo "smtpd_tls_key_file=/etc/ssl/private/postfix_key.pem" >> /etc/postfix/main.cf \
    && echo "smtpd_tls_security_level=encrypt" >> /etc/postfix/main.cf \
    && echo "smtpd_tls_wrappermode=yes" >> /etc/postfix/main.cf \
    && echo "inet_protocols = all" >> /etc/postfix/main.cf \
    && echo "smtpd_tls_loglevel = 1" >> /etc/postfix/main.cf

# Copy SSL certificates (self-signed or from a certificate authority)
# Make sure to replace `postfix_cert.pem` and `postfix_key.pem` with your actual certificate files.
COPY postfix_cert.pem /etc/ssl/certs/postfix_cert.pem
COPY postfix_key.pem /etc/ssl/private/postfix_key.pem
RUN chmod 600 /etc/ssl/certs/postfix_cert.pem /etc/ssl/private/postfix_key.pem

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s CMD curl -f http://localhost:8080/ || exit 1

# Start Postfix and Apache together
CMD service postfix start && apache2-foreground
