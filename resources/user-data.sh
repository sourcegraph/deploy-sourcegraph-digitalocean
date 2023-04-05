#!/usr/bin/env bash

export SOURCEGRAPH_VERSION=5.0.1
export USER_HOME=/root
export SOURCEGRAPH_CONFIG=/etc/sourcegraph
export SOURCEGRAPH_DATA=/var/opt/sourcegraph
export PATH=$PATH:/usr/local/bin
export DEBIAN_FRONTEND=noninteractive
export CAROOT=${SOURCEGRAPH_CONFIG}
export MKCERT_VERSION=1.4.1 # https://github.com/FiloSottile/mkcert/releases
export IP_ADDRESS=$(echo $(hostname -I) | awk '{print $1;}')

apt update
apt-get -y upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Required utils
apt install -y \
    git \
    nano \
    zip

# Reset firewall to only allow 22, 80, 443, and 2633
echo "y" | ufw reset
ufw default allow outgoing
ufw default deny incoming
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 2633/tcp
ufw allow 2633/tcp
ufw disable  && echo "y" | ufw enable

# Create the required Sourcegraph directories
mkdir -p ${SOURCEGRAPH_CONFIG}/management
mkdir -p ${SOURCEGRAPH_DATA}

# Install mkcert and generate root CA, certificate and key 
wget https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VERSION}/mkcert-v${MKCERT_VERSION}-linux-amd64 -O /usr/local/bin/mkcert
chmod a+x /usr/local/bin/mkcert

# Use the public ip address of the instance as hostnae for the self-signed cert as DigitalOcean doesn't have public DNS hostnames
mkcert -install
mkcert -cert-file ${SOURCEGRAPH_CONFIG}/sourcegraph.crt -key-file ${SOURCEGRAPH_CONFIG}/sourcegraph.key ${IP_ADDRESS}

#
# Configure the nginx.conf file for SSL.
#
cat > ${SOURCEGRAPH_CONFIG}/nginx.conf <<EOL
# From https://github.com/sourcegraph/sourcegraph/blob/main/cmd/server/shared/assets/nginx.conf
# You can adjust the configuration to add additional TLS or HTTP features.
# Read more at https://docs.sourcegraph.com/admin/nginx

error_log stderr;
pid /var/run/nginx.pid;

# Do not remove. The contents of sourcegraph_main.conf can change between
# versions and may include improvements to the configuration.
include nginx/sourcegraph_main.conf;

events {
}

http {
    server_tokens off;

    # SAML redirect response headers are sometimes large
    proxy_buffer_size           128k;
    proxy_buffers               8 256k;
    proxy_busy_buffers_size     256k;  

    # Do not remove. The contents of sourcegraph_http.conf can change between
    # versions and may include improvements to the configuration.
    include nginx/sourcegraph_http.conf;

    access_log off;
    upstream backend {
        # Do not remove. The contents of sourcegraph_backend.conf can change
        # between versions and may include improvements to the configuration.
        include nginx/sourcegraph_backend.conf;
    }

    # Redirect all HTTP traffic to HTTPS
    server {
        listen 7080 default_server;
        return 301 https://\$host\$request_uri;
    }

    server {
        # Do not remove. The contents of sourcegraph_server.conf can change
        # between versions and may include improvements to the configuration.
        include nginx/sourcegraph_server.conf;

        listen 7443 ssl http2 default_server;        
        ssl_certificate         sourcegraph.crt;
        ssl_certificate_key     sourcegraph.key;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # SAML redirect response headers are sometimes large
        proxy_buffer_size           128k;
        proxy_buffers               8 256k;
        proxy_busy_buffers_size     256k;        

        location '/.well-known/acme-challenge' {
            default_type "text/plain";
            root /var/www/html;
        }
    }
}
EOL


# Use the same certificate for the management console
cp ${SOURCEGRAPH_CONFIG}/sourcegraph.crt ${SOURCEGRAPH_CONFIG}/management/cert.pem
cp ${SOURCEGRAPH_CONFIG}/sourcegraph.key ${SOURCEGRAPH_CONFIG}/management/key.pem

