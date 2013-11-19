#!/bin/bash

DOMAIN=$1

apt-get update

echo "We are going to install the locales you want"
read -p "Press any key to continue... " -n1 -s
echo

dpkg-reconfigure locales

perl -pi -e 's|localhost$|localhost mail mail.veau.me|' /etc/hosts

### POSTFIX
echo "We are going to install postfix, select \"internet website\" and then \"mail.$DOMAIN\"
"
read -p "Press any key to continue... " -n1 -s
echo

apt-get install --yes postfix

echo $DOMAIN > /etc/mailname

cp /etc/postfix/main.cf /etc/postfix/main.cf.orig
perl -pi -e "s/myhostname = .*$/myhostname = mail.$DOMAIN/" /etc/postfix/main.cf
perl -pi -e "s/mydestination = .*$/mydestination = $DOMAIN, localhost.$DOMAIN, localhost, mail.$DOMAIN/" /etc/postfix/main.cf
echo '
mailbox_command = /usr/lib/dovecot/deliver
inet_protocols = all

# SASL
smtpd_sasl_auth_enable  = yes
smtpd_sasl_type         = dovecot
smtpd_sasl_path         = private/auth

mailbox_transport = lmtp:unix:private/dovecot-lmtp

smtpd_helo_restrictions = yes
strict_rfc821_envelopes = yes
smtpd_helo_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_hostname, reject_invalid_helo_hostname
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unauth_pipelining
smtpd_recipient_restrictions = reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_recipient, reject_unknown_recipient_domain, reject_unauth_destination


content_filter = smtp-amavis:[127.0.0.1]:10024

# OpenDKIM
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:8891
non_smtpd_milters = $smtpd_milters' >> /etc/postfix/main.cf

mv /etc/postfix/master.cf /etc/postfix/master.cf.orig
cp data/master.cf /etc/postfix/master.cf


### SASL
apt-get install --yes sasl2-bin
perl -pi -e 's|START=no|START=yes|' /etc/default/saslauthd
perl -pi -e 's|MECHANISMS="pam"|MECHANISMS="rimap"|' /etc/default/saslauthd
perl -pi -e 's|OPTIONS="-c -m /var/run/saslauthd"||' /etc/default/saslauthd
echo '
PWDIR=/var/spool/postfix/var/run/saslauthd
PIDFILE="${PWDIR}/saslauthd.pid"
OPTIONS="-r -m /var/spool/postfix/var/run/saslauthd -O localhost -c"' >> /etc/default/saslauthd


### DOVECOT
apt-get install --yes dovecot-common dovecot-core dovecot-imapd dovecot-lmtpd

echo "
protocols = imap lmtp

#auth_verbose=yes
#auth_debug=yes
#auth_debug_passwords=yes
#mail_debug=yes
#verbose_ssl=yes

ssl_cert=</etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_key=</etc/ssl/private/ssl-cert-snakeoil.key
" >> /etc/dovecot/dovecot.conf

perl -pi -e 's|#auth_username_format = %Lu|auth_username_format = %n|' /etc/dovecot/conf.d/10-auth.conf
perl -pi -e 's|mail_location =.*$|mail_location = mbox:~/mail:INBOX=~/mail/INBOX|' /etc/dovecot/conf.d/10-mail.conf
mv /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig
cp data/10-master.conf /etc/dovecot/conf.d/10-master.conf
perl -pi -e 's|ssl_cert = .*$|ssl_cert = \</etc/ssl/certs/ssl-cert-snakeoil.pem|' /etc/dovecot/conf.d/10-ssl.conf
perl -pi -e 's|ssl_key = .*$|ssl_key = \</etc/ssl/private/ssl-cert-snakeoil.key|' /etc/dovecot/conf.d/10-ssl.conf
perl -pi -e "s|#hostname =.*$|hostname = mail.$DOMAIN|" /etc/dovecot/conf.d/15-lda.conf
perl -pi -e 's|protocol lda {|protocol lda {\n  mail_plugins = sieve|' /etc/dovecot/conf.d/15-lda.conf
mv /etc/dovecot/conf.d/20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf.orig
echo "protocol lmtp {
  postmaster_address = postmaster@$DOMAIN   # required
  mail_plugins = quota sieve
}" > /etc/dovecot/conf.d/20-lmtp.conf


