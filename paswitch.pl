#!/usr/bin/perl
use strict;
use warnings;
use feature ":5.10";

my %presets = (
	default => 'Music Player Daemon',
	strings =>
		{ plugin	=> 'ALSA plug-in [plugin-container]'
		, mplayer	=> 'MPlayer'
		},
	lambdas =>
		{ raw	=>	sub { return ($_[0] =~ /^i\d+/) ? substr($_[0], 1) : undef; }
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
	(Feature available only if presets->{lambdas}->{raw} is defined)
----------
Null	List Clients/Sinks
N/A	Show this help
EOF

$_ = `pacmd list-sink-inputs`;
my @lines = split /\n/;
my (%apps, %appsinfo); # appsinfo.id = apps.id
my $state = 0;
my ($appn, $appi); # Buffers to store matches in loop
sub presets;

#for (0 .. $#lines) {
for (@lines) {
	if ($state == 1 && /\t+application\.name\s=\s\"(.*)\"$/) {
		$apps{$1} = $appn;
		$appsinfo{$1} = $appi;
		$appn = $appi = undef;
		$state = 0;
		next;
	} elsif ($state == 1 && /^\t+sink:\s([0-9]+)\s/) {
		$appi = $1;
	} elsif (/^\s+index:\s([0-9]+)$/) {
		$appn = $1;
		$state = 1;
		# Should always be 19 lines ahead but we shouldn't count on that
		#$lines[$_+19] =~ s/\t+application\.name\s=\s\"(.*)\"$/$1/;
		#$apps{$lines[$_+19]} = $appn;
	}
}

given($ARGV[0]) {
	when (undef) {
		print "Default App: " . $presets{default} . "\nRunning Apps:\n";
		while ( my ($key, $value) = each %apps ) {
			print "$key => $value (on $appsinfo{$key})\n";
		}
		print "Sinks:\n" . `pacmd list-sinks | grep index`; # fuck doing it in perl
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
