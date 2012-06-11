#!/usr/bin/perl
use strict;
use warnings;
use feature ":5.10";

my %presets = (
	default => 'amarok',
	strings =>
		{ plugin	=> 'ALSA plug-in [plugin-container]'
		, mplayer	=> 'MPlayer'
		},
	lambdas =>
		{ raw		=>	sub { return ($_[0] =~ /^i\d+/) ? substr($_[0], 1) : undef; }
		, noop	=>	sub { return undef }
		}
);

use constant HELPTEXT => <<EOF;
Syntax: $0 [ <appname> | <sink #> ] [ <appname> | <sink #> ]
Example: $0 mplayer 0 [OR] $0 0 mplayer
	This will change mplayer to sink #0
Example 2: $0 1
	This will change default app to sink #1
Example 3: $0 i1194
	appname can be substituted for client ID found in client list
----------
Null	List Clients
?!	List Sinks
N/A	Show this help
EOF

$_ = `pacmd list-sink-inputs`;
my @lines = split /\n/;
my %apps;
my $state = 0;
my $appn;
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
		print HELPTEXT if($? != 0);
	}
	when (/^[0-9]/) {
		my $app = &presets($ARGV[1] || undef);
		system "pactl", "move-sink-input", $app, $ARGV[0];
		print HELPTEXT if($? != 0);
	}
	when ("?!") {
		print `pacmd list-sinks | grep index`; # just bastardize this, fuck doing it in perl
	}
	default { print HELPTEXT; }
}
sub presets {
	return $apps{ $presets{'default'} } if(!$_[0]);
	my $arg = shift;

	for(keys %{$presets{'strings'}}) {
		return $apps{ $presets{'strings'}->{$_} } if($arg eq $_);
	}
	for(keys %{$presets{'lambdas'}}) {
		my $r = $presets{'lambdas'}->{$_}->($arg);
		return $r if($r);
	}
	return $apps{$arg} || $arg;
}
