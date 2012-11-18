#!/usr/bin/perl

use strict;
use warnings;
use Compress::Raw::Zlib qw(crc32);

binmode STDIN;

my $crc = 0;
my $file = shift || <STDIN>;
open FH, $file or die "Failed to open file: $!\n";
$crc = crc32($_, $crc) while (<FH>);
close FH;

printf "%.8X\n", $crc;
