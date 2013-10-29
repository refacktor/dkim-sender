#!/bin/sh

perl -MCPAN -e 'install Email::MIME::Creator'

perl -MCPAN -e 'install Mail::DKIM::Signer'

perl -MCPAN -e 'install IO::Lines'

perl -MCPAN -e 'install Mail::DomainKeys::Message'