# Zip the CA Root key and certificate for easy downloading
zip -j ${USER_HOME}/sourcegraph-root-ca.zip ${SOURCEGRAPH_CONFIG}/sourcegraph.crt ${SOURCEGRAPH_CONFIG}/sourcegraph.key

cat > ${USER_HOME}/sourcegraph-start <<EOL
#!/usr/bin/env bash

SOURCEGRAPH_VERSION=${SOURCEGRAPH_VERSION}

# Disable exit on non 0 as these may fail, which is ok 
# because failure will only occur if the network exists
# or if the sourcegraph container doesn't exist.
set +e
docker network create sourcegraph > /dev/null 2>&1
docker container rm -f sourcegraph > /dev/null 2>&1

# Enable exit on non 0
set -e

echo "[info]: Starting Sourcegraph \${SOURCEGRAPH_VERSION}"

docker container run \\
    --name sourcegraph \\
    -d \\
    --restart always \\
    \\
    --network sourcegraph \\
    --hostname sourcegraph \\
    --network-alias sourcegraph \\
    \\
    -p 80:7080 \\
    -p 443:7443 \\
    -p 2633:2633 \\
    -p 127.0.0.1:3370:3370 \\
    \\
    -v ${SOURCEGRAPH_CONFIG}:${SOURCEGRAPH_CONFIG} \\
    -v ${SOURCEGRAPH_DATA}:${SOURCEGRAPH_DATA} \\
    \\
    sourcegraph/server:\${SOURCEGRAPH_VERSION}
EOL

cat > ${USER_HOME}/sourcegraph-stop <<EOL
#!/usr/bin/env bash

echo "[info]:  Stopping Sourcegraph"
docker container stop sourcegraph > /dev/null 2>&1 docker container rm sourcegraph
EOL

cat > ${USER_HOME}/sourcegraph-upgrade <<EOL
#!/usr/bin/env bash

./sourcegraph-stop

read -p "Sourcegraph version to upgrade to: " VERSION
sed -i -E "s/SOURCEGRAPH_VERSION=[0-9\.]+/SOURCEGRAPH_VERSION=\$VERSION/g" ./sourcegraph-start

./sourcegraph-start
EOL

cat > ${USER_HOME}/sourcegraph-restart <<EOL
#!/usr/bin/env bash

./sourcegraph-stop
./sourcegraph-start
EOL

chmod +x ${USER_HOME}/sourcegraph-*
${USER_HOME}/sourcegraph-start

# Truncate the `global_state` db table so a unique site_id will be generated upon launch
docker container exec -it sourcegraph psql -U postgres sourcegraph --command "DELETE FROM global_state WHERE 1=1;"

apt -y autoremove
apt -y autoclean

cat > /etc/update-motd.d/99-one-click <<EOL
#!/bin/sh
#
# Configured as part of the DigitalOcean 1-Click Image build process

IP_ADDRESS=$(echo $(hostname -I) | awk '{print $1;}')
cat <<EOF

********************************************************************************

Welcome to the Sourcegraph 1-Click App Droplet.

For help and more information, visit https://docs.sourcegraph.com/

## Accessing Sourcegraph

Sourcegraph is running as the sourcegraph/server Docker container with two different access points:
 - Sourcegraph web app: https://${IP_ADDRESS}
 - Sourcegraph management console: https://${IP_ADDRESS}:2633

## Controlling Sourcegraph

There are four scripts in the /root directory for controlling Sourcegraph:
 - sourcegraph-start
 - sourcegraph-stop
 - sourcegraph-restart
 - sourcegraph-upgrade

## Server resources

 - Sourcegraph configuration files are in /etc/sourcegraph
 - Sourcegraph data files are in /var/opt/sourcegraph

## PostgreSQL access

Access the PostgreSQL db inside the Docker container by running: docker container exec -it sourcegraph psql -U postgres sourcegraph

## Security

To keep this Droplet secure, UFW is blocking all in-bound ports except 20, 80, 443, and 2633 (Critical config management console).

To delete this message of the day: rm -rf $(readlink -f ${0})

********************************************************************************
EOF
EOL
