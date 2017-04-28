FROM php:5.6.30-fpm-alpine

MAINTAINER We ahead <docker@weahead.se>

RUN apk --no-cache add \
      nano \
      findutils \
      tar \
      coreutils \
      freetype-dev \
      libjpeg-turbo-dev \
      libmcrypt-dev \
      libpng-dev \
      imagemagick-dev \
      libtool \
      su-exec \
      nodejs \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) iconv mcrypt mysqli opcache \
    && apk --no-cache add --virtual .phpize-deps $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-png-dir=/usr/include --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) gd \
    && apk --no-cache add --virtual .phpize-deps $PHPIZE_DEPS \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && apk --no-cache del .phpize-deps

RUN echo "@3.6 http://dl-cdn.alpinelinux.org/alpine/v3.6/main" >> /etc/apk/repositories \
    && apk --no-cache add \
      jq@3.6

RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.validate_timestamps=on'; \
  } > /usr/local/etc/php/conf.d/opcache.ini

ENV NODE_ENV=production\
    S6_VERSION=1.21.1.1\
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN apk --no-cache add --virtual build-deps \
      gnupg \
  && cd /tmp \
  && curl -OL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz" \
  && curl -OL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz.sig" \
  && export GNUPGHOME="$(mktemp -d)" \
  && curl https://keybase.io/justcontainers/key.asc | gpg --import \
  && gpg --verify /tmp/s6-overlay-amd64.tar.gz.sig /tmp/s6-overlay-amd64.tar.gz \
  && tar -xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && rm -rf "$GNUPGHOME" /tmp/* \
  && apk --no-cache del build-deps

ENV WP_CLI_VERSION=1.4.0\
    PAGER=cat

RUN apk --no-cache add \
          ncurses \
    && curl -L -o /usr/local/bin/wp https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar \
    && curl -L -o wp-cli.sha512 "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar.sha512" \
    && echo "$(cat wp-cli.sha512) */usr/local/bin/wp" | sha512sum -c - \
    && rm -rf wp-cli.sha512 \
    && chmod +x /usr/local/bin/wp

ENV COMPOSER_VERSION=1.5.2\
    COMPOSER_CACHE_DIR=/tmp/composer-cache

RUN mkdir -p /tmp/composer-cache \
    && chown www-data:www-data /tmp/composer-cache \
    && chmod 777 /tmp/composer-cache \
    && curl -L -o composer-setup.php https://getcomposer.org/installer \
    && curl -L -o composer-setup.sig https://composer.github.io/installer.sig \
    && echo "$(cat composer-setup.sig) *composer-setup.php" | sha384sum -c - \
    && php composer-setup.php -- \
      --install-dir=/usr/local/bin\
      --filename=composer\
      --version=${COMPOSER_VERSION}\
    && rm -rf composer-setup.php composer-setup.sig \
    && su-exec www-data composer global require "hirak/prestissimo:^0.3"

ENV BEDROCK_VERSION=1.4.5

RUN curl -L -o bedrock.tar.gz https://github.com/roots/bedrock/archive/${BEDROCK_VERSION}.tar.gz \
    && tar -zxf bedrock.tar.gz --strip-components=1 \
    && rm -rf bedrock.tar.gz \
    && chown -R www-data:www-data /var/www/html \
    && echo http://dl-cdn.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories \
    && echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
    && echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories \
    && apk --no-cache add --virtual build-deps \
      moreutils \
    && jq --indent 4 '.extra["merge-plugin"] = {"include":["composer-app.json"],"recurse":false}' composer.json | su-exec www-data sponge composer.json \
    && apk --no-cache del build-deps \
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
    && su-exec www-data composer install --prefer-dist \
    && PKGDIR=$(find /var/www/html/web/app/themes -mindepth 2 -maxdepth 2 -name "package.json" -type f -printf "%h" -quit) \
    && [ -n "${PKGDIR}" ] \
    && cd -- "${PKGDIR}" \
    && echo "Installing npm dependencies in ${PKGDIR}" \
    && su-exec www-data npm set progress=false \
    && su-exec www-data npm install --dev -s \
    && echo "Cleaning npm cache in ${PKGDIR}" \
    && su-exec www-data npm cache clean \
    && echo "Executing build in ${PKGDIR}" \
    && su-exec www-data npm run build \
    || true
