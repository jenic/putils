#!/usr/bin/perl
use strict;
use warnings;

my $o = $ARGV[0] || 1;
chomp(my $c = `qdbus org.kde.amarok /Player org.freedesktop.MediaPlayer.VolumeGet`);
my $v = ($c + $o);
`qdbus org.kde.amarok /Player org.freedesktop.MediaPlayer.VolumeSet $v`;
print "$v\n";
