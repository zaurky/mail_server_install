#!/bin/bash

echo "usefull links :
# * http://infos-reseau.com/postfix-amavis-couple-avec-spamassassin-et-clamav/
# * http://linuxaria.com/howto/using-opendkim-to-sign-postfix-mails-on-debian/

"

read -p "Press any key to continue... " -n1 -s
echo

read -p "Enter the domain name : " DOMAIN

echo "On the gandi web site :
 * create a new vm (wheezy - debian 7)
 * change the reverse dns to mail.$DOMAIN
 * note the server ipv4 and 6
"

read -p "Press any key to continue... " -n1 -s
echo

read -p "Enter the ipv4 : " SERVER_IP
read -p "Enter the ipv5 : " SERVER_IPV6

# Modifier la zone du domaine pour ajouter :
echo "Modify the domain zone to put :

\"\"\"
imap 10800 IN A $SERVER_IP
mail 10800 IN A $SERVER_IP
smtp 10800 IN A $SERVER_IP
imap 10800 IN AAAA $SERVER_IPV6
mail 10800 IN AAAA $SERVER_IPV6
smtp 10800 IN AAAA $SERVER_IPV6
@ 10800 IN MX 10 mail.$DOMAIN.
@ 10800 IN TXT \"v=spf1 ip4:$SERVER_IP -all\"
_domainkey 10800 IN TXT \"o=-;\"
\"\"\"

"

read -p "Press any key to continue... " -n1 -s
echo

echo "We are going to copy the files we need on the server, please enter your password when asked"
scp -r install_mail root@$SERVER_IP:/tmp/

echo "We are now login to the server to execute the remaining install script"
ssh root@$SERVER_IP "cd /tmp/install_mail/; ./install_part2.sh $DOMAIN"

echo "Cleaning files on server"
ssh root@$SERVER_IP "rm -fr /tmp/install_mail/"
