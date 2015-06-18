#/bin/bash

###
# Variables
###

if [ -z ${POSTGRES_USER+x} ] || [ -z ${PGPASSWORD+x} ]
then
  >&2 echo ">> no user or password for database specified!"
  exit 1
fi

if [ -z ${ROUNDCUBE_IMAP_HOST+x} ]
then
  ROUNDCUBE_IMAP_HOST=mail
fi

if [ -z ${ROUNDCUBE_IMAP_PROTO+x} ]
then
  ROUNDCUBE_IMAP_PROTO=tls
fi

if [ -z ${ROUNDCUBE_SMTP_HOST+x} ]
then
  ROUNDCUBE_SMTP_HOST=mail
fi

if [ -z ${ROUNDCUBE_SMTP_PROTO+x} ]
then
  ROUNDCUBE_SMTP_PROTO=tls
fi

if [ -z ${ROUNDCUBE_SMTP_PORT+x} ]
then
  ROUNDCUBE_SMTP_PORT=25
fi

if [ -z ${ROUNDCUBE_LANGUAGE+x} ]
then
  ROUNDCUBE_LANGUAGE=en_CA
fi


if [ -z ${POSTGRES_PORT_5432_TCP_PORT+x} ]
then
  POSTGRES_PORT_5432_TCP_PORT=5432
fi

if [ -z ${PG_DBNAME+x} ]
then
  PG_DBNAME=roundcube
fi

if [ -z ${ROUNDCUBE_PHP_DATE_TIMEZONE+x} ]
then
  ROUNDCUBE_PHP_DATE_TIMEZONE=America/Montreal
fi

if [ -z ${ROUNDCUBE_RELATIVE_URL_ROOT+x} ]
then
  ROUNDCUBE_RELATIVE_URL_ROOT="/"
fi

ROUNDCUBE_RANDOM=`perl -e 'my @chars = ("A".."Z", "a".."z"); my $string; $string .= $chars[rand @chars] for 1..24; print $string;'` # returns exactly 24 random chars

###
# Configuration
###

sed -i "s/PG_USER/$POSTGRES_USER/g" /roundcube/config/config.inc.php
sed -i "s/PG_PASSWORD/$PGPASSWORD/g" /roundcube/config/config.inc.php
sed -i "s/PG_DB/$PG_DBNAME/g" /roundcube/config/config.inc.php
sed -i "s/PG_TCP_ADDR/$POSTGRES_PORT_5432_TCP_ADDR/g" /roundcube/config/config.inc.php
sed -i "s/PG_PORT/$POSTGRES_PORT_5432_TCP_PORT/g" /roundcube/config/config.inc.php
sed -i "s/IMAP_HOST/$ROUNDCUBE_IMAP_HOST/g" /roundcube/config/config.inc.php
sed -i "s/IMAP_PROTOCOL/$ROUNDCUBE_IMAP_PROTO/g" /roundcube/config/config.inc.php
sed -i "s/SMTP_HOST/$ROUNDCUBE_SMTP_HOST/g" /roundcube/config/config.inc.php
sed -i "s/SMTP_PROTOCOL/$ROUNDCUBE_SMTP_PROTO/g" /roundcube/config/config.inc.php
sed -i "s/SMTP_PORT/$ROUNDCUBE_SMTP_PORT/g" /roundcube/config/config.inc.php
sed -i "s/LOCALISATION/$ROUNDCUBE_LANGUAGE/g" /roundcube/config/config.inc.php
sed -i "s/ROUNDCUBE_RANDOM/$ROUNDCUBE_RANDOM/g" /roundcube/config/config.inc.php

echo ">> set Timezone -> $ROUNDCUBE_PHP_DATE_TIMEZONE"
sed -i "s!;date.timezone =.*!date.timezone = $ROUNDCUBE_PHP_DATE_TIMEZONE!g" /etc/php5/fpm/php.ini

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
