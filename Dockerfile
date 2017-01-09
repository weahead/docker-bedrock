FROM php:5.6.23-fpm-alpine

MAINTAINER We ahead <docker@weahead.se>

RUN apk --no-cache add \
      nano \
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
    && apk --no-cache add --virtual .phpize-deps $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-png-dir=/usr/include --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) gd \
    && apk --no-cache add --virtual .phpize-deps $PHPIZE_DEPS \
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

ENV S6_VERSION=1.18.1.3\
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN apk --no-cache add --virtual build-deps \
      gnupg \
  && cd /tmp \
  && curl -OL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz" \
  && curl -OL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz.sig" \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --keyserver pgp.mit.edu --recv-key 0x337EE704693C17EF \
  && gpg --batch --verify /tmp/s6-overlay-amd64.tar.gz.sig /tmp/s6-overlay-amd64.tar.gz \
  && tar -xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && rm -rf "$GNUPGHOME" /tmp/* \
  && apk del build-deps

ENV WP_CLI_VERSION=0.25.0

RUN curl -L -o /usr/local/bin/wp https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar \
    && curl -L -o wp-cli.sha512 "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar.sha512" \
    && echo "$(cat wp-cli.sha512) */usr/local/bin/wp" | sha512sum -c - \
    && rm -rf wp-cli.sha512 \
    && chmod +x /usr/local/bin/wp

ENV COMPOSER_VERSION=1.2.2

RUN curl -L -o composer-setup.php https://getcomposer.org/installer \
    && curl -L -o composer-setup.sig https://composer.github.io/installer.sig \
    && echo "$(cat composer-setup.sig) *composer-setup.php" | sha384sum -c - \
    && php composer-setup.php -- \
      --install-dir=/usr/local/bin\
      --filename=composer\
      --version=${COMPOSER_VERSION}\
    && rm -rf composer-setup.php composer-setup.sig \
    && su-exec www-data composer global require "hirak/prestissimo:^0.3"

ENV BEDROCK_VERSION=1.6.3

RUN curl -L -o bedrock.tar.gz https://github.com/roots/bedrock/archive/${BEDROCK_VERSION}.tar.gz \
    && tar -zxf bedrock.tar.gz --strip-components=1 \
    && rm -rf bedrock.tar.gz \
    && chown -R www-data:www-data /var/www/html \
    && echo http://dl-2.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
    && echo http://dl-2.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
    && apk --no-cache add --virtual build-deps \
      jq \
      moreutils \
    && jq --indent 4 '.extra["merge-plugin"] = {"include":["composer-app.json"],"recurse":false}' composer.json | su-exec www-data sponge composer.json \
    && apk del build-deps \
    && su-exec www-data composer require wikimedia/composer-merge-plugin \
    && su-exec www-data composer install

COPY root /

RUN chown -R www-data:www-data /var/www/html

ENTRYPOINT ["/init"]

ONBUILD COPY app/ /var/www/html/web/app/

ONBUILD RUN mv /var/www/html/web/app/.env /var/www/html/.env 2> /dev/null || true \
    && mv /var/www/html/web/app/composer.json /var/www/html/composer-app.json 2> /dev/null || true \
    && chown -R www-data:www-data /var/www/html \
    && rm composer.lock \
    && su-exec www-data composer install --prefer-dist
