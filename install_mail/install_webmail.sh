#!/bin/bash

# from http://www.linux-magazine.com/Online/Blogs/Productivity-Sauce/Rainloop-Lightweight-Webmail-Client

DOMAIN=$1

apt-get install --yes apache2 php5 php5-curl
a2enmod ssl

mkdir /var/www/rainloop
cd /var/www/rainloop
find . -type d -exec chmod 777 {} \;
find . -type f -exec chmod 666 {} \;
chown -R www-data:www-data .
wget -qO- http://repository.rainloop.net/installer.php | php

echo "
Now go to http://mail.$DOMAIN/rainloop/?admin
Log in as admin/12345
And start by changing the admin password

Then go to the Domain tab and add your domain
XXXXX

"

echo "
<VirtualHost mail.$DOMAIN:443>
        ServerAdmin webmaster@$DOMAIN
        DocumentRoot /var/www/rainloop

        SSLEngine on
        SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        SSLVerifyClient None

        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        ErrorLog \${APACHE_LOG_DIR}/webmail.error.log
        LogLevel warn

        CustomLog \${APACHE_LOG_DIR}/webmail.access.log combined
        
        <IfModule mod_headers.c>                                                                                                                                           
            Header set Strict-Transport-Security "max-age=15768000;"                                                                                                   
            Header set X-Content-Type-Options "nosniff"                                                                                                                
            Header set X-Frame-Options "DENY"                                                                                                                          
            Header set X-XSS-Protection "1; mode=block"                                                                                                                
            Header set Content-Security-Policy "script-src 'self'"                                                                                                     
        </IfModule>  
</VirtualHost>
" >> /etc/apache2/sites-enabled/000-default

a2enmod headers
service apache2 start || service apache2 reload
