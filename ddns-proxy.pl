#!/usr/bin/perl -Tw
use strict;
use IO::Socket;
use Net::hostent;

BEGIN { $ENV{PATH} = "/usr/bin:/bin" }
sub debug;
sub mkassoc;

# Service to use
my $domain = "https://dynamicdns.park-your-domain.com/update?";
my $TTY;

sub daemonize {
	use POSIX;
	POSIX::setsid or die "Setsid: $!\n";
	my $pid = fork();
	if ($pid < 0) {
		die "Fork: $!\n";
	} elsif ($pid) {
		# Write child to pid file and then exit
		open FH, '>', "/tmp/ddns-proxy.pid" or die "parent: $!\n";
		print FH $pid;
		close FH;
		exit 0;
	}
	chdir "/";
	umask 0;
	POSIX::close $_
		foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024));
	open (STDIN, "</dev/null");
	open (STDOUT, ">/dev/null");
	open (STDERR, ">&STDOUT");
}

# Daemonize
if (@ARGV) { $TTY = 1; } else { &daemonize; }

my $eol = "\015\012";
my $port = shift || 6881;
die "No port specified" unless ($port =~ /^ \d+ $/x);

my $server = IO::Socket::INET->new( Proto	=> "tcp"
				  , LocalPort	=> $port
				  , Listen	=> SOMAXCONN
				  , Reuse	=> 1
				  );
die "Failed to build server" unless $server;
debug("[Server $0 accepting clients]");

while (my $client = $server->accept()) {
	$client->autoflush(1);
	while(<$client>) {
		next unless /\S/; # blank line
		debug("Client sends: $_");
		if(/^GET\s\/\?(.*?)\s/) {
			debug("URI Data: $1");
			my $r = `wget -q '$domain$1' -O -`;
			debug("Return ($?): $r");
			next if $?;
			use Encode;
			my $l = length(Encode::encode_utf8($r));
			debug("Content-Length: $l");
			print $client "HTTP/1.0 200 OK$eol";
			print $client "Content-Length: $l$eol";
			print $client $eol, $r, $eol;
			last;
		}
	}
	close $client;
}

sub debug {
	return unless $TTY;
	my ($msg) = @_;
	my ($s, $m, $h) = (localtime(time))[0,1,2,3,6];
	my $date = sprintf "%02d:%02d:%02d", $h, $m, $s;
	warn "$date\t$msg";
}
