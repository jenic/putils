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

	printf "%.8X\n", $crc;
} continue {
	$crc = 0;
}
