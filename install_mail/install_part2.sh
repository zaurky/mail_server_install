#!/bin/bash

DOMAIN=$1

export TERM='xterm'
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive


echo "updating apt repo"
apt-get update > /dev/null
apt-get install --yes debconf-utils > /dev/null

echo "We are going to install the locales you want"
locale-gen --purge en_US.UTF-8
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale


perl -pi -e "s|localhost$|localhost mail mail.$DOMAIN|" /etc/hosts

### POSTFIX
echo "We are going to install postfix"
echo "postfix   postfix/mailname    string  mail.$DOMAIN" | debconf-set-selections
echo "postfix   postfix/main_mailer_type    select  Internet Site" | debconf-set-selections
echo "postfix   postfix/destinations    string  mail.veau.me, veau.me, localhost.veau.me, localhost" | debconf-set-selections


echo "installing postfix"
apt-get install -q --yes postfix > /dev/null

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
echo "installing sasl"
apt-get install --yes sasl2-bin > /dev/null
perl -pi -e 's|START=no|START=yes|' /etc/default/saslauthd
perl -pi -e 's|MECHANISMS="pam"|MECHANISMS="rimap"|' /etc/default/saslauthd
perl -pi -e 's|OPTIONS="-c -m /var/run/saslauthd"||' /etc/default/saslauthd
echo '
PWDIR=/var/spool/postfix/var/run/saslauthd
PIDFILE="${PWDIR}/saslauthd.pid"
OPTIONS="-r -m /var/spool/postfix/var/run/saslauthd -O localhost -c"' >> /etc/default/saslauthd


### DOVECOT
echo "installing dovecot"
apt-get install --yes dovecot-common dovecot-core dovecot-imapd dovecot-lmtpd > /dev/null

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
perl -pi -e 's|#imap_idle_notify_interval = 2 mins|imap_idle_notify_interval = 29 mins|' /etc/dovecot/conf.d/20-imap.conf
mv /etc/dovecot/conf.d/20-lmtp.conf /etc/dovecot/conf.d/20-lmtp.conf.orig
echo "protocol lmtp {
  postmaster_address = postmaster@$DOMAIN   # required
  mail_plugins = quota sieve
}" > /etc/dovecot/conf.d/20-lmtp.conf


### SIEVE
echo "installing sieve"
apt-get install --yes dovecot-sieve > /dev/null


### AMAVIS
echo "installing amavis"
apt-get install --yes amavisd-new gzip bzip2 unzip unrar cpio rpm nomarch cabextract arj arc zoo lzop pax > /dev/null
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
echo "installing spamassassin"
apt-get install --yes spamassassin > /dev/null
perl -pi -e 's|ENABLED=0|ENABLED=1|' /etc/default/spamassassin


### OPENDKIM
echo "installing opendkim"
apt-get install --yes opendkim opendkim-tools > /dev/null
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

echo "put the following line in your domain dns"
cat /etc/opendkim/$DOMAIN/mail.txt
echo "Press any key to continue... "
read -s
echo


### add user
echo "Enter your user name (the left part of the email address), it will be your domain admin : "
read USERLOGIN
echo

useradd  -m $USERLOGIN
# chsh -s /sbin/noshell $USERLOGIN
echo "Enter password for $USERLOGIN"
passwd $USERLOGIN

mkdir /home/$USERLOGIN/mail -p
touch /home/$USERLOGIN/mail/INBOX
touch /home/$USERLOGIN/mail/spam
chown $USERLOGIN:mail /home/$USERLOGIN/mail -R
echo 'require ["fileinto"];
# Move spam to spam folder
if header :contains "X-Spam-Flag" ["YES"] {
  fileinto "spam";
  stop;
}
if header :contains "subject" "***SPAM***" {
  fileinto "spam";
  stop;
}
' > /home/$USERLOGIN/.dovecot.sieve
su - $USERLOGIN -c "sievec .dovecot.sieve"

echo "root: $USERLOGIN" >> /etc/aliases



### RESTART SERVICES
echo "restarting all services"
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
