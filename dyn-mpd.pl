#!/usr/bin/perl
use strict;
use warnings;
#use POSIX ":sys_wait_h";
use Getopt::Euclid qw[ :minimal_keys ];
use Proc::Daemon;
use Encode;

# Infinite loop with daemon
# This method does not handle the playlist,
# only adds to it. Thus, consume mode is needed
my $pid = -1;

sub debug;
$SIG{CHLD} = sub {
	debug("Child reported for reapin! (pid var is $pid)");
	waitpid($pid || -1, 0);
};

Proc::Daemon::Init unless $ARGV{debug};

debug("Beginning Loop");
while (1) {
	# If we have a child process running, don't fork another, that is silly
	next if ($pid > 1 && kill 0 => $pid);
	my @playlist = split "\n", `mpc playlist`;
	debug("Playlist:\n@playlist");
	debug("Checking Playlist");
	# Once playlist gets below certain threshold, fork child for heavy lifting:
	$pid = fork if(@playlist < $ARGV{thresh});
	next if ($pid || $pid == -1);
	# Now we are the child
	debug("Child Forked!");
	my @library = split "\n", `mpc listall`;
	
	# Generate appropriate amount via rand @library
	my @new;
	PICK:
	while (@new < $ARGV{add}) {
		my $pick = encode('utf-8', $library[rand @library]);
		# Don't add entries that are already queued
		for (@playlist) {
			next PICK if($pick eq $_);
		}
		push @new, decode('utf-8', $pick);
	}
	
	# add to playlist
	$" = qw(\n);
	`echo "@new" | mpc add`;
	# End child, return to infinite loop
	exit;
} continue {
	debug("Sleeping for " . $ARGV{sleep});
	sleep $ARGV{sleep};
}

exit; # Lol wat you doin here?

sub debug {
    return unless $ARGV{debug};
    my ($msg) = @_;
    my ($s,$m,$h) = ( localtime(time) )[0,1,2,3,6];
    my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
    warn "$date $msg";
}

__END__

=head1 USAGE

    dyn-mpd [options]

=head1 DESCRIPTION

This program is a deviation of the dynamic playlist for MPD written by Tue
Abrahamsen <tue.abrahamsen@gmail.com>, et al. It was created because it's
author was frustrated with Audio::MPD's refusal to compile correctly on his
system and lack of a .deb for his outdated system. Additionally, this version
seeks to to be more minimal in it's resource needs and to provide added
functionality.

Note that this version requires the C++ MPD tools in the "MPC" package and
that this version does _not_ manage the playlist. Without consume mode enabled
in MPD this daemon will not interfere with your playlist as long as it is
above the defined threshold.

=head1 OPTIONS

=head2 General behaviour

Switchy dohickeys

=over 4

=item -d[ebug]

Run in debug mode. In particular, the program will not daemonize itself.
Default to false.

=item -t[hresh] <thresh>

Items to keep in playlist until appending new items. Somewhat equivalent to
Audio::MPD's -old functionality. Defaults to 10.

=for Euclid:
	thresh.type:		integer > 0
	thresh.default:	10

=item -a[dd] <add>

(Equivalent of Audio::MPD's -new)
Number of items to add per loop: Defaults to 10.

=for Euclid:
	add.type:			integer > 0
	add.default:	10

=item -s[leep] <sleep>

Time spent sleeping (in seconds) before checking playlist.
Default is 5 seconds.

=for Euclid:
	sleep.type:			number > 0
	sleep.default:	5

=cut
