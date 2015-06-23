based on docker files and scripts by https://github.com/MarvAmBass
ssl secure,ngnix and roundcube dockerfiles

This dockerfile fetches the latest roundcube. It needs a postgres container to store the user data.
 
build with 

  sudo docker build -t youruser/rc-nginx .

once built, create a postgres container based on the default docker.io image. (next time around, you only need to start it, not recreate it, with sudo docker start roundcube-postgres)

  sudo docker run --name roundcube-postgres -e POSTGRES_USER=roundcube -e POSTGRES_PASSWORD=pgcontainer_rcpassword -d postgres

then run a container based on the image you built (or fetched from dockerhub). There is very little state in the roundcube container so you can remove and run again with a different name and port, and every time you run you'll fetch the latest roundcube,  as the roundcube fetch occurs on entry.

 sudo docker run -p 443:443 -p 80:80 -d --name roundcube-nginx --link roundcube-postgres:postgres -e DH_SIZE=2048 -e POSTGRES_USER=roundcube -e PGPASSWORD=pgcontainer_rcpassword -e ROUNDCUBE_IMAP_PROTO=ssl  -e ROUNDCUBE_IMAP_HOST=mail.yourdomain.net:993 -e ROUNDCUBE_SMTP_HOST=smtp.yourdomain.net -e ROUNDCUBE_SMTP_PORT=587 -e ROUNDCUBE_SMTP_PROTO=ssl -v ~/yourdomain.net.key:/etc/nginx/external/key.pem:ro  -v ~/yourdomain.net.crt:/etc/nginx/external/cert.pem:ro youruser/rc-nginx nginx

most of the -e variables are optional, if you dont specify a cert one will be generated for you; if you do not have a cert remove the -v for the .key and the .cert files, if you leave them there docker will generate a folder these location, and nginx will fail to launch.
