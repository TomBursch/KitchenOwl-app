#!/bin/sh
set -e

# if ipv6 is unavailable, remove it from the wsgi config
ME=$(basename $0)
if [ ! -f "/proc/net/if_inet6" ]; then
    echo "$ME: info: ipv6 not available"
    sed -i 's/\[::\]//g' /usr/src/kitchenowl/wsgi.ini
fi

mkdir -p $STORAGE_PATH/upload
flask db upgrade
if [ "${SKIP_UPGRADE_DEFAULT_ITEMS}" != "true" ] && [ "${SKIP_UPGRADE_DEFAULT_ITEMS}" != "True" ]; then
    python upgrade_default_items.py
fi
uwsgi "$@"
