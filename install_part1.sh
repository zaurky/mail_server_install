#!/bin/bash

function create_vm() {
    DOMAIN=$1
    echo "On the gandi web site :
     * create a new vm (wheezy - debian 7)
     * change the reverse dns to mail.$DOMAIN
     * note the server ipv4 and 6
    "

    read -p "Press any key to continue... " -n1 -s
    echo

    read -p "Enter the ipv4 : " SERVER_IP
    read -p "Enter the ipv6 : " SERVER_IPV6
}

function alter_domain_zone() {
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
}


echo "usefull links :
   * http://infos-reseau.com/postfix-amavis-couple-avec-spamassassin-et-clamav/
   * http://linuxaria.com/howto/using-opendkim-to-sign-postfix-mails-on-debian/

"
read -p "Press any key to continue... " -n1 -s
echo

read -p "Enter the domain name : " DOMAIN

create_vm $DOMAIN
alter_domain_zone $DOMAIN $SERVER_IP $SERVER_IPV6

echo "Copying the files we need on the server"
scp -i ~/.ssh/id_dsa.$DOMAIN -r install_mail root@$SERVER_IP:/tmp/

echo "Login to the server to execute the remaining install script"
ssh -i ~/.ssh/id_dsa.$DOMAIN root@$SERVER_IP "cd /tmp/install_mail/; ./install_part2.sh $DOMAIN"

echo "Cleaning files on server"
ssh root@$SERVER_IP "rm -fr /tmp/install_mail/"
