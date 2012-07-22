#!/usr/bin/perl
use strict;
use warnings;
use Socket;
use Carp;

# IPC Variables
my $EOL = "\015\012";
my $port = 6666;
my $proto = getprotobyname('tcp');
$port = $1 if $port =~ /(\d+)/; # untaint port number

# Personal Settings
my $micsrc = "alsa_input.usb-045e_Microsoft_LifeChat_LX-3000-00-default.analog-mono";
my $eventdir = $ENV{HOME}.'/Ubuntu\ One/Webcam';
my $activatelogdir = $ENV{HOME}."/.motion/logs";
my $fm = 3; # File multiplier, 3 files per event
my $ethresh = (7 * $fm); # Where 7 is the threshold of events before an alert
my @asec = (20, 35); # Grace period for Events outside of time windows (stop, start, respectively)

# Bits Variable uses same idea as *nix file perms
# Switchbit = 1
# Event Modulu = 2
# Manual oggenc subroutine = 4
# Can be expanded into octal (0000) where each place is separate bits (for later expansion)
my $bits = 0;
sub checkforFiles;
sub formatTime;
sub logmsg;
sub stateCheck;

$_ = `pactl stat`;
$\ = "\n";
$, = "\n";
unless (/^Default\sSource:\s$micsrc$/m) {
	warn "Attempting to set PA: Source Sink to $micsrc\n";
	system "pacmd set-default-source $micsrc > /dev/null 2>&1";
	$_ = `pactl stat`;
	die "Failed to set Input Source!" unless (/^Default\sSource:\s$micsrc$/m);
	$bits += 1;
}
my $amsg = ($ARGV[0]) ? join ' ', @ARGV : "Out.";
my $startTime = time;
my ($sec,$min,$hour,$mday,$mon,$year) = gmtime($startTime);
# Build our socket
print 'Building listening socket on TCP/6666...';
socket(Server, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "setsockopt: $!";
bind(Server, sockaddr_in($port, INADDR_ANY)) || die "bind: $!";
listen(Server, SOMAXCONN) || die "listen: $!";

print "Begin: $amsg";
logmsg "Server started on port $port";
my $paddr;

sleep 2.5; # Give some time to abort before locking
system 'xscreensaver-command','-lock';

system 'purple-remote',
			 'setstatus?status=away&message=' . $amsg . ' (@' . 
			 sprintf("%04d%02d%02dT%02d%02dZ"
				 			, $year + 1900
							, $mon + 1
							, $mday
							, $hour
							, $min
							) . ')';
sleep 5; # Give some time to get out of room
system 'mpc', '-q', 'pause';
#system 'killall', '-STOP', '-r', 'dyn-mpd' and warn "Couldn't Pause dyn-mpd";

system 'motion'; # this now daemonizes
sleep 2; # give time for motion to start
my $mpid = `cat /tmp/motion.pid`; # Too lazy to do this properly right now
$mpid = $1 if ($mpid =~ /(\d+)/); # untaint pid

# Subroutines
sub logmsg { print "$0 $$: @_ at " . scalar localtime }
sub checkforFiles {
	my @check = glob "$eventdir/*.raw";
	return 0 if(@check < 1);
	if($_[0] > 4) {
		print 'Reached 5 iterations of subroutine; Encoding raw files manually...';
		system 'oggenc', '-q 1', '-r', $_ for (@check);
		unlink $_ or die "Could not delete $_: $!\n" for (@check);
		$bits += 4; # Modify our event bits variable
		return 0;
	}
	print 'Found raw recordings. Waiting for oggenc to finish...';
	sleep 2;
	&checkforFiles($_[0] + 1);
}
sub formatTime {
	if($_[0] < 60) {
		return $_[0] . 's';
	} elsif(($_[0] > 60) && ($_[0] < 3600)) {
		return sprintf("%.3fm",($_[0]/60));
	} else {
		return sprintf("%.3fh",(($_[0]/60)/60));
	}
}

sub stateCheck {
	my $out;
	my $stopTime = time;
	while(glob $eventdir . '/*.ogg') {
			my $e;
			if(/\/([0-9]*)\.ogg/) {
				$e = $1;
			} else {
				next; # lol how did you get here?
			}
			my $ms = ($startTime + $asec[1]);
			my $minend = ($stopTime - $asec[0]);
			if( ($e > $ms) && ($e < $minend) ) {
				$out .= sprintf("**%i is outside time parameters: %s\n",$e,scalar localtime($e));
			}
		}
		return $out || "System State Normal\n";
}

# Create our cleanup subroutine, executing it on SIGINT
$SIG{INT} = sub {
	print 'SIGINT Detected, Ending System Surveillence...';
	if(!$mpid) {
		# We didn't read the pid file correctly. Attempt a scatter bomb
		system("killall motion");
		warn "Could not detect the PID file, please check ps for proper daemon termination.\n";
	} else {
		kill 2, $mpid;
	}
	my $stopTime = time;
	system 'purple-remote','setstatus?status=available&message=';
	#system 'killall', '-CONT', '-r', 'dyn-mpd' and warn "Couldn't resume dyn-mpd";
	system 'mpc', '-q', 'toggle';
	&checkforFiles(0); # Handle any stray .raw files

	# If an event modulu exists after above subroutine runs something is seriously wrong
	# This will be reflected in event bits with a value >= 6
	my @events = <$eventdir/*>;
	if ((@events % $fm) > 0) {
		print "Event modulo exists! Dumping Data...\nEvent Interpolation: @events";
		$bits += 2;
	}
	open LOG, ">>$activatelogdir/$mon.$year.log" or die "Cant open Logfile! ($!)";
	print LOG "$startTime,$amsg,$bits,".@events.",$stopTime";
	close LOG;
	print "System Surveillence Ended.\nEvent Bits: $bits\nTime Elapsed: " . &formatTime(($stopTime - $startTime)),
				"Events Recorded: ".(@events / $fm)."\nLog $activatelogdir/$mon.$year.log appended.";
	print &stateCheck;
	return 0 unless (@events > $ethresh);
	
	print "Threshold ($ethresh) reached. Would you like to review records now? [Y/n] ";
	chomp(my $response = <STDIN>);
	return 1 if ($response =~ /n/i);
	my @avis = glob $eventdir . '/*.avi';
	system 'mplayer', '-fixed-vo', '-really-quiet', @avis;
	
	print "\nCleanup Recordings? [y/N] ";
	$response = <STDIN>;
	chomp $response;
	return 0 unless ($response =~ /y/i);

	@avis = glob $eventdir . '/*';
	unlink $_ for (@avis);
};

print "Now handling client connections...\n";
# Listen for connections
for ( ; $paddr = accept(Client, Server); close Client) {
	my ($port, $iaddr) = sockaddr_in($paddr);
	my $name = gethostbyaddr($iaddr, AF_INET);

	logmsg "connection from $name [", inet_ntoa($iaddr), "] at port $port\n";

	print Client "System Surveillance is Active\n" . 
		"You are asking from : \t$name\n" . 
		"Time elapsed : \t" . &formatTime((time - $startTime)) . "\n" .
		"Event Bits : \t$bits\n" . 
		"Away Msg : $amsg\n" . 
		"Motion PID : $mpid\n" . 
		"My PID : $$\n" . 
		"State Check : \n" . &stateCheck .
		"Time of request : \t ", scalar localtime, $EOL;
}
