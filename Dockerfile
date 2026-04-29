# Stage 1 — Build Stage (Node + Composer)
FROM php:8.3-cli AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    nodejs \
    npm \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy all source files
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Install Node dependencies and build assets
RUN npm install && npm run build

# Stage 2 — Production Stage (Apache + PHP)
FROM php:8.3-apache

# Install PHP extensions needed by EasyAppointments
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libzip-dev \
    && docker-php-ext-install pdo pdo_mysql mysqli zip gd

# Set working directory
WORKDIR /var/www/html

# Copy built app from Stage 1
COPY --from=builder /app .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Enable Apache mod_rewrite (needed by EasyAppointments)
RUN a2enmod rewrite

# Copy Apache config
RUN echo '<Directory /var/www/html>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' > /etc/apache2/conf-available/easyappointments.conf \
    && a2enconf easyappointments

EXPOSE 80