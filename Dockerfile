# Stage 1 — Build Stage (Node + Composer)
FROM php:8.3-cli AS builder

RUN apt-get update && apt-get install -y \
    git curl zip unzip nodejs npm \
    libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction
RUN npm install && npm run build

# Stage 2 — Production Stage (Apache + PHP)
FROM php:8.3-apache

RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mysqli zip gd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copy ONLY the necessary files from builder
COPY --from=builder /app/index.php .
COPY --from=builder /app/application ./application
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/vendor ./vendor
COPY --from=builder /app/.htaccess .

RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

RUN a2enmod rewrite

RUN echo '<Directory /var/www/html>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' > /etc/apache2/conf-available/easyappointments.conf \
    && a2enconf easyappointments

EXPOSE 80