#!/usr/bin/perl
use strict;
use warnings;
use feature ":5.10";

my %presets = {
	default => 'amarok',
	strings =>
		{ plugin => 'ALSA plug-in [plugin-container]'
		, mplayer => 'MPlayer'
		},
	lambdas =>
		{ rawid => sub { return substr($_[0], 1); }
		}
};

$_ = `pacmd list-sink-inputs`;
my @lines = split /\n/;
my %apps;
my $state = 0;
my $appn;
my $helptext <<EOF
Syntax: $0 [ <appname> | <sink #> ] [ appname | <sink #> ]
Example: $0 mplayer 0 [OR] $0 0 mplayer
	This will change mplayer to sink #0
Example 2: $0 1
	This will change amarok to sink #1
----------
Null	List Clients
?!	List Sinks
N/A	Show this help
EOF
sub presets;

#for (0 .. $#lines) {
for (@lines) {
	if(/^\s+index:\s([0-9]+)$/) {
		$appn = $1;
		$state = 1;
		next;
		# Should always be 19 lines ahead but we shouldn't count on that
		#$lines[$_+19] =~ s/\t+application\.name\s=\s\"(.*)\"$/$1/;
		#$apps{$lines[$_+19]} = $appn;
	} elsif(/\t+application\.name\s=\s\"(.*)\"$/ && $state == 1) {
		$apps{$1} = $appn;
		$appn = undef;
		$state = 0;
	}
}

given($ARGV[0]) {
	when (undef) {
		print "$_ => " . $apps{$_} . "\n" for (keys %apps);
	}
	when (/^[A-z]/) {
		my $sink = $ARGV[1] || 0;
		my $app = &presets($ARGV[0]);
		system 'pactl', 'move-sink-input', $app, $sink;
	}
	when (/^[0-9]/) {
		my $app = &presets($ARGV[1]);
		system "pactl", "move-sink-input", $app, $ARGV[0];
	}
	when ("?!") {
		print `pacmd list-sinks | grep index`; # just bastardize this, fuck doing it in perl
	}
	default { print $helptext; }
}
sub presets {
	my $out;
	given($_[0]) {
		when (undef) {
			$out = 'amarok';
		}
		when ("plugin") {
			$out = 'ALSA plug-in [plugin-container]';
		}
		when ("mplayer") {
			$out = 'MPlayer';
		}
		when (/^i\d+/) {
			$out = substr($_[0], 1);
		}
		default {
			$out = $_[0];
		}
	}
	return ($out =~ /\d+/) ? $out : $apps{$out};
}
