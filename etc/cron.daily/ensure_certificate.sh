#!/bin/bash

if [ -f "$HOME/.webthings/ssl/certificate.pem" ] && [ -f "$HOME/webthings/gateway/tools/make-self-signed-cert.sh" ]; then 
    END_DATE=$(openssl x509 -enddate -noout -in "$HOME/.webthings/ssl/certificate.pem" | cut -d= -f2)
    echo "END_DATE: $END_DATE"
    END_STAMP=$(date -d "$END_DATE" +%s)
    echo "END_STAMP: $END_STAMP"
    
    NOW_STAMP=$(date +%s)
    echo "NOW_STAMP: $NOW_STAMP"
    
    DELTA=$((END_STAMP-NOW_STAMP))
    
    # Three days left
    if [ "$DELTA" -lt "153600" ]; then
        chmod +x "$HOME/webthings/gateway/tools/make-self-signed-cert.sh" 
    	"$HOME/webthings/gateway/tools/make-self-signed-cert.sh"
        if [ -e /dev/kmsg ]; then
            echo "Candle: ensure_certificate.sh: generated fresh self-signed certificate" >> /dev/kmsg
        fi
    fi
fi
