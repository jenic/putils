#!/usr/bin/perl
use strict;
use warnings;

for(glob '~/.gvfs/cdda\ mount\ on\ sr0/*') {
	my $fn = (split /\//)[-1];
	$fn = (split /\./, $fn)[0];
	#print "oggenc -o ~/$fn -q 3.5 $_\n";
	system 'oggenc', "-o".$ENV{HOME}."/$fn.ogg", '-q 3.5', $_;
	printf "$0: child exited with %d\n", $? >> 8 unless($? == 0);
}
