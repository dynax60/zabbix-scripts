#!/usr/bin/perl

use strict;
use warnings;
use threads;

$ENV{PATH} = '/usr/local/zb2/bin:/usr/local/bin';

our $verbose = shift; undef $verbose if $verbose && $verbose !~ /^\-vv?$/;
our $zabbix_sender = 'zabbix_sender -z localhost -p 20051';
our $hosts = [
	['192.168.X.1', 'Administrator', 'mypasswd', 'host1'],
	['192.168.X.2', 'Administrator', 'mypasswd', 'host2', qw(fan.1 fan.2 fan.3 fan.4)],
	['192.168.X.3', 'Administrator', 'mypasswd', 'host3'],
];

sub process($);
sub zbsend($$$);

$verbose && ($zabbix_sender .= ' -vv');

my @threads;
push @threads, threads->create(\&process, $_) for @$hosts;
$_->join() for @threads;

sub process($)
{
	my ($host, $user, $pass, $zbhost, @sensors) = @{ $_[0] } or return;
	my $s;

	$verbose && warn "Making IMPI request on host $host...\n";
	for (qx{ ipmitool -H $host -I lanplus -U $user -P $pass sdr })
	{
		chomp;
		my ($key, $val, $status)= grep { s/^\s+//; s/\s+$//; 1; } split(/\|/, $_);
		$key && $key =~ s/\.?\s+/\./g; $key = lc($key);
		($val) = ($val =~ /(\d+(?:[\.\,]\d+)?)/);

		$verbose && warn "$host ($zbhost): [$_], "
		   .(defined $val ? "got key=$key, val=$val, status=$status" : 'were skipped'), "\n";

		next if !defined $val;
		$s->{$key}->{val}=$val;
		$s->{$key}->{status}=$status;
	}

	for (@sensors? @sensors: keys %{$s}) {
		my $state = $s->{$_}->{status} eq 'cr'? 0: 1;
		zbsend( $zbhost, $_, $s->{$_}->{val} ); # send sensor value
		zbsend( $zbhost, "$_.status", $state ); # send sensor status
	}
}

sub zbsend($$$) {
	my ($host, $key, $value) = @_;
	my $cmd = "$zabbix_sender -s $host -k $key -o $value 2>&1";
	my @out = qx{ $cmd };
	my $ret = 1; # successful
	print "$0: zbsend failed: $cmd\n", @out unless $?>>8 == 0;
	$verbose && $verbose eq '-vv' && warn "$host: $zabbix_sender -s $host -k $key -o $value\n";
	$verbose && $verbose eq '-vv' && warn "$host: ", @out;
	(/Failed (\d+)/ && ($ret = ($1 != 0? 0: 1))) for @out;
	$verbose && warn "zbsend: $host|$key|$value -- ",($ret? 'successful': 'failed'),"\n";
	return $ret;
}
