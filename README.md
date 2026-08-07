# JumpServer Installer

JumpServer Installer is used to install and manage JumpServer.

## Requirements
  - Linux x86_64
  - Kernel greater than 4.0

## Installation

```bash
# Install, version is specified in static.env
$ ./jmsctl.sh install
```

## Management Commands

```
# Start
$ ./jmsctl.sh start

# Restart
$ ./jmsctl.sh restart

# Stop (does not include the database)
$ ./jmsctl.sh stop

# Stop everything
$ ./jmsctl.sh down

# Backup the database
$ ./jmsctl.sh backup_db

# View logs
$ ./jmsctl.sh tail

```

## KOTL (Enterprise Edition)

KOTL is an Enterprise Edition component and requires setting
`USE_XPACK=1` in `/opt/jumpserver/config/config.txt`. It is installed as a
host systemd service and is not added to Docker Compose; it is enabled by
default in the Enterprise Edition, and can be disabled with:

```bash
KOTL_ENABLED=0
```

The installer pulls the `${NAMESPACE:-jumpserver}/kotl:${VERSION}` artifact
image, extracts it from `/dist`, and runs KOTL's own `scripts/install.sh` or
`scripts/upgrade.sh`. The offline package also automatically includes this
image. The service is managed via `jmsctl.sh start/stop/restart/status`, and
logs can be viewed with `./jmsctl.sh tail kotl`. When enabled, it also
automatically configures `KOTL_ENABLED=1`, `JDMC_ENABLED=1`, and
`/opt/jumpserver/data/unshare/kotl.sock` for Core.

KOTL currently uses a fixed host path of `/data/jumpserver`, so `VOLUME_DIR`
must also remain `/data/jumpserver` when it is enabled.

## Configuration Files

Configuration files are placed in /opt/jumpserver/config

```
[root@localhost config]# tree .
.
├── config.txt       # main configuration file
├── mysql
│   └── my.cnf       # mysql configuration file
|── mariadb
|   └── mariadb.cnf  # mariadb configuration file
├── nginx            # nginx configuration files
│   ├── cert
│   │   ├── server.crt
│   │   └── server.key
│   ├── lb_http_server.conf
│   └── lb_ssh_server.conf
├── README.md
└── redis
    └── redis.conf  # redis configuration file

6 directories, 11 files
```

### About config.txt

The config.txt file is an environment variable configuration file that is
mounted into each container, so you don't need to set configuration
separately for koko, core, lion, etc.

See: [JumpServer configuration reference](https://docs.jumpserver.org/zh/master/admin-guide/env/)
