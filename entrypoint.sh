#!/bin/bash

/etc/init.d/php5-fpm start
chmod a+rwx /var/run/php5-fpm.sock

cat <<EOF
Derived from marvambass/nginx-ssl-secure and marvambass/roundcube containers

IMPORTANT:
  IF you use SSL inside your personal NGINX-config,
  you should add the Strict-Transport-Security header like:

    # only this domain
    add_header Strict-Transport-Security "max-age=31536000";
    # apply also on subdomains
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

  to your config.
  After this you should gain a A+ Grade on the Qualys SSL Test

EOF

if [ -z ${DH_SIZE+x} ]
then
  >&2 echo ">> no \$DH_SIZE specified using default" 
  DH_SIZE="2048"
fi


DH="/etc/nginx/external/dh.pem"

if [ ! -e "$DH" ]
then
  echo ">> seems like the first start of nginx"
  echo ">> doing some preparations..."
  echo ""

  echo ">> generating $DH with size: $DH_SIZE"
  openssl dhparam -out "$DH" $DH_SIZE
fi

if [ ! -e "/etc/nginx/external/cert.pem" ] || [ ! -e "/etc/nginx/external/key.pem" ]
then
  echo ">> generating self signed cert"
  openssl req -x509 -newkey rsa:4086 \
  -subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
  -keyout "/etc/nginx/external/key.pem" \
  -out "/etc/nginx/external/cert.pem" \
  -days 3650 -nodes -sha256
fi

echo ">> copy /etc/nginx/external/*.conf files to /etc/nginx/conf.d/"
cp /etc/nginx/external/*.conf /etc/nginx/conf.d/ 2> /dev/null > /dev/null


#RC CONFIG
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

#Roundcube Webmail
if [ -z ${ROUNDCUBE_NAME+x} ]
then
  ROUNDCUBE_NAME=Roundcube Webmail
fi


ROUNDCUBE_RANDOM=`perl -e 'my @chars = ("A".."Z", "a".."z"); my $string; $string .= $chars[rand @chars] for 1..24; print $string;'` # returns exactly 24 random chars

###
# Configuration
###
if [ ! -e "/roundcube/config/TPLconfig.inc.php" ] 
then
  cp /roundcube/config/config.inc.php /roundcube/config/TPLconfig.inc.php
fi
cp /roundcube/config/TPLconfig.inc.php /roundcube/config/config.inc.php

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
sed -i "s/Roundcube Webmail/$ROUNDCUBE_NAME/g" /roundcube/config/config.inc.php

echo ">> set Timezone -> $ROUNDCUBE_PHP_DATE_TIMEZONE"
sed -i "s!;date.timezone =.*!date.timezone = $ROUNDCUBE_PHP_DATE_TIMEZONE!g" /etc/php5/fpm/php.ini

# exec CMD

/opt/startup-roundcube.sh


echo ">> exec docker CMD"
echo "$@"
exec "$@"
#exec nginx
