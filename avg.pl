#!/usr/bin/perl
use strict;
use warnings;

my @args = @ARGV;
@args = split ' ', <STDIN> if(@args < 1);
chomp @args;

my ($m, $x, $n) = ($args[0], $args[0], 0);

for (@args) {
	$n += $_;
	$m = $_ if($m > $_);
	$x = $_ if($x < $_);
}

print "avg ".$n / @args . "\nmax $x\nmin $m\nrange ".($x - $m)."\nsum $n\n";
