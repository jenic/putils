#!/usr/bin/perl
use strict;
use warnings;
#use POSIX ":sys_wait_h";
use Getopt::Euclid qw[ :minimal_keys ];
use IO::Socket::INET;
use Proc::Daemon;

# Infinite loop with daemon
# This method does not handle the playlist,
# only adds to it. Thus, consume mode is needed
my $pid = -1;
my $sock = 0;
my %status;
my @blist;

sub mkSock;
sub mpd;
sub mkassoc;
sub playlist;
sub listall;
sub add;
sub nowPlaying;
sub debug;
sub upBlist;
sub isMatch;

$SIG{CHLD} = sub {
	debug("Child reported for reapin! (pid var is $pid)");
	waitpid($pid || -1, 0);
};
END { $sock->close() if $sock; }
my $_cmp = sub {
	my ($name, $stack) = @_;
	return (lc($name) cmp lc($stack));
};

if ($ARGV{debug}) {
	warn "$_ => " . $ARGV{$_}, "\n" for(keys %ARGV);
} else {
	Proc::Daemon::Init;
}

# Load Blacklist if it exists
my $blts = &upBlist if (-e $ARGV{blist});

debug("Beginning Loop");
while (1) {
	debug("New Loop: PID is $pid");
	# Did our socket time out or get closed by the child?
	$sock = &mkSock unless $sock;
	# Setup our status hash for this iteration
	%status = &mkassoc('status');
	if($ARGV{debug}) {
		debug("Dumping status hash:");
		warn "\t$_ -> " . $status{$_}, "\n" for (keys %status);
	}
	
	# 0 length playlist causes way too many problems
	die "Playlist length is 0" if !$status{playlistlength};

	# Don't bother if we aren't "Playing"
	next unless (defined $status{state} && $status{state} eq "play");

	# Unrelated to this script's primary purpose but for efficiency's sake
	# I am combining these two goals into a single process. This is for
	# xmobar:
	open FH, '>', '/tmp/mpd-playing' or die "I/O ERR: $!\n";
	print FH &nowPlaying;
	close FH;
	
	# If we have a child process running, don't fork another, that is
	# silly

	debug("$pid still running")
		and sleep 2
		and next
		if ($pid > 1 && kill 0 => $pid);

	# Once playlist gets below certain threshold, fork child for heavy
	# lifting:
	debug("Checking Playlist: " . $status{playlistlength});
	$pid = fork if ($status{playlistlength} < $ARGV{thresh});
	
	next if ($pid || $pid == -1);
	# Now we are the child
	debug("Child Forked!");
	use Encode;
	use Storable;
	my @library = &listall;
	# Binary search requires a sorted haystack
	my @playlist = sort { lc($a) cmp lc($b) } &playlist;
	my $pickref;

	# Check for History file and load it
	my @picks;
	if (-e $ARGV{Histfile}) {
		# TODO: Need a "try catch" here
		$pickref = retrieve($ARGV{Histfile});
		if(!$pickref) {
			@picks = ();
			debug("Failed to load History file! $!");
		} else {
			@picks = @$pickref;
			debug("History file loaded: " . @picks);
		}
	} else {
		@picks = ();
	}
	
	# Generate appropriate amount via rand @library
	PICK:
	for (0..$ARGV{add}) {
		my $id = sprintf "%i", rand @library;
		# Check history array for this ID
		if(&isMatch($id, \@picks, sub { return ($_[0] <=> $_[1]); })) {
			debug("[HIST] $id found in @picks, redoing");
			redo PICK;
		}

		my $pick = encode('utf-8', $library[$id]);

		# Consult the Blacklist
		for (@blist) {
			if ($pick =~ /$_/i) {
				debug("[BLACKLIST] $pick matched $_, redoing");
				redo PICK;
			}
		}
		# Don't add entries that are already queued. This somewhat
		# overlaps history feature except this also takes into
		# account songs added manually by the user
		if(&isMatch($pick, \@playlist)) {
			debug("[PL] $pick is a DUP, redoing pick");
			redo PICK;
		}
		
		# Add to playlist
		&add(decode('utf-8', $pick)) or redo PICK;
		# Append pick to playlist array so it is also checked since
		# random sometimes picks the same song twice
		$playlist[++$#playlist] = $pick;
		
		# Trials are over, add the worthy song to history and prune previous
		# entries if necessary
		debug("Added $pick");
		next unless ($ARGV{count} > 0);
		shift @picks if (@picks >= $ARGV{count});
		push @picks, $id;
	}
	
	# TODO: Figure out how history stored duplicate numbers
	# Sort our array before storing
	@picks = sort { $a <=> $b } @picks;
	# Save our history array to disk
	store(\@picks, $ARGV{Histfile}) if ($ARGV{count} > 0);

	# End child, return to infinite loop
	exit;
} continue {
	my $l = $status{playlistlength} || 0;
	my $s = $ARGV{sleep} + ((($l + 1)-$ARGV{thresh})*.5);
	$s = $ARGV{sleepmax} if ($s > $ARGV{sleepmax});
	debug("Sleeping for $s");
	sleep $s;
	
	# Update our blacklist if it has changed
	if (defined $blts) {
		my $nbl = (stat($ARGV{blist}))[9];
		if ($nbl > $blts) {
			debug("BList has changed! ($blts -> $nbl)");
			&upBlist;
			$blts = $nbl;
		}
	}
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
	my @reply;
	while(<$sock>) {
		return 0 if (/^ACK\s/);
		last if (/^OK$/);
		next if (/^directory:/);
		$reply[++$#reply] = $_;
	}
	chomp @reply;
	# If nothing to return, must return 1
	# or all hell breaks loose
	return (@reply > 1) ? @reply : pop @reply || 1;
}

# Makes hash (associative) of a &mpd command
sub mkassoc {
	my @cmd = &mpd(shift);
	return map { my @r = split /:\s/; lc($r[0]) => $r[1] // '' } @cmd;
}

# Specific subfunctions of &mpd
sub playlist {
	return (map { (split ':')[-1] } &mpd('playlist'));
}
sub listall {
	# How do we get regex to *return* string as shown with 'r' modifier :(
	return (map { (s/file:\s//) ? $_ : () } &mpd('listall'));
}
sub add {
	my $file = shift;
	my $add = &mpd('add "' . $file . '"');
	return $add;
}
sub nowPlaying {
	my %stats = &mkassoc('currentsong');
	return "<fc=red>No Playlist</fc>" unless defined $stats{time};
	my ($c, $t) = split ':', $status{time};
	my $percent = sprintf "%.0f", ( $c * 100 / $t );
	my $out;
	if ($stats{title}) {
		$out = "<fc=green>".$stats{title}."</fc>";
		$out .= " - <fc=yellow>".$stats{artist}."</fc>" if ($stats{artist});
	} else {
		$out = "<fc=red>".$stats{file}."</fc>";
	}
	$out .= " [<fc=blue>$percent%</fc>]";
	return $out;
}

# Other Subs
sub debug {
    return unless $ARGV{debug};
    my ($msg) = @_;
    my ($s,$m,$h) = ( localtime(time) )[0,1,2,3,6];
    my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
    warn "$date $msg", "\n";
}

sub upBlist {
	open FH, $ARGV{blist} or die "$!\n";
	@blist = <FH>;
	chomp @blist;
	close FH;
	my $blts = (stat($ARGV{blist}))[9];
	debug("Blacklist $blts Loaded: " . @blist);
	return $blts;
}

sub isMatch {
	my ($low, $mid, $high);
	my ($name, $ref, $opt) = @_;
	my @haystack = @$ref;
	$low = 0;
	$high = $#haystack;
	$opt = $_cmp if(!$opt);
	&debug("Binary search subroutine begins with needle $name");

	while ($low <= $high) {
		$mid = sprintf("%i", ($low + $high) / 2);
		# Why chomp the whole array when we wont even look at half of it?
		chomp $haystack[$mid];
		# Capitals fuck with shit
		my $cmp = $opt->($name, $haystack[$mid]);

		&debug("low = $low, high = $high, mid = $mid, cmp = $cmp, $haystack[$mid]");

		if($cmp < 0) {
			$high = $mid - 1;
		} elsif ($cmp > 0) {
			$low = $mid + 1;
		} else {
			&debug("-- Match --");
			return $mid; #Match
		}
	}
	&debug("-- No Match --");
	return 0; # No match

}

__END__

=head1 USAGE

dyn-mpd [options]

=head1 DESCRIPTION

This program is a deviation of the dynamic playlist for MPD written by Tue
Abrahamsen <tue.abrahamsen@gmail.com>, et al. It was created because its
author was frustrated with Audio::MPD's refusal to compile correctly on his
crappy outdated system. Additionally, this version has different design
priorities, focusing on random playlist generation and foregoing the scoring
system.

Note that this version does _not_ manage the playlist. Without consume mode
enabled in MPD this daemon will not interfere with your playlist as long as it
is above the defined threshold.

=head1 OPTIONS

=head2 General behaviour

Switchy dohickeys

=over

=item -d[ebug]

Run in debug mode. In particular, the program will not daemonize itself.
Default to false.

=item -t[hresh] <thresh>

Items to keep in playlist until appending new items. Somewhat equivalent to
Audio::MPD's -old functionality. Defaults to 10.

=for Euclid:
	thresh.type:	integer > 0
	thresh.default:	10

=item -a[dd] <add>

(Equivalent of Audio::MPD's -new)
Number of items to add per loop: Defaults to 10.

=for Euclid:
	add.type:	integer > 0
	add.default:	10

=item -s[leep] <sleep>

Base time spent sleeping (in seconds) before checking playlist. Actual sleep
time increases based on threshold and playlist length:
sleep + (((playlistLength + 1) - Threshold) * .5)
Default is 5 seconds.

=for Euclid:
	sleep.type:	number > 0
	sleep.default:	5

=item -sleepmax <sleepmax>

Maximum time daemon can sleep between loops.
Default is 30 seconds.

=for Euclid:
	sleepmax.type:		number > 0
	sleepmax.default:	30

=item -p[ort] <port>

Port MPD is listening on. Defaults to 6600.

=for Euclid:
	port.type:	integer > 0;
	port.default:	6600

=item -h[ost] <host>

Host to connect to. Default is localhost.

=for Euclid:
	host.type:	string
	host.default:	'localhost'

=item -H[istfile] <histfile>

Location of History file

=for Euclid:
	histfile.type:		writable
	histfile.default:	$ENV{HOME}.'/.mpd/dyn-hist'

=item -c[ount] <count>

Number of songs to remember in history

=for Euclid:
	count.type:	integer > -1
	count.default:	20

=item -b[list] <blist>

Location of Blacklist file

=for Euclid:
	blist.type:	readable
	blist.default:	$ENV{HOME}.'/.mpd/dyn-blacklst'

=back

=cut
