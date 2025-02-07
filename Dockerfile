FROM php:8.0-fpm

# Fix GPG issues and install base dependencies
RUN set -eux; \
    # Clear existing keys, lists, and caches
    rm -rf /var/lib/apt/lists/* \
           /etc/apt/sources.list.d/* \
           /etc/apt/trusted.gpg \
           /etc/apt/trusted.gpg.d/* \
           /var/cache/apt/archives/* \
           /var/cache/apt/archives/partial/*; \
    mkdir -p /var/cache/apt/archives/partial; \
    # Create fresh sources.list
    echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list; \
    echo "deb http://security.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list; \
    echo "deb http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list; \
    # Update and install prerequisites
    apt-get clean; \
    apt-get update --allow-insecure-repositories; \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
        ca-certificates \
        gnupg2; \
    # Add all required keys
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 112695A0E562B32A; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 54404762BBB6E853; \
    # Clean up
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    # Update again with new keys
    apt-get update

# Install build essentials first
RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf \
        pkg-config \
        build-essential \
        apt-utils \
    && rm -rf /var/lib/apt/lists/*

# Install GD dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd \
        --enable-gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
        --with-xpm \
    && docker-php-ext-install -j$(nproc) gd

# Install other PHP extension dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        zlib1g-dev \
        libzip-dev \
        libicu-dev \
        libpq-dev \
        libonig-dev \
        libxml2-dev \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install -j$(nproc) \
        zip \
        intl \
        pdo_mysql \
        pdo_pgsql \
        bcmath \
        opcache

# Install additional PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    ctype \
    dom \
    exif \
    fileinfo \
    iconv \
    mbstring \
    xml

# Install FreeTDS and PDO_DBLIB
RUN apt-get update && apt-get install -y --no-install-recommends \
    freetds-dev \
    freetds-bin \
    freetds-common \
    libsybdb5 \
    libct4 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/ \
    && docker-php-ext-configure pdo_dblib --with-libdir=lib/x86_64-linux-gnu \
    && docker-php-ext-install pdo_dblib

# Install ImageMagick
RUN apt-get update && apt-get install -y --no-install-recommends \
    imagemagick \
    libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# Install Redis
RUN pecl install redis \
    && docker-php-ext-enable redis

# Install APCu
RUN pecl install apcu \
    && docker-php-ext-enable apcu

# Install additional utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ghostscript \
    libgs-dev \
    jpegoptim \
    pngquant \
    xmlstarlet \
    libhiredis-dev \
    wget \
    git \
    nano \
    supervisor \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Install fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6 \
    xfonts-base \
    xfonts-75dpi \
    fonts-wqy-microhei \
    ttf-wqy-microhei \
    fonts-wqy-zenhei \
    ttf-wqy-zenhei \
    && rm -rf /var/lib/apt/lists/*

# Install phpiredis
RUN git clone https://github.com/nrk/phpiredis.git /tmp/phpiredis && \
    cd /tmp/phpiredis && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/phpiredis && \
    echo "extension=phpiredis.so" > /usr/local/etc/php/conf.d/phpiredis.ini

# Create required directories
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /etc/cron.d \
    /var/log/php-app \
    /var/log/php-fpm \
    /var/log/cron \
    && chown www-data:www-data \
        /var/log/php-app \
        /var/log/php-fpm \
        /var/log/cron

# Copy configurations
COPY config/supervisor/supervisord.conf /etc/supervisor/
COPY config/php/custom.ini /usr/local/etc/php/conf.d/

# Install wkhtmltopdf
RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && apt-get update \
    && apt-get install -y ./wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && rm wkhtmltox_0.12.6.1-2.bullseye_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer

# Define volume
VOLUME ["/etc/supervisor/conf.d"]

# Expose ports
EXPOSE 9000 8022

# Set default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]