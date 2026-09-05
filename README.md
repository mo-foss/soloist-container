# Spotify Soloist container

Run _Spotify Soloist_ in a rootles Podman[^1] container on a Linux host.

Minimal container image based on Alpine Linux. Supports audio output through both PipeWire as well as PulseAudio[^2].

[^1]: Or Docker, if that's your thing.
[^2]: Depends on your host system support. Soloist will fallback to PulseAudio if it can't connect to PipeWire.

## Disclaimer
This repository as well as its author are not associated with Spotify in any way. Soloist binaries are not being shipped within this repository. The officially released binaries will be download throughout the process of building the container image.

See the [official repository](https://github.com/spotify/soloist) for the documentation.

## Quickstart

### Building
Check out the repository and build the image:

```sh
git clone git@github.com:mo-foss/soloist-container.git
cd soloist-container
podman build -t soloist:latest .
```

### Running
First you have to get a [Soloist API key](https://developer.spotify.com/documentation/soloist/tutorials/getting-started).

Put this key in an environment variable, so the container can pick it up:
```sh
export SOLOIST_API_KEY="spak_..."
```

Use this if your system supports PipeWire:
```sh
podman run --rm --name soloist \
  --network host \
  --userns=keep-id \
  --env SOLOIST_API_KEY \
  --env PIPEWIRE_RUNTIME_DIR=/tmp/soloist-runtime \
  --mount "type=bind,src=$XDG_RUNTIME_DIR/pipewire-0,target=/tmp/soloist-runtime/pipewire-0,readonly" \
  --volume soloist-data:/data:Z,U \
  soloist:latest
```

And this version if you only have PulseAudio support:
```sh
podman run --rm --name soloist \
  --network host \
  --userns=keep-id \
  --env SOLOIST_API_KEY \
  --env PULSE_SERVER=unix:/tmp/soloist-runtime/pulse-native \
  --mount "type=bind,src=$XDG_RUNTIME_DIR/pulse/native,target=/tmp/soloist-runtime/pulse-native,readonly" \
  --volume soloist-data:/data:Z,U \
  soloist:latest
```

A few notes of explanation are in order.

**Host networking** is absolutely necessary for Soloist to work correctly. Otherwise you won't be able to see it as a playback target in your Spotify mobile/desktop/web app. You could probably get away with enabling host networking just for the authentication process and then disabling it for the playback.

**Userns** is being modified here to enable access to the system PipeWire/PulseAudio sockets. Without this option, Soloist won't be able to play anything at all and you would only get some cryptic error messages.

**API key** is a hard requirement. Soloist won't even start without it being provided.

The named `soloist-data` **volume** keeps the device identity and Spotify Connect session (e.g. the authentication state)[^3].

[^3]: Audio data cache will conversely land in ephemeral storage (unless configured otherwise).

## Running with Docker

The same `Containerfile` can be built with Docker:

```sh
docker build -t soloist:latest -f Containerfile .
```

Docker has no Podman `keep-id` user namespace or `:U` volume option.
The following command therefore runs the container as its default root user, which can write the named data volume:

```sh
docker run --rm \
  --name soloist \
  --network=host \
  --env SOLOIST_API_KEY \
  --env PIPEWIRE_RUNTIME_DIR=/tmp/soloist-runtime \
  --env PULSE_SERVER=unix:/tmp/soloist-runtime/pulse-native \
  --mount "type=bind,src=$XDG_RUNTIME_DIR/pipewire-0,target=/tmp/soloist-runtime/pipewire-0,readonly" \
  --mount "type=bind,src=$XDG_RUNTIME_DIR/pulse/native,target=/tmp/soloist-runtime/pulse-native,readonly" \
  --volume soloist-data:/data:Z \
  soloist:latest
```

This is a combined version prepared for a PipeWire host with PulseAudio fallback.

If SELinux denies access to an audio socket, add `--security-opt label=disable`.

> [!NOTE]
> This example targets Docker on Linux. Docker Desktop uses a VM, so the
host's Linux audio socket paths and host networking require additional Desktop
configuration and are not equivalent by default.

## Runtime options

This container image supports a set of options that modify Soloist behaviour. These are just passed verbatim to the application itself.

### `SOLOIST_API_KEY`
Your own developer's API key for running the Soloist application.
Required for startup. Spotify Connect authentication comes on top of that.

### `SOLOIST_DEVICE_NAME`
The Spotify Connect name of the Soloist instance. Defaults to `Soloist`
but you can always change it to differentiate your devices better.

### `SOLOIST_DATA_DIR`

Where Soloist will store its runtime state (but not audio cache).
By default set to `/data` which will be mounted as the `soloist-data` volume from your host.

This is the data you normally want to be persisted and not thrown out on every container restart.

### `SOLOIST_CACHE_DIR`

Destination for Soloist audio data cache. By default set to `/tmp/soloist-cache`, which is an ephemeral path.

If you intend to persist this data, either:
1. set `SOLOIST_CACHE_DIR=/cache` and pass `--volume soloist-cache:/cache:Z,U` to have a separate volume attached for the cache, or
2. set `SOLOIST_CACHE_DIR=/data/cache` and reuse the existing data volume.

### `SOLOIST_WS`

Soloist offers a WebSocket interface for interacting with the running process.

To expose Soloist's WebSocket API, set `SOLOIST_WS`.
Use a fixed host-network port, for example `SOLOIST_WS=127.0.0.1:1780`.

The WebSocket API is disabled unless this variable is set.

> [!NOTE]
> Avoid putting `0.0.0.0` there as the container runs with host networking, and you'll expose that WebSocket port on your external network interfaces as well.

You can then use e.g. `soloist ctl --ws 127.0.0.1:1780` to talk to the running Soloist process.

## Build arguments

### `SOLOIST_URL`

The URL to download the official Spotify Soloist binary from.

> [!NOTE]
> Currently hardcoded for x86_64 version. The image would require a lot more changes than just this URL for other architectures to work.


### `ALPINE_VERSION`

The base version of Alpine Linux to include in the image.
