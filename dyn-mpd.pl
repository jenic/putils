#!/usr/bin/perl
use strict;
use warnings;
#use POSIX ":sys_wait_h";
use Getopt::Euclid qw[ :minimal_keys ];
use IO::Socket::INET;
use Proc::Daemon;
use Encode;

# Infinite loop with daemon
# This method does not handle the playlist,
# only adds to it. Thus, consume mode is needed
my $pid = -1;
my $sock = 0;

sub mkSock;
sub mpd;
sub playlist;
sub listall;
sub add;
sub plen;
sub debug;
$SIG{CHLD} = sub {
	debug("Child reported for reapin! (pid var is $pid)");
	waitpid($pid || -1, 0);
};
END { $sock->close() if $sock; }

if($ARGV{debug}) {
	print "$_ => " . $ARGV{$_} . "\n" for(keys %ARGV);
} else {
	Proc::Daemon::Init;
}

debug("Beginning Loop");
while (1) {
	# If we have a child process running, don't fork another, that is silly
	next if ($pid > 1 && kill 0 => $pid);
	# Did our socket time out?
	$sock = &mkSock unless $sock;
	my $p = &plen;
	debug("Checking Playlist: $p");
	# Once playlist gets below certain threshold, fork child for heavy lifting:
	$pid = fork if($p < $ARGV{thresh});
	next if ($pid || $pid == -1);
	# Now we are the child
	debug("Child Forked! $pid");
	my @library = &listall;
	my @playlist = &playlist;
	
	# Generate appropriate amount via rand @library
	PICK:
	for (0..$ARGV{add}) {
		my $pick = encode('utf-8', $library[rand @library]);
		# Don't add entries that are already queued
		for (@playlist) {
			redo PICK if($pick eq $_);
		}
		# Add to playlist
		&add(decode('utf-8', $pick));
		debug("Added $pick");
	}
	
	# End child, return to infinite loop
	exit;
} continue {
	debug("Sleeping for " . $ARGV{sleep});
	sleep $ARGV{sleep};
}

exit; # Lol wat you doin here?

sub mkSock {
	my $sock = IO::Socket::INET->new
		( PeerAddr	=> $ARGV{host}
		, PeerPort	=> $ARGV{port}
		, Proto		=> 'tcp'
		, Timeout	=> ($ARGV{sleep} + 1)
		);
	die "Unable to connect to mpd: $!\n" unless $sock;
	debug("Socket Created!");
	my $ack = <$sock>;
	die "Not MPD? ($ack)\n" unless ($ack =~ /^OK MPD/);
	return $sock;
}
sub mpd {
	my $cmd	= shift;
	print $sock "$cmd\n";
	my $reply;
	while(<$sock>) {
		last if (/^OK$/);
		next if (/^directory:/);
		$reply .= $_;
	}
	return $reply || 1;
}
sub playlist {
	return (map { (split ':')[-1] } (split "\n", &mpd('playlist')));
}
sub listall {
	# How do we get regex to *return* string as shown with 'r' modifier :(
	return (map { (s/file:\s//) ? $_ : () } (split "\n", &mpd('listall')));
}
sub add {
	my $file = shift;
	my $add = &mpd('add "' . $file . '"');
	return $add;
}
sub plen {
	return	(split ': ', 
				( grep (/playlistlength:/,
					( split "\n", &mpd('status') ) )
				)[0]
			)[1];
}
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

=item -p[ort] <port>

Port MPD is listening on. Defaults to 6600.

=for Euclid:
	port.type:		integer > 0;
	port.default:	6600

=item -h[ost] <host>

Host to connect to. Default is localhost.

=for Euclid:
	host.type:		string
	host.default:	'localhost'

=cut
