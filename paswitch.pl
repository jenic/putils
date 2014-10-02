#!/usr/bin/perl
use strict;
# http://www.nntp.perl.org/group/perl.perl5.porters/2013/03/msg200559.html
no warnings "experimental::smartmatch";
use feature "switch";

my %presets = (
    default => 'Music Player Daemon',
    # Use this to add aliases
    aliases =>
        { plugin        => 'ALSA plug-in [plugin-container]'
        , oldmplayer    => 'MPlayer'
        , mplayer       => 'mplayer2'
        , mpd           => 'Music Player Daemon'
        },
    # Use this to easily add features
    lambdas =>
    # TODO: raw has no error checking. Goes all the way to pacmd before
    # user finds out given app id doesn't exist. For now I've decided to
    # leave it AS A FEATURE!
        { raw   =>  sub { return ($_[0] =~ /^i\d+/)
                            ? substr($_[0], 1)
                            : undef;
                        }
        , match =>  sub { my %m;
                    my %r = %{$_[1]};
                    for (keys %r) {
                        $m{$_}++ if (/$_[0]/i);
                    }
                    my @f = keys %m;
                    return (@f == 1) ? $r{$f[0]} : undef;
                }
        }
);

use constant _DEBUG => 0;

use constant _APPSFORMAT => <<EOF;
[%s]\t%s (Sink %s) Vol: %s%%
EOF

use constant _SINKSFORMAT => <<EOF;
[%s]\t%s
EOF

use constant _HELPTEXT => <<EOF;
Syntax: $0 [ <appname> [ <sink #> ] ] | [ <sink #> [ <appname> ] ]

Example: $0 MPlayer 0 [OR] $0 0 MPlayer
    This will change mplayer to sink #0 Note the case.

Example of default app: $0 1
    This will change default app to sink #1

Example of "Raw ID" feature: $0 i1194
    appname can be substituted for client ID found in client list
    (Feature available only if presets->{lambdas}->{raw} is defined)

Example of "match" feature: $0 plug
    Partial match of /plug/ against all running apps.
    (Feature available w/ presets->{lambdas}->{match})

When given appname first, will toggle between two sinks if exactly 2 sinks
exist.

----------
Null    List Clients/Sinks
N/A Show this help
EOF

# Forward Declarations
sub debug;
sub iterhash;
sub presets;

my (%apps, %buf);
my $state = 0;
my ($appn, $appi); # Buffers to store matches in loop

# Populate %apps with running applications
my @lines = `pacmd list-sink-inputs`;
for (@lines) {
    if ($state == 1 && /\t+application\.name\s=\s\"(.*)\"$/) {
        $apps{$1} = {};
        iterhash(\%buf, sub { $apps{$1}->{$_[0]} = $_[1] });
        $state = 0;
        %buf = ();
        next;
    } elsif ($state == 1 && /^\t+sink:\s([0-9]+)\s/) {
        $buf{sink} = $1;
    } elsif ($state == 1 && /^\t+volume: front-left: (\d+)\s/) {
        $buf{vol} = $1;
    } elsif (/^\s+index:\s([0-9]+)$/) {
        $buf{index} = $1;
        $state = 1;
    }
}

# Populate %sinks
# sink keys correspond to app index
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

# For Debug
if (_DEBUG || $ENV{DEBUG}) {
    for ( (\%apps, \%sinks) ) {
        &debug("$_ hash:");
        &iterhash($_);
    }
}

# Main
given($ARGV[0]) {
    when (undef) {
        print "Default App: $presets{default}\nRunning Apps:\n";
        &iterhash(\%apps, sub { printf  ( _APPSFORMAT
                        , $_[0]
                        , $_[1]->{index}
                        , $_[1]->{sink}
                        , (sprintf( "%.3f", ($_[1]->{vol}/65536)) * 100)
                        )}
        );

        print "Sinks:\n";
        &iterhash(\%sinks, sub { printf ( _SINKSFORMAT
                        , $_[0]
                        , $_[1]
                        )}
        );
    }
    when (/^[A-z]/) {
        my $app = &presets($ARGV[0]);
        my $sink;
        my @sinks = sort keys %sinks;

        &debug("[MAIN] presets() returns with $app");
        my $current;
        &iterhash(\%apps, sub {
                &debug("[MAIN] $app == $_[1] ($_[0]) ?");
                if($app == $_[1]->{index}) {
                    $current = $_[1]->{sink};
                    &debug("[MAIN] Found: $current");
                    last;
                }
        });

        unless (defined $current) {
            warn "$app could not be found! " .
            "Are you sure it's running?\n";
        }

        if( !$ARGV[1] && @sinks == 2 ) { # Toggle feature
            if(!defined $current) {
                $sink = 0;
                warn "Current sink of $app couldn't be found" .
                ", assuming 0", "\n";
            } else {
                for (@sinks) {
                    &debug("[TOGGLE] $_ = $current?");
                    if($_ != $current) {
                        $sink = $_;
                        last;
                    }
                }
            }
            &debug("[TOGGLE] $app: $current to $sink (@sinks)");
        } else {
            &debug("[TOGGLE] Only 1 sink found. Will not toggle.");
            $sink = $ARGV[1] || $sinks[0];
        }
        &debug("[MAIN] Params passed to pactl: $app $sink");
        system 'pactl', 'move-sink-input', $app, $sink;
        print _HELPTEXT if($? != 0);
    }
    when (/^[0-9]/) {
        my $app = &presets($ARGV[1] || undef);
        &debug("[MAIN] presets() returns with $app");
        system "pactl", "move-sink-input", $app, $ARGV[0];
        print _HELPTEXT if($? != 0);
    }
    default { print _HELPTEXT; }
}

sub debug {
    return unless _DEBUG || $ENV{DEBUG};
    my ($msg) = @_;
    my ($s,$m,$h) = ( localtime(time) )[0,1,2,3,6];
    my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
    warn "$date $msg", "\n";
}

sub iterhash {
    my %hash = %{ shift() };
    my $sub = shift || sub { &debug("$_[0] => $_[1]") };

    while ( my ($k, $v) = each %hash) {
        $sub->($k, $v);
    }
}

sub presets {
    &debug("Begin presets()");
    return $apps{ $presets{'default'} } if(!$_[0]);
    my $arg = shift;
    &debug("Got $arg");

    for(keys %{$presets{'aliases'}}) {
        if ($arg eq $_) {
            &debug("$arg == $_");
            &debug("aliases returns " .
                $apps{ $presets{'aliases'}->{$_} }
            );
            return $apps{ $presets{'aliases'}->{$_} };
        }
    }

    for(keys %{$presets{'lambdas'}}) {
        my $r = $presets{'lambdas'}->{$_}->($arg, \%apps);
        if ($r) {
            &debug("Lambda returns $r");
            return $r;
        }
    }

    return $apps{$arg} if (exists $apps{$arg});
    warn "$arg could not be found. Is it running?", "\n"
        if($arg !~ /\d+/);
    return $arg;
}