### SIEVE
apt-get install --yes dovecot-sieve


### AMAVIS
apt-get install --yes amavisd-new gzip bzip2 unzip unrar cpio rpm nomarch cabextract arj arc zoo lzop pax
perl -pi -e 's|^# ?\$unfreeze|\$unfreeze|' /etc/amavis/conf.d/01-debian
perl -pi -e 's|^\$unfreeze\s+= undef;|# \$unfreeze = undef;|' /etc/amavis/conf.d/01-debian
perl -pi -e 's|^# ?\$lha|\$lha|' /etc/amavis/conf.d/01-debian
perl -pi -e 's|^\$lha\s+= undef;|# \$lha = undef;|' /etc/amavis/conf.d/01-debian
perl -pi -e "s|use strict;|use strict;\n\@local_domains_maps = ( [ '.$DOMAIN', '.mail.$DOMAIN' ] );|" /etc/amavis/conf.d/05-domain_id
perl -pi -e 's|#\$myhostname = "mail.example.com";|\$myhostname = "mail.'$DOMAIN'";|' /etc/amavis/conf.d/05-node_id
perl -pi -e "s|=>  1.0,|=>  1.0,\n     '.$DOMAIN'                                 => -3.0,|" /etc/amavis/conf.d/20-debian_defaults
perl -pi -e 's|#\@bypass_spam_checks_maps|\@bypass_spam_checks_maps|' /etc/amavis/conf.d/15-content_filter_mode
perl -pi -e 's|#   \\%bypass_spam_checks|   \\%bypass_spam_checks|' /etc/amavis/conf.d/15-content_filter_mode
echo "amavis:        root" >> /etc/aliases


### SPAMASSASSIN
apt-get install --yes spamassassin
perl -pi -e 's|ENABLED=0|ENABLED=1|' /etc/default/spamassassin


### OPENDKIM
apt-get install --yes opendkim opendkim-tools
mv /etc/opendkim.conf /etc/opendkim.conf.orig
cp data/opendkim.conf /etc/opendkim.conf
mkdir -p /etc/opendkim/$DOMAIN
perl -pi -e "s|##DOMAIN##|$DOMAIN|" /etc/opendkim.conf
echo "$DOMAIN $DOMAIN:mail:/etc/opendkim/$DOMAIN/mail" > /etc/opendkim/KeyTable
echo "*@$DOMAIN $DOMAIN" > /etc/opendkim/SigningTable
echo -e "127.0.0.1\n$DOMAIN" > /etc/opendkim/TrustedHosts
chmod go-rwx /etc/opendkim/* 
chown -R opendkim:opendkim /etc/opendkim
cd /etc/opendkim/$DOMAIN
opendkim-genkey -r -h rsa-sha256 -d $DOMAIN -s mail
mv mail.private mail
chown opendkim:opendkim *
chmod u=rw,go-rwx * 

echo "mettre la ligne suivante dans la zone du domain"
cat /etc/opendkim/$DOMAIN/mail.txt
read -p "Press any key to continue... " -n1 -s


### add user
read -p "Enter your user name (the left part of the email address), it will be your domain admin : " USERLOGIN
echo

useradd  -m $USERLOGIN
chsh $USERLOGIN /sbin/noshell
echo "Enter password for $USERLOGIN"
passwd $USERLOGIN

mkdir /home/$USERLOGIN/mail -p
touch /home/$USERLOGIN/mail/INBOX
chown $USERLOGIN:mail /home/$USERLOGIN/mail -R
echo "root: $USERLOGIN" >> /etc/aliases



### RESTART SERVICES
newaliases
service saslauthd restart
service dovecot restart
service amavis restart
service spamassassin restart
service opendkim restart
service postfix restart


# pour tester l'email :
# * envoyer un mail a check-auth@verifier.port25.com
# * demander un test sur http://emailaudit.com
