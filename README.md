# Bedrock in a container

This container includes:

- [Bedrock](https://roots.io/bedrock/)
- [Composer](https://getcomposer.org/)
- [WP CLI](https://wp-cli.org/)


## Usage

1. Create a `Dockerfile` with `FROM weahead/bedrock:<tag>`. Where `tag` is a
   version number like `1.6.3`.
2. Create a folder named `app` next to `Dockerfile`.
3. Optionally, create a file named `.env` at `app/.env`.
   See [example](app/.env.example) for example content.
   Detailed info can be found [in Bedrock documentation](https://roots.io/bedrock/docs/environment-variables/).
4. Place themes in folder `app/themes`.
5. Place plugins in folder `app/plugins`.

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

5. Build it with `docker build -t <name>:<tag> .`


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
