#!/bin/bash

if [ x$1 = x ]
then
  echo "Usage: $0 [your domain name here]"
  exit 1
else
  DOMAIN=$1
fi

BITS=1024

private="$DOMAIN-secret.key"
config="$DOMAIN-instructions.txt"

#
# generate DomainKeys 
#
openssl genrsa -out $private $BITS && {
	public=`mktemp` && openssl rsa -in $private -out $public -pubout && {
	    (
		echo "* Add the following IN TXT record to your DNS configuration for $DOMAIN"
        echo ""
		sed -e '1i\default._domainkey.'$DOMAIN' IN TXT "g=; k=rsa; p=' -e '/^----/d' < $public | tr -d '\n' | sed -e 's/$/"\n/'
		) > $config
		rm -f $public
	}
	echo ""
    echo "-------- IMPORTANT ---------"
	echo "Private key written to..............: $private" 
    echo "DNS config instructions written to..: $config" 
    
}

