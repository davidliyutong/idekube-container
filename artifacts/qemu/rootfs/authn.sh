#!/bin/bash
#
# authn.sh — Configure nginx access-token authentication.
# Called by startup.sh before nginx starts.
#
# The template lives at /etc/nginx/conf.d/access_token.conf (baked into the
# image). This script either replaces the placeholder with the real token or
# overwrites the file with a permit-all map when no token is configured.
#

CONF=/etc/nginx/conf.d/access_token.conf

if [ -n "${IDEKUBE_ACCESS_TOKEN:-}" ]; then
    # Validate token: only allow safe characters
    if ! echo "$IDEKUBE_ACCESS_TOKEN" | grep -qE '^[A-Za-z0-9._:@%+-]+$'; then
        echo "ERROR: IDEKUBE_ACCESS_TOKEN contains invalid characters."
        echo "       Only alphanumeric characters, dots, underscores, hyphens, colons, @, %, and + are allowed."
        exit 1
    fi

    echo "Configuring nginx access token authentication"
    sed -i "s|__IDEKUBE_ACCESS_TOKEN_PLACEHOLDER__|${IDEKUBE_ACCESS_TOKEN}|g" "$CONF"
    echo "Access token authentication configured"
else
    echo "IDEKUBE_ACCESS_TOKEN is not set, allowing all requests"
    cat > "$CONF" <<'NGINX_EOF'
# No access token configured — permit all requests.
# The intermediate variables must still be defined because
# sites-enabled/default references them (cookie-set rewrite, etc.).

map $args $__idekube_token_from_arg {
    default "";
}

map $__idekube_token_from_arg $__idekube_token_arg_ok {
    default 0;
}

map $cookie_idekube_container_access_token $__idekube_token_cookie_ok {
    default 0;
}

map $http_x_idekube_container_access_token $__idekube_token_header_ok {
    default 0;
}

map $request_uri $idekube_access_permitted {
    default 1;
}
NGINX_EOF
fi
