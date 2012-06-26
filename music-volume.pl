#!/usr/bin/perl
use strict;

my @args = ('qdbus', 'org.kde.amarok', '/Player');
my $o = $ARGV[0] || 1;
chomp(my $c = `@args org.freedesktop.MediaPlayer.VolumeGet`);
my $v = ($c + $o);
system @args, 'org.freedesktop.MediaPlayer.VolumeSet', $v;
