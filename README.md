# Architecture Diagram

![Architecture Diagram](./doc/home_theatre.png)

# !! Work In Progress Below !!

----

# Services

TODO: Decide the order of the subheadings within each service

## <img src="./logos/radarr.png" width="50" height="50" alt="radarr_logo"/> Radarr

TODO: Purpose

### Docker Compose Extract

```
radarr:
image: linuxserver/radarr:nightly-version-5.5.1.8747
container_name: radarr
hostname: radarr
depends_on:
  - qbittorrent
deploy:
  resources:
    limits:
      cpus: "1"
      memory: "1024M"
environment:
  # Base config
  PGID: "${PGID:?Group ID missing}"
  PUID: "${PUID:?User ID missing}"
  TZ: "${TIMEZONE:?Timezone not set}"
healthcheck:
  interval: 5m
  retries: 3
  start_period: 2m
  test: "curl --silent --fail http://localhost:3000/ping | grep -q 'OK' || exit 1"
  timeout: 20s
networks:
  - home
ports:
  - "4000:3000"
restart: unless-stopped
volumes:
  # Volume mounts from host system
  - "${DOWNLOADS_DIRECTORY}:/downloads"
  - "${MOVIE_DIRECTORY}:/movies"
  # Persistent volumes
  - ./storage/radarr/:/config
```

### Additional Environment Variables

None.

### Required Services

### Is It Mandatory

No.

Radarr is a companion to Sonarr/Lidarr/Readarr, but it is used to finding movies. If you have no need of _ever_ wanting movies to be downloaded
automatically, this service can be removed.

It is possible to search for content through Prowlarr directly if a movie is wanted. However, they may potentially need to be manually renamed/moved
after the download is completed.

### Healthcheck

Radarr exposes a healthcheck endpoint, **/ping**. We configure the h

### Ports

The default Radarr port of **7878** has been changed in the Radarr UI to **3000**. We then publicly expose it as port **4000**. This is minor
obfuscation, and should not be considered actual security.

### Volumes

## <img src="./logos/homarr.png" width="70" height="49" alt="homarr_logo"/> Homarr

## <img src="./logos/sonarr.png" width="50" height="50" alt="sonarr_logo"/> Sonarr

## <img src="./logos/lidarr.png" width="50" height="50" alt="lidarr_logo"/> Lidarr

## <img src="./logos/readarr.png" width="50" height="50" alt="readarr_logo"/> Readarr

----

# Misc/Common Info

## Common Healthcheck

TODO: Discuss interval/retries/start_period/timeout default values

## Common Environment Variables

Most services may contain the following environment variables:

| Environment Variable Name | Purpose          | Example Value    |
|---------------------------|------------------|------------------|
| PGID                      | Process Group ID | 0 (for root)     |
| PUID                      | Process User ID  | 0 (for root)     |
| TZ (or TIMEZONE)          | Timezone         | Pacific/Auckland |

Since they are used throughout, we set these values in the `.env` file and pass them in through our docker-compose configuration.

### PGID/PUID

