#/bin/bash

###
# Variables
###

echo ">> remove startup-roundcube.sh script"
sed -i "s/\/opt\/startup-roundcube.sh/# removed /g" /opt/entrypoint.sh

###
# Pre Install
###

if [ ! -z ${ROUNDCUBE_HSTS_HEADERS_ENABLE+x} ]
then
  echo ">> HSTS Headers enabled"
  sed -i 's/#add_header Strict-Transport-Security/add_header Strict-Transport-Security/g' /etc/nginx/conf.d/nginx-roundcube.conf

  if [ ! -z ${ROUNDCUBE_HSTS_HEADERS_ENABLE_NO_SUBDOMAINS+x} ]
  then
    echo ">> HSTS Headers configured without includeSubdomains"
    sed -i 's/; includeSubdomains//g' /etc/nginx/conf.d/nginx-roundcube.conf
  fi
else
  echo ">> HSTS Headers disabled"
fi

###
# Install
###

echo ">> making roundcube available beneath: $ROUNDCUBE_RELATIVE_URL_ROOT"
mkdir -p "/usr/share/nginx/html$ROUNDCUBE_RELATIVE_URL_ROOT" 
# adding softlink for nginx connection
echo ">> adding softlink from /roundcube to $ROUNDCUBE_RELATIVE_URL_ROOT"
mkdir -p "/usr/share/nginx/html$ROUNDCUBE_RELATIVE_URL_ROOT"
rm -rf "/usr/share/nginx/html$ROUNDCUBE_RELATIVE_URL_ROOT"
ln -s /roundcube $(echo "/usr/share/nginx/html$ROUNDCUBE_RELATIVE_URL_ROOT" | sed 's/\/$//')

###
# Post Install
###

if [ ! -z ${ROUNDCUBE_DO_NOT_INITIALIZE+x} ]
then
  echo ">> ROUNDCUBE_DO_NOT_INITIALIZE set - skipping initialization"
  exit 0
fi

# skip if DB exists and not empty!!!
if [ $(psql -h $POSTGRES_PORT_5432_TCP_ADDR -p $POSTGRES_PORT_5432_TCP_PORT -U $POSTGRES_USER -c "\d" | wc -l) -gt 4 ]
then
  echo ">> DB is already configured - skipping initialization"
  exit 0
fi

###
# Headless initialization
###
echo ">> initialization"
echo ">> starting nginx to configure roundcube"
sleep 1
nginx > /dev/null 2> /dev/null &
sleep 1

## Create Roundcube Installation
echo ">> init roundcube installation"
echo ">> init database"

# enable installer
sed -i 's/\?>/\$config["enable_installer"] = true;\n\?>/g' /roundcube/config/config.inc.php
sleep 1

wget -O /dev/null --no-check-certificate --no-proxy --post-data 'initdb=Initialize+database' https://localhost$ROUNDCUBE_RELATIVE_URL_ROOT\installer/index.php?_step=3

# disable installer
echo ">> removing installer folder"
sed -i 's/\$config\["enable_installer"\] = true;/\$config\["enable_installer"\] = false;/g' /roundcube/config/config.inc.php
rm -rf /roundcube/installer
chown www-data:www-data -R /roundcube

echo ">> killing nginx - done with configuration"
sleep 1
killall nginx


echo ">> finished initialization"
