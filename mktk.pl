#!/usr/bin/perl
use common::sense;
use Net::Telnet::Cisco;
use Data::Dumper;
use JSON::XS;

++$|;
$/ = "\n";

$0 =~ s{.*/}{};

my $TelnetPort = 23;
my $TelnetUser = $ENV{MKTK_USER} || die "Specify environment MKTK_USER";
my $TelnetPass = $ENV{MKTK_PASS} || die "Specify environment MKTK_PASS";
my $TelnetHost = shift || &usage;
my $WlanInterface = shift || &usage;
my $Param = shift;

my $CacheFile	= '/tmp/'.$TelnetHost.'_mktk';
my $CacheExpire	= 60; # seconds

my $wlan;

my $cache = &cache_load if -r $CacheFile;
if ($cache) {
	$wlan = $cache;
	die "$0: No such interface: $WlanInterface\n" unless $wlan->{ $WlanInterface };
	goto Cache if $cache;
}

my $mktk = Net::Telnet::Cisco->new(
	Host	=> $TelnetHost,
	Port	=> $TelnetPort,
	Prompt	=> '/[\>\#] $/',
	Timeout => 30);

$mktk->login($TelnetUser . '+ct', $TelnetPass) or die "$0: $mktk->error";

for ($mktk->cmd(qq{ /interface wireless registration-table print })) {
	next unless /^ \d+ /;
	my ($wlan_if, $signal) = (split)[1,5];
	$signal =~ s/dBm.*//;
	$wlan->{$wlan_if}->{signal} = $signal;
}

die "$0: No such interface: $WlanInterface\n" unless $wlan->{ $WlanInterface };

my $in_block = 0;
my $wlan_if = '';
for ($mktk->cmd(qq{ /interface wireless registration-table print stats without-paging })) {
	if (/interface=(\S+)/) {
		$in_block = 1;
		$wlan_if = $1;
	} elsif (/^\n$/s) {
		$in_block = 0;
	}

	if ($in_block && exists $wlan->{ $wlan_if } ) {
		$wlan->{$wlan_if}->{data} .= $_;
	}
}

my $data = '';
$data .= $_ foreach $mktk->cmd(qq{ /interface wireless monitor $WlanInterface once });
$data =~ s/\n/ /g;
$data =~ s/\s{2,}/ /g;
$data =~ s/(,) /$1/g;
$wlan->{$WlanInterface}->{$1} = $2 while $data =~ m{(\S+): (.*?) (?=\S+:)?}g;

$wlan->{$WlanInterface}->{data} =~ s/[\n\t]/ /g;
$wlan->{$WlanInterface}->{data} =~ s/\s{2, }/ /g;
$wlan->{$WlanInterface}->{$1} = $2 
	while $wlan->{$WlanInterface}->{data} =~ m{(\S+)\=(.*?) (?=\S+\=)?}g;
delete $wlan->{$WlanInterface}->{data};

$wlan->{$WlanInterface}->{'signal'} = ($wlan->{$WlanInterface}->{'signal'} =~ m/(.?\d+)/)[0];
$wlan->{$WlanInterface}->{'tx-ccq'} = ($wlan->{$WlanInterface}->{'tx-ccq'} =~ m/(.?\d+)/)[0];
$wlan->{$WlanInterface}->{'rx-ccq'} = ($wlan->{$WlanInterface}->{'rx-ccq'} =~ m/(.?\d+)/)[0];
$wlan->{$WlanInterface}->{'noise-floor'} = ($wlan->{$WlanInterface}->{'noise-floor'} =~ m/(.?\d+)/)[0];
$wlan->{$WlanInterface}->{'tx-rate'} = ($wlan->{$WlanInterface}->{'tx-rate'} =~ m/(\d+)/)[0];
$wlan->{$WlanInterface}->{'rx-rate'} = ($wlan->{$WlanInterface}->{'rx-rate'} =~ m/(\d+)/)[0]; 
$wlan->{$WlanInterface}->{'frequency'} = ($wlan->{$WlanInterface}->{'frequency'} =~ m/(\d+)/)[0]; 

Cache:

&cache_save( $wlan ) unless $cache;

if ($Param && $wlan->{$WlanInterface}->{$Param}) {
	print "$wlan->{$WlanInterface}->{$Param}\n";
	exit;
}

while(my( $param, $value ) = each %{ $wlan->{ $WlanInterface }}) {
	print "$param: $value\n";
}

sub usage {
	die << "_EOF_";
Usage: $0 <host> <wlan interface>
Enviroments:
	MKTK_USER - username 
	MKTK_PASS - password
_EOF_
}

sub cache_load
{
	return unless -r $CacheFile && !-z $CacheFile;
	my $modtime = (stat($CacheFile))[9];
	
	return if $modtime < time()-$CacheExpire;
	
	open my $fh, '<' . $CacheFile or die "$0: Cannot read from $CacheFile: $!\n";
	local undef $/;
	return decode_json(<$fh>);
}

sub cache_save
{
	my $hash_ref = shift or return;
	open my $fh, '>' . $CacheFile or die "$0: Cannot write to $CacheFile: $!\n";
	print $fh encode_json($hash_ref);
}
