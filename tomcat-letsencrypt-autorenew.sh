#!/bin/bash
set -ex
DOMAIN=""
TOMCAT_KEY_PASS=""
CERTBOT_BIN="/usr/local/bin/certbot-auto"
EMAIL_NOTIFICATION=""

# Install certbot

install_certbot () {
    if [[ ! -f /usr/local/bin/certbot-auto ]]; then
        wget https://dl.eff.org/certbot-auto -P /usr/local/bin
        chmod a+x $CERTBOT_BIN
    fi
}

# Attempt cert renewal:
renew_ssl () {
    ${CERTBOT_BIN} renew  > /etc/letsencrypt/crt.txt
    cat /etc/letsencrypt/crt.txt | grep "No renewals were attempted"
    if [[ $? -eq "0" ]]; then
        echo "Cert not yet due for renewal"
        exit 0
    else

        # Create Letsencypt ssl dir if doesn't exist
        echo "Renewing ssl certificate..."

        # create a PKCS12 that contains both your full chain and the private key
        rm -f /etc/letsencrypt/fullchain_and_key.p12 2>/dev/null
        openssl pkcs12 -export -out /etc/letsencrypt/fullchain_and_key.p12 -passin pass:$TOMCAT_KEY_PASS -passout pass:$TOMCAT_KEY_PASS -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem -inkey /etc/letsencrypt/live/${DOMAIN}/privkey.pem -name tomcat
    fi
 }

# Convert that PKCS12 to a JKS
pkcs2jks () {
    rm -f /etc/letsencrypt/${DOMAIN}.jks 2>/dev/null
    keytool -importkeystore -deststorepass $TOMCAT_KEY_PASS -destkeypass $TOMCAT_KEY_PASS -destkeystore /etc/letsencrypt/${DOMAIN}.jks -srckeystore /etc/letsencrypt/fullchain_and_key.p12 -srcstoretype PKCS12 -srcstorepass $TOMCAT_KEY_PASS -alias tomcat
}

# Send email notification on completion
send_email_notification () {
    if [[ $? -eq "0" ]]; then
        echo " Retarting tomcat server"
        systemctl restart tomcat
        if [[ $? -eq "0" ]]; then
            echo "" > /etc/letsencrypt/success
            echo "Letsencrypt ssl certificate for $DOMAIN successfully renewed by cron job." >> /etc/letsencrypt/success
            echo "" >> /etc/letsencrypt/success
            echo "Tomcat successfully restarted after renewal" >> /success
            mail -s "$DOMAIN Letsencrypt renewal" $EMAIL_NOTIFICATION < /success
        else
            echo "" > /etc/letsencrypt/failure
            echo "Letsencrypt ssl certificate for $DOMAIN renewal by cron job failed." >> /etc/letsencrypt/failure
            echo "" >> /etc/letsencrypt/failure
            echo "Try again manually.." >> /etc/letsencrypt/failure
            mail -s "$DOMAIN Letsencrypt renewal" $EMAIL_NOTIFICATION < /etc/letsencrypt/failure
        fi
    fi
}

# Main

install_certbot
renew_ssl
pkcs2jks
send_email_notification
