#!/bin/bash

# dont want ssh-agent to say he don't know how to do stuff I didn't ask him to do
export SSH_AUTH_SOCK=0

function create_vm_manual() {
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

function create_vm_auto() {
    DOMAIN=$1
    echo "Please insert your gandi apikey"
    read APIKEY

    echo "Generating an ssh key put a password if you want"
    ssh-keygen -f ~/.ssh/id_dsa.mail.$DOMAIN -t dsa

    echo "Creating vm"
    ./create_vm.py -s ~/.ssh/id_dsa.mail.$DOMAIN.pub \
                   -d $DOMAIN -a $APIKEY | tee /tmp/create_vm.mail.$DOMAIN

    SERVER_IP=`grep IPV4 /tmp/create_vm.mail.$DOMAIN | awk '{print $2}'`
    SERVER_IPV6=`grep IPV6 /tmp/create_vm.mail.$DOMAIN | awk '{print $2}'`
}

function create_vm() {
    DOMAIN=$1

    echo "Do you want the vm to be automatically created at gandi ? (y/N)"
    read -n 1 ANSWER

    if [ "x$ANSWER" == "xY" ] || [ "x$ANSWER" == "xy" ]; then
        create_vm_auto $DOMAIN
    elif [ "x$ANSWER" == "xN" ] || [ "x$ANSWER" == "xn" ]; then
        create_vm_manual $DOMAIN
    else
        create_vm_manual $DOMAIN
    fi
}

function alter_domain_zone() {
    DOMAIN=$1
    SERVER_IP=$2
    SERVER_IPV6=$3

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

function install_webmail() {
    DOMAIN=$1
    SERVER_IP=$2

    echo "Do you want to install a webmail ? (y/N)"
    read -n 1 ANSWER

    if [ "x$ANSWER" == "xY" ] || [ "x$ANSWER" == "xy" ]; then
        ssh -i ~/.ssh/id_dsa.mail.$DOMAIN root@$SERVER_IP "cd /tmp/install_mail/; ./install_webmail.sh $DOMAIN"
    fi
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
scp -i ~/.ssh/id_dsa.mail.$DOMAIN -r install_mail root@$SERVER_IP:/tmp/

echo "Login to the server to execute the remaining install script"
ssh -i ~/.ssh/id_dsa.mail.$DOMAIN root@$SERVER_IP "cd /tmp/install_mail/; ./install_part2.sh $DOMAIN"

install_webmail $DOMAIN $SERVER_IP

echo "Cleaning files on server"
ssh -i ~/.ssh/id_dsa.mail.$DOMAIN root@$SERVER_IP "rm -fr /tmp/install_mail/"
