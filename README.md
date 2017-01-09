# Bedrock in a container

This container includes:

- [S6 Overlay](https://github.com/just-containers/s6-overlay)
- [Bedrock](https://roots.io/bedrock/)
- [Composer](https://getcomposer.org/)
- [WP CLI](https://wp-cli.org/)
- [Node.js](https://nodejs.org/)


## Usage

See [example](example)

1. Create a `Dockerfile` with `FROM weahead/bedrock:<tag>`. Where `tag` is a
   version number like `1.7.3`.

2. Make sure you add `VOLUME /var/www/html` to the end of your `Dockerfile`.

3. Create a folder named `app` next to `Dockerfile`.

4. Optionally, either declare environment variables in docker-compose.yml files
   (recommended) or create a file named `.env` at `app/.env`.

   Detailed info on environment variables and their values can be found
   [in Bedrock documentation](https://roots.io/bedrock/docs/environment-variables/).

5. Place themes in folder `app/themes`.

6. Place plugins in folder `app/plugins`.

   This gives you a folder structure like this:

   ```
   .
   ├── Dockerfile
   ├── app
   │   ├── .env
   │   ├── plugins
   │   │   ├── plugin1
   │   │   ├── plugin2
   │   │   └── ...
   │   └── themes
   │       ├── my-theme
   │       └── ...
   └── ...
   ```

7. Build it with `docker build -t <name>:<tag> .`


## Node.js service

This image has optional support for running a single Node.js service. If there
is a `package.json` inside a theme folder, the image will run `npm install` in
that folder during the build of a derivative image. Upon startup of a container
from the built derivative image S6 will start a Node.js service that will run a
command depending on the value of the environment variable `NODE_ENV`:

| Value | Command |
|-------|---------|
| development | `npm run dev` |
| production  | `npm run start` |

This is useful for using Node.js based build systems like broccoli, grunt,
gulp, etc. when developing the theme.


### S6 supervision

To use additional services S6 supervision can be used. More information on how
to use S6 can be found in [their documentation](https://github.com/just-containers/s6-overlay).

The recommended way is to use `COPY root /` in a descendant `Dockerfile` with 
the directory structure found in [example/root](example/root).


### Notes for usage in production

It is probably a good idea to provide a new configuration file for `opcache` at
`/usr/local/etc/php/conf.d/opcache.ini`. The configuration file included in
this image is for development settings. A new configuration file can be provided
by adding it in the `Dockerfile` that `FROM`s this image, or via another
container that exposes configuration via Docker volumes.

Dockerfile example:
```
FROM weahead/bedrock:<tag>

COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini
```

Configuration container example with Docker compose:
```
bedrock:
  image: weahead/bedrock:<tag>
  volumes_from:
    - bedrock-conf
  ...

bedrock-conf:
  build: ./bedrock-conf
  ..
```

`./bedrock-conf/Dockerfile`:
```
# image that weahead/bedrock:<tag> uses as FROM
FROM php:5.6.21-fpm-alpine

COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

VOLUME /usr/local/etc/php/conf.d
```


## License

[X11](LICENSE)
