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