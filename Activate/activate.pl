#!/usr/bin/perl
use strict;

my $micsrc = "alsa_input.usb-045e_Microsoft_LifeChat_LX-3000-00-default.analog-mono";
my $eventdir = $ENV{HOME}."/Ubuntu\\\ One/Webcam";
my $activatelogdir = $ENV{HOME}."/.motion/logs";

my $switchbit = 0;
$_ = `pactl stat`;
unless (/^Default\sSource:\s$micsrc$/m) {
	warn "Attempting to set PA: Source Sink to $micsrc\n";
	system "pacmd set-default-source $micsrc > /dev/null 2>&1";
	$_ = `pactl stat`;
	die "Failed to set Input Source!" unless (/^Default\sSource:\s$micsrc$/m);
	$switchbit = 1;
}
my $amsg = ($ARGV[0]) ? $ARGV[0] : "Out.";
my $startTime = time;
my ($sec,$min,$hour,$mday,$mon,$year) = gmtime($startTime);
system "dbus-send","--session","--dest=org.gnome.ScreenSaver","--type=method_call","/org/gnome/ScreenSaver","org.gnome.ScreenSaver.SetActive","boolean:true";
system "purple-remote","setstatus?status=away&message=$amsg (Camera Activated ".sprintf("%04d%02d%02dT%02d%02dZ",$year + 1900, $mon + 1, $mday, $hour, $min).")";
sleep 5;
system "qdbus","org.kde.amarok","/Player","org.freedesktop.MediaPlayer.Pause";
system "motion";
my $stopTime = time;
system "purple-remote","setstatus?status=available&message=";
system "qdbus","org.kde.amarok","/Player","org.freedesktop.MediaPlayer.Play";
my @events = <$eventdir/*>;
system "zenity","--error","--text=\"You have over 7 events that require review. Get off your fucking ass.\"" if (@events > 21);
open LOG, ">>$activatelogdir/$mon.$year.log" or die "Cant open Logfile! ($!)";
print LOG "\@$startTime--$amsg--$switchbit--".@events."--$stopTime\n";
close LOG;
print "System Surveillence Ended.\nTime Elapsed: ".(($stopTime - $startTime) / 60)."m\nEvents Recorded: ".@events."\nLog File Appended Successfully.\nTerminating...\n";
