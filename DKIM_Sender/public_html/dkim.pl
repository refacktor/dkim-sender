#!/usr/bin/perl
# $Id: dkim.pl,v 1.2 2010-04-03 15:23:52 alex Exp $

# CGI
use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

# Email creation
use MIME::Base64;
use URI::Escape;
use Email::MIME::Creator;
use Email::MessageID;

# DKIM
use IO::File;
use Mail::DKIM::Signer;

# DomainKeys
use IO::Lines;
use Mail::DomainKeys::Message;
use Mail::DomainKeys::Key::Private;

# Email sending
use Net::SMTP;
use strict;

# config : SMTP
my $server = "127.0.0.1"; # relay via this SMTP server

# config : DKIM / DomainKeys
my ($domain) = (param('from') =~ /\@(.*)/);
my $selector = "default"; # with that key selector
my $secret_key_file = "../config/$domain-secret.key"; 

if(!-f $secret_key_file) {
   die "File not found: $secret_key_file. Administrator needs to run dkim-setup.sh for $domain";
}

# encoding
my $charset = "utf-8"; # only change the charset if you realy know what you are doing

# content
my @clean_addresses;
my $subject = encode_subject(param('subject'));
my $from = encode_address(param('from'));
my $to = encode_address(param('to'));
my $body = param('body');


# check if encoding is required
# the criteria is a bit paranoid
sub need_encoding{
	my ($raw,) = @_;
	return !($raw =~ /^[a-z0-9_:\.\!+\-\%\/ ]*$/);
}

# encode an email address
sub encode_address{
	my ($raw,) = @_;
	my $encoded = "";
	foreach my $addr (Email::Address->parse($raw)){
		my $tmp = uri_escape($addr->user()) . "@"
			. $addr->host();
		$clean_addresses[$#clean_addresses + 1] = $tmp;
		$tmp = "<" . $tmp . ">";
		if($addr->phrase()){
			$tmp = "\"" . encode_subject($addr->phrase())
				. "\" " . $tmp;
		}
		if($addr->comment()){
			$tmp .= "(" . encode_subject($addr->comment())
				. ")";
		}
		if(length($encoded)){
			$encoded .= ", " . $tmp;
		}else{
			$encoded = $tmp;
		}
	}
	return $encoded;
}

# encode the subject line 
sub encode_subject{
	my ($raw,) = @_;
	if(need_encoding($raw)){
		return "=?" . $charset . "?b?" . encode_base64($raw, "") . "?=";
	}else{
		return $raw;
	}
}

# create email
length($subject) or die "subject is missing";
length($from) or die "sender is missing";
length($to) or die "recipent is missing";
length($body) or die "text is missing";

my $email = Email::MIME->create(
	header => [
		From    => $from,
		To      => $to,
		Subject => $subject,
		'Message-ID' => "<" . Email::MessageID->new . ">"
	],
	body => $body,
);

$email->content_type_set('text/plain');
$email->charset_set($charset);
$email->encoding_set('quoted-printable');

# fix line ends
$email = $email->as_string;
$email =~ s/\r//g;
$email =~ s/\n/\r\n/g;

# sign email : DomainKeys
my @dkim_io_x = split(/\n/, "Sender: <dummy\@$domain>\r\n$email");
my $dkim_io = IO::Lines->new(\@dkim_io_x);
my $dk_mail = load Mail::DomainKeys::Message(File => $dkim_io);
my $dk_secret = load Mail::DomainKeys::Key::Private(File => $secret_key_file);

$dk_mail->sign(Method => "nofws",
	Selector => $selector,
	SignHeaders => "from:to:subject:message-id:date:mime-version:content-type:content-transfer-encoding:cc:bcc:repyl-to",
	Private => $dk_secret);
$email = "DomainKey-Signature: " . $dk_mail->signature->as_string . "\r\n" . $email;

# sign email : DKIM
my $signer = Mail::DKIM::Signer->new(
	Algorithm => "rsa-sha1",
	Method => "relaxed/relaxed",
	Domain => $domain,
	Selector => $selector,
	KeyFile => $secret_key_file);
$signer->PRINT($email);
$signer->CLOSE();
$email = $signer->signature->as_string . "\r\n" . $email;

print header;
print start_html("DKIM Test");
print h2("DKIM Test Message");
print pre(escapeHTML($email));
print h2("Sending...");

# send email
my $smtp = Net::SMTP->new($server) || die "failed to connect to $server";

$smtp->mail(@clean_addresses[0]) || die "sender rejected";
for(my $i = 1; $i - 1< $#clean_addresses; $i++){
	$smtp->to(@clean_addresses[$i]) || die "recipent @clean_addresses[$i] rejected";
}
$smtp->data() || die "failed to send message";
$smtp->datasend($email) || die "failed to send message";
$smtp->dataend() || die "failed to send message";
$smtp->quit();

print end_html;
