#!/usr/bin/perl
use strict;

$_ = <STDIN>;
chomp;
my @files = split;
my $toget;
my ($sec, $min, $hour, $mday, $mon, $year) = gmtime;
$mon++;
$mon = sprintf("%02d", $mon);
$mday = sprintf("%02d", $mday);
print "\n\n";
for (0 .. $#files) {
	my ($pre, $post) = split '_', $files[$_], 2;
	$toget .= $pre . '_' . $_ . '.wmv ' for (1 .. 6);
}
mkdir $mon . $mday unless(-d $mon . $mday);

system "wget -P $mon$mday -nv --wait=.5 --random-wait --user-agent=\"Mozilla/5.0 (Windows NT 5.1; rv:2.0) Gecko/20100101 Firefox/4.0\" $toget";
