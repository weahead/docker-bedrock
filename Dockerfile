FROM php:5.6.22-fpm-alpine

MAINTAINER We ahead <docker@weahead.se>

RUN apk --no-cache add \
      tar \
      coreutils \
      freetype-dev \
      libjpeg-turbo-dev \
      libmcrypt-dev \
      libpng-dev \
      imagemagick-dev \
      libtool \
      su-exec \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) iconv mcrypt mysqli opcache \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-png-dir=/usr/include --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) gd \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && apk del .phpize-deps

RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.validate_timestamps=on'; \
  } > /usr/local/etc/php/conf.d/opcache.ini

ENV BEDROCK_VERSION=1.6.3\
    COMPOSER_VERSION=1.1.1\
    WP_CLI_VERSION=0.23.1\
    WP_CLI_SHA512=efad9ce6a268dc20f4d8db1a1b367c64e6c032383b32bca3bad8d922b7fd19f0cfa16fcf91a73954b680b959905f746549ec56fceb8503c195b1f37dd682dd60

RUN curl -L -o /usr/local/bin/wp https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar \
    && echo "${WP_CLI_SHA512} */usr/local/bin/wp" | sha512sum -c - \
    && chmod +x /usr/local/bin/wp \
    && curl -L -o composer-setup.php https://getcomposer.org/installer \
    && curl -L -o composer-setup.sig https://composer.github.io/installer.sig \
    && echo "$(cat composer-setup.sig) *composer-setup.php" | sha384sum -c - \
    && php composer-setup.php -- \
      --install-dir=/usr/local/bin\
      --filename=composer\
      --version=${COMPOSER_VERSION}\
    && rm -rf composer-setup.php composer-setup.sig \
    && curl -L -o bedrock.tar.gz https://github.com/roots/bedrock/archive/${BEDROCK_VERSION}.tar.gz \
    && tar -zxf bedrock.tar.gz --strip-components=1 \
    && rm -rf bedrock.tar.gz \
    && chown -R www-data:www-data /var/www/html \
    && su-exec www-data composer install

ONBUILD COPY app/ /var/www/html/web/app/

ONBUILD RUN mv /var/www/html/web/app/.env /var/www/html/.env 2> /dev/null || true

ONBUILD RUN chown -R www-data:www-data /var/www/html

ONBUILD VOLUME /var/www/html
