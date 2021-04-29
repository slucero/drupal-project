FROM forumone/drupal8:7.4-xdebug AS dev

RUN f1-ext-install pecl:memcached

FROM forumone/drupal8:7.4 AS base

RUN f1-ext-install pecl:memcached

FROM composer:2 AS composer

COPY ["scripts", "scripts"]

RUN mkdir -p web

COPY ["composer.json", "composer.lock", "./"]

RUN set -ex \
  && composer install --no-dev --optimize-autoloader \
  && composer drupal:scaffold

# Install additional dev dependencies for the test image.

FROM composer AS composer-dev

RUN set -ex \
  && composer install --optimize-autoloader

FROM forumone/gesso:php7.3-node12 AS gesso

# Install npm dependencies

COPY ["web/themes/gesso/package*.json", "./"]

RUN if test -e package-lock.json; then npm ci; else npm i; fi

# Copy sources and build

COPY ["web/themes/gesso", "./"]

RUN set -ex \
  && gulp build

# Use a temporary image to clean dev dependencies for production. This allows

# the gesso-dev stage to start with these files in place rather than rebuilding.

FROM gesso AS gesso-clean

RUN set -ex \
  && rm -rf node_modules

# Install all dev dependencies for the test image.

FROM gesso AS gesso-dev

RUN set -ex \
  && npm install

FROM base AS release

# Copy all artifacts into the production-ready release stage for the final image.

COPY --from=composer ["/app/scripts", "scripts"]

COPY --from=composer ["/app/vendor", "vendor"]

COPY --from=composer ["/app/web", "web"]

COPY --from=gesso-clean ["/app", "web/themes/gesso"]

COPY ["web", "web"]

COPY ["config", "config"]

COPY ["drush", "drush"]

COPY ["load.environment.php", "./"]

FROM release AS test

# Copy all dev dependencies into a stage for a testing image.

COPY --from=composer-dev ["/app/scripts", "scripts"]

COPY --from=composer-dev ["/app/vendor", "vendor"]

COPY --from=composer-dev ["/app/web", "web"]

COPY --from=gesso-dev ["/app", "web/themes/gesso"]

# Ensure the default image to be built is the release image so any builds

# not explicitly defining a target receive the production release image

FROM release