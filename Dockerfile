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

# Set the PORT environment variable
ENV PORT 8080

# Configure Apache to listen on port 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf

# Add a health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s CMD curl -f http://localhost:8080/ || exit 1

# Set up the Apache server to listen on port 8080
CMD ["apache2-foreground"]