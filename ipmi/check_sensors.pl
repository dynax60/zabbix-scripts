#!/usr/bin/perl

use strict;
use warnings;

$ENV{PATH} = '/usr/local/bin';
@ARGV == 3 or die "Usage: $0 <host> <user> <password>\n";

sub process($);

&process(@ARGV);

sub process($)
{
	my ($host, $user, $pass) = @_ or return;

	print "Making IMPI request on host $host...\n";
	for (qx{ ipmitool -H $host -I lanplus -U $user -P $pass sdr })
	{
		chomp;
		my ($key, $val, $status)= grep { s/^\s+//; s/\s+$//; 1; } split(/\|/, $_);
		$key && $key =~ s/\.?\s+/\./g; $key = lc($key);
		($val) = ($val =~ /(\d+(?:[\.\,]\d+)?)/);

		print "$host: [$_], "
		   .(defined $val ? "got key=$key, val=$val, status=$status" : 'were skipped'), "\n";
	}
}
