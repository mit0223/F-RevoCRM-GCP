# F-RevoCRM Dockerfile
# This Dockerfile sets up an environment to run F-RevoCRM.

# Use an official PHP image with Apache
FROM php:8.1-apache

# Install system dependencies required by F-RevoCRM and PHP extensions
RUN apt-get update && apt-get install -y \
  git \
  unzip \
  libzip-dev \
  libpng-dev \
  libjpeg-dev \
  libfreetype-dev \
  libldap2-dev \
  libc-client-dev \
  libkrb5-dev \
  && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions required by F-RevoCRM
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install zip \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
  && docker-php-ext-install ldap \
  && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
  && docker-php-ext-install imap \
  && docker-php-ext-install pdo pdo_mysql mysqli opcache

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Download and install F-RevoCRM
RUN cd /tmp \
  && curl -L -o frevocrm.zip https://github.com/thinkingreed-inc/F-RevoCRM/archive/refs/tags/v7.4.1.zip \
  && unzip frevocrm.zip \
  && mv F-RevoCRM-7.4.1/* /var/www/html/ \
  && mv F-RevoCRM-7.4.1/.* /var/www/html/ 2>/dev/null || true \
  && rm -rf /tmp/*

# Install composer dependencies
WORKDIR /var/www/html
RUN composer install --no-dev --optimize-autoloader

# Set permissions for Apache
RUN chown -R www-data:www-data /var/www/html \
  && chmod -R 755 /var/www/html

# Enable Apache rewrite module for pretty URLs
RUN a2enmod rewrite

# Expose port 80 for Apache
EXPOSE 80

# The default command for the container is to start Apache
CMD ["apache2-foreground"]