**PGID** and **PUID** are used to override the group and user ID of the running container process, for permissions and privileges. Some services use
the `user` element in [docker-compose](https://docs.docker.com/compose/compose-file/05-services/#user), but the same values should be used. For
example, for any given service, the docker-compose definition could be:

```
services:
  service_name:
    image: image_name:tag
  environment:
    PGID: ${PGID}
    PUID: ${PUID}
```

or

```
services:
  service_name:
    image: image_name:tag
  user: "${PUID}:${PGID}"
```

### TZ/TIMEZONE

**TZ** or **TIMEZONE** is used to tell the service the running host's timezone, as defined by
the [tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List).

----

# Environment Variables File (.env)

TODO: Describe either in detail here, or high-level but with better comments in the .env.template file

----

# Public Access

Access to the services is controlled by an instance of [Apache](https://httpd.apache.org/), being used as a reverse-proxy. This means all requests go
through the Apache web-server and are then forwarded on to the correct internal system. This means we do not need to expose the ports for each service
publicly, as Apache will be able to forward those requests itself.

## Macro Definition

The following macro is used as a template for most of the services:

```
<VirtualHost *:80>
    ServerAdmin <email_address>
    ServerName $server_name.<domain_name>.<domain_tld>
    ServerAlias $server_name.<domain_name>.*

    ProxyPass / $protocol://$url/
    ProxyPassReverse / $protocol://$url/

    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://$url/$1" [P,L]

    ProxyPreserveHost on
    ProxyRequests Off
    RemoteIPHeader X-Forwarded-For

    TimeOut 20
    ErrorDocument 502 <status_page_url>
    ErrorDocument 503 <status_page_url>
</VirtualHost>
```

Breaking down the macro, we can define each section/line:

### VirtualHost

```
<VirtualHost *:80>
...
</VirtualHost>
```

Definition

### Host Configuration

```
ServerAdmin <email_address>
```

Definition

```
ServerName $server_name.<domain_name>.<domain_tld>
```

Definition

```
ServerAlias $server_name.<domain_name>.*
```

Definition

### URL Proxying

```
ProxyPass / $protocol://$url/
```

Definition

```
ProxyPassReverse / $protocol://$url/
```

Definition

## Websocket Enabling

```
RewriteEngine on
```

Definition

```
RewriteCond %{HTTP:Upgrade} websocket [NC]
```

Definition

```
RewriteCond %{HTTP:Connection} upgrade [NC]
```

Definition

```
RewriteRule ^/?(.*) "ws://$url/$1" [P,L]
```

Definition

### Preserving Originating Host 

```
ProxyPreserveHost on
```

Definition

```
ProxyRequests Off
```

Definition

```
RemoteIPHeader X-Forwarded-For
```

Definition

### Timeouts And Errors

```
TimeOut 20
```

Definition

```
ErrorDocument 502 <status_page_url>
```

Definition

```
ErrorDocument 503 <status_page_url>
```

Definition


## Custom Configuration

In addition to the basic configuration, we have extra configuration for (TODO: discuss tandoor, homarr, redirects next)

----

# Authentication

Where possible, we use [Authentik](https://goauthentik.io/) to secure the services.

The following services are integrated with Authentik, and their configuration is below.

TODO:

- Radarr
- Sonarr
- Readarr
- Lidarr
- Prowlarr
- Bazarr
- Navidrome

Following have no auth of their own (both disabled explicitly), using Authentik as the only auth:
- Dozzle
- File Browser
- Uptime-Kuma

----

# Backups

TODO: Move all this info into the service-level documentation instead of making it common
TODO: Add description of how we use bind mounts rather than volumes (except for where required), and why

## Creating Backups

### Scheduled Backups

The following containers have backup systems which are configured to take weekly backups.
You can either retrieve the latest automated backup, or can export a fresh one.

For the following containers, a new backup can be generated by going to **System**> **Backup**> **Backup Now**.

- `bazarr`
- `lidarr`
- `prowlarr`
- `radarr`
- `readarr`
- `sonarr`

### Built-In Backups

The following containers have no scheduled backup, but there is an option in the UI to export one:

- `tandoor`

For the `tandoor` container, the backup can be generated by clicking on the toolbox icon in the toolbar, selecting **Export**, selecting the option
**All recipes**, then pressing the **Export** button.

### Manual Backups

The following containers have no built-in backup systems, and must have their content archived manually.

- `homebox`

For the `homebox` container, there is an import/export feature, but we need to manually back up any uploaded screenshots/PDFs/attachments. This can be
done using the commands:

```
docker exec -it homebox sh
root@homebox:/# tar -czf homebox.tar.gz /data/
```

These attachments will unfortunately have to be manually added to each item (as of v0.9.0). In addition, an export of all items must be done by going
to **Tools**> **Import/Export**> **Export Inventory**.

### No Backups

The following containers have no need for backups, or backups are not used:

- `doplarr`
- `flaresolverr`
- `navidrome`
- `qbittorrent`
- `unpackerr`

For `navidrome`, the music directory is read-only so on creating a new container, you simply need to re-create the admin user. Custom playlists are
lost, but I don't use them, so I don't really care. Might update this if I use more playlists in the future.

## Retrieving Backups

Once a backup has been created on the container, it should be copied to the host system. This can be done by copying the file from the container.
If you are unsure of where the file is saved, you can connect to the container and search the file system by using the command:

```
docker exec -it [CONTAINER_ID] bash
```

Once you know the filepath of the backup file, you can copy it to the host by executing this command from the host itself:

```
docker cp [CONTAINER_ID]:/path/to/backup/file.tar.gz ./host/path/to/backup/file.tar.gz
```

## Restoring Backups

TODO:

----

# Logos & Images

TODO: Describe the ./logos directory and where those icons are use. Re-organise the structure while you're at it

----

# Future Plans

New/replaced services
Further auth integrations
Better backup solutions

# Dozzle

In order for Dozzle to connect to another host, the docker socket needs to be exposed over TCP. For a RaspberryPi4, the following needs to be done:

- Create a file `/etc/systemd/system/docker.service.d/override.conf`
- Add the following content to the file:
  ```
  [Service]
  ExecStart=
  ExecStart=/usr/bin/dockerd -H fd:// -H tcp://<lan_ip_address_of_raspberry_pi>:2375 --containerd=/run/containerd/containerd.sock
  ```
- Reload the daemon `sudo systemctl daemon-reload`
- Restart the docker service `sudo systemctl edit docker.service`
- Confirm the port is in LISTEN state with the LAN IP address:
  ```
  sudo netstat -lntp | grep dockerd
  tcp        0      0 192.168.123.123:2375      0.0.0.0:*               LISTEN      1234/dockerd
  ```
