#!/usr/bin/perl -Tw
use strict;
use IO::Socket;
use Net::hostent;

BEGIN { $ENV{PATH} = "/usr/bin:/bin" }
sub debug;
sub mkassoc;

# Service to use
my $domain = "https://dynamicdns.park-your-domain.com/update?";

# Determine Running Environment
my $TTY;
{ # Try to free this memory asap
	use POSIX qw(getpgrp tcgetpgrp);
	if(!open(TTY, "/dev/tty")) {
		$TTY = 0;
	} else {
		my $tpgrp = tcgetpgrp(fileno(*TTY));
		my $pgrp = getpgrp();
		$TTY = ($tpgrp == $pgrp) ? 1 : 0;
	}
}

my $eol = "\015\012";
my $remote = shift || "localhost";
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
