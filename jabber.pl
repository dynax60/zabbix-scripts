#!/usr/bin/perl

use common::sense;
use Net::XMPP;

use constant {
	SERVER 		=> 'mon.domain.ru',
	PORT 		=> 5222,
	USER 		=> 'zabbix',
	PASSWORD 	=> 'password',
	RESOURCE	=> 'perl-script',
	TLS			=> 0,
	DEBUG		=> 0,
	};
	
$0 =~ s{.*/}{};
my ($to, $subj, $body, $type) = @ARGV;
$type ||= 'headline';

die << "EOF" unless @ARGV == 3 or @ARGV == 4;
Usage: $0 <jid> <subject> <body> [type]
EOF

utf8::decode($subj);
utf8::decode($body);

my $bot = new Net::XMPP::Client( debuglevel => DEBUG ); 

$bot->SetCallBacks( 
    onconnect => sub{},
    onauth => sub{
		$bot->PresenceSend;
		$bot->MessageSend( to => $to, subject => $subj, body => $body, type => $type );
		$bot->Disconnect();
	},
    ondisconnect => sub{}
); 

$bot->Execute( 
	hostname => SERVER,
	port => PORT, 
	tls => TLS, 
	username => USER, 
	password => PASSWORD, 
	resource => RESOURCE, 
	register => 0, 
	connectiontype => 'tcpip'
);