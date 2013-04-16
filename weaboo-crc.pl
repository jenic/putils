#!/usr/bin/perl

use strict;
use warnings;
use Compress::Raw::Zlib qw(crc32);

binmode STDIN;

my $crc = 0;
for my $file ( @ARGV ) {
	unless (-e $file) {
		warn "$file not found, skipping", "\n";
		next;
	}
	warn "$file:", "\n";
	open FH, $file or die "Failed to open file: $!\n";
	$crc = crc32($_, $crc) while (<FH>);
	close FH;
	
	my $hex = sprintf "%.8X", $crc;
	if ($file =~ /\[([A-f0-9]{8})\]/) {
		printf "%s\t%s\n",
			$hex,
			(hex($hex) == hex($1)) ? "MATCH" : "FAIL";
	} else {
		print $hex, "\n";
	}

} continue {
	$crc = 0;
}
