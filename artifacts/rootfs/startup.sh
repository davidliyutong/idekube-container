#!/bin/bash

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf