#!/usr/bin/perl
use strict;
use warnings;

my $arg = $ARGV[-1] || '0';
my $progress = sub {
	my $t = shift;
	my $c = `qdbus org.kde.amarok /Player org.freedesktop.MediaPlayer.PositionGet`;
	return sprintf "%.0f", ( $c * 100 / $t );
};
my $introspect = sub {
	my $ref = shift;
	my $out;
	my %qmap = %$ref;
	$out .= "$_  =\t" . $qmap{$_} . "\n" for (keys %qmap);
	return $out;
};

my @rawout = split('\n', `qdbus org.kde.amarok /Player org.freedesktop.MediaPlayer.GetMetadata`);
my %qmap = map { my @r = split /:\s+/; $r[0] => $r[1] || '' } @rawout;
if($arg eq 'dump') {
	print $introspect->(\%qmap);
	exit;
}
#print $qmap{$arg} || $progress->($qmap{mtime});
print ((exists $qmap{$arg}) ? $qmap{$arg} : $progress->($qmap{mtime}));
