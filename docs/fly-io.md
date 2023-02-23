# Deployment to Fly.io

First start off with following the [Fly.io deployment speedrun](https://fly.io/docs/speedrun/).

1. In order to create a new application run
```console
fly launch
```

and copy the configuration from existin `fly.toml` file.

2. Choose an appropriate app name and deployment region.
If your project doesn't require it, don't create any database.

3. 