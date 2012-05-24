#!/usr/bin/perl
use strict;
use warnings;

# Gather Files
my @files = map {(split /_/)[0]} glob('*_1.wmv');
my $dir = (split /\//, $ENV{PWD})[-1];
my $i;

sub mkset;
sub tarball;
sub rmset;

print "Found " . @files . " sets in $dir.\nPress ENTER to begin reviewing. (Ctrl-C to Abort)";
my $pause = <STDIN>;

print "\nBeginning review of $dir\n";
sleep 1;
for(@files) {
	print "Now viewing set $_...\n";
	sleep 1;
	my $set = &mkset($_);
	`mplayer -fs -really-quiet $set`;
	$i++;
	ACTION: {
		print "$_ ($i/".@files.") Finished, Yea or Nay? [Y/n/d] ";
		chomp($pause = <STDIN>);
		if($pause =~ /[nN]/) {
			print "Tarring set...\n";
			&tarball($_);
		} elsif ($pause =~ /[dD]/) {
			print "Delete $_? Are you sure? [y/N]";
			chomp($pause = <STDIN>);
			redo ACTION if($pause !~ /[yY]/);
			print "Removing set...\n";
			&rmset($_);
		} else {
			print "Keeping set! Moving on:\n";
		}
	}
}

sub mkset {
	my $set = shift;
	my @files;
	push @files, $set . "_$_.wmv" for(1..6);
	return join ' ', @files;
}
sub tarball {
	my $Set = shift;
	my @set = split(/ /, &mkset($Set));
	# Check if tar already exists...
	my @args = ("$dir.tar", @set);
	if(-e $dir . '.tar') {
		print "Appending to existing tar...\n";
		unshift @args, '-rf';
	} else {
		print "Creating tar...\n";
		unshift @args, '-cf';
	}
	system 'tar', @args;
	if($? != 0) {
		warn "Could not tar $Set!\n";
	} else {
		unlink @set;
	}
}
sub rmset {
	my $set = shift;
	my @args = split(/ /, &mkset($set));
	#system 'rm', @args;
	unlink @args or warn "Could not unlink $set!\n";
}

print "Review Complete. Take this time to Abort execution if you would like to re-evaluate this set.\n";
$pause = <STDIN>;
if(-e "$dir.tar") {
	print "BZiping tar, you may now fork this process into background.\n";
	# Become bzip2
	exec 'bzip2', '-9', "$dir.tar";
} else {
	print "No tar found, ending execution.\n";
}
