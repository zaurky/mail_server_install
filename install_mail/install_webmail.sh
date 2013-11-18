#!/bin/bash

# from http://www.linux-magazine.com/Online/Blogs/Productivity-Sauce/Rainloop-Lightweight-Webmail-Client

apt-get install --yes apache2 php5 php5-curl

mkdir /var/www/rainloop
cd /var/www/rainloop
find . -type d -exec chmod 777 {} \;
find . -type f -exec chmod 666 {} \;
chown -R www-data:www-data .
wget -qO- http://repository.rainloop.net/installer.php | php

echo "
Now go to http://mail.veau.me/rainloop/?admin
Log in as admin/12345
And start by changing the admin password

Then go to the Domain tab and add your domain
XXXXX

"



