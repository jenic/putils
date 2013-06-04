#!/usr/bin/perl
use strict;
# http://www.nntp.perl.org/group/perl.perl5.porters/2013/03/msg200559.html
no warnings "experimental::smartmatch";
use feature "switch";

my %presets = (
	default => 'Music Player Daemon',
	strings =>
		{ plugin	=> 'ALSA plug-in [plugin-container]'
		, oldmplayer	=> 'MPlayer'
		, mplayer	=> 'mplayer2'
		},
	lambdas =>
		{ raw	=>	sub { return ($_[0] =~ /^i\d+/) ? substr($_[0], 1) : undef; }
		, noop	=>	sub { return undef }
		}
);

use constant _DEBUG => 0;

use constant _APPSFORMAT => <<EOF;
[%s]\t%s (Sink %s)
EOF

use constant _SINKSFORMAT => <<EOF;
[%s]\t%s
EOF

use constant _HELPTEXT => <<EOF;
Syntax: $0 [ <appname> [ <sink #> ] ] | [ <sink #> [ <appname> ] ]

Example: $0 mplayer 0 [OR] $0 0 mplayer
	This will change mplayer to sink #0

Example 2: $0 1
	This will change default app to sink #1

Example 3: $0 i1194
	appname can be substituted for client ID found in client list
	(Feature available only if presets->{lambdas}->{raw} is defined)
	Will toggle between two sinks if exactly 2 sinks exist

----------
Null	List Clients/Sinks
N/A	Show this help
EOF

sub presets;
my (%apps, %appsinfo); # appsinfo.id = apps.id
my $state = 0;
my ($appn, $appi); # Buffers to store matches in loop

#for (0 .. $#lines) { # Old way
# Populate %apps and %appsinfo with running applications
my @lines = `pacmd list-sink-inputs`;
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

# Populate %sinks
@lines = `pacmd list-sinks | grep -A1 index`;
my %sinks;
$state = $appn = $appi = 0;
for (@lines) {
	if ($state == 1 && /^\s+name:\s\<(.*?)\>/) {
		$sinks{$appn} = $1;
		$sinks{$appn} .= ' (Default)' if ($appi);
		$state = 0;
		$appn = undef;
	} elsif (/^\s+(\*?)\s+index:\s(\d+)\s?$/) {
		$appn = $2;
		$appi = $1;
		$state = 1;
	}
}

# Main
given($ARGV[0]) {
	when (undef) {
		print "Default App: " . $presets{default} . "\nRunning Apps:\n";
		while ( my ($key, $value) = each %apps ) {
			printf	( _APPSFORMAT
				, $value
				, $key
				, $appsinfo{$key}
				);
		}

		print "Sinks:\n";
		while ( my ($key, $value) = each %sinks ) {
			printf	( _SINKSFORMAT
				, $key
				, $value
				);
		}
	}
	when (/^[A-z]/) {
		my $app = &presets($ARGV[0]);
		my $sink;
		my @sinks = sort keys %sinks;
		if( !$ARGV[1] && @sinks == 2 ) { # Toggle feature
			my $current;
			while ( my ($key, $value) = each %apps ) {
				&debug("$app == $value ($key) ?");
				if($app == $value) {
					$current = $appsinfo{$key};
					&debug("Found: $current");
					last;
				}
			}
			if(!defined $current) {
				$sink = 0;
				warn "Current is undef?!";
			} else {
				for (@sinks) {
					&debug("$_ = $current?");
					if($_ != $current) {
						$sink = $_;
						last;
					}
				}
			}
			&debug("$app: $current to $sink (@sinks)");
		} else {
			$sink = $ARGV[1] || 0;
		}
		system 'pactl', 'move-sink-input', $app, $sink;
		print _HELPTEXT if($? != 0);
	}
	when (/^[0-9]/) {
		my $app = &presets($ARGV[1] || undef);
		system "pactl", "move-sink-input", $app, $ARGV[0];
		print _HELPTEXT if($? != 0);
	}
	default { print _HELPTEXT; }
}

sub debug {
    return unless _DEBUG;
    my ($msg) = @_;
    my ($s,$m,$h) = ( localtime(time) )[0,1,2,3,6];
    my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
    warn "$date $msg", "\n";
}

sub presets {
	return $apps{ $presets{'default'} } if(!$_[0]);
	my $arg = shift;
	&debug("Got $arg");

	for(keys %{$presets{'strings'}}) {
		return $apps{ $presets{'strings'}->{$_} } if($arg eq $_);
	}

	for(keys %{$presets{'lambdas'}}) {
		my $r = $presets{'lambdas'}->{$_}->($arg);
		return $r if($r);
	}

	return $apps{$arg} if (exists $apps{$arg});
	warn "$arg could not be found. Is it running?", "\n"
		if($arg !~ /\d+/);
	return $arg;
}
