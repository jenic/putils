putils
======

_Small perl utilities for various CLI tasks_

* activate

	Personal script used to automate a couple tasks
	that I do whenever leaving my computer.

* amarok-info

	Small perl script to parse the output of DBus calls
	to amarok. Used in Conky.

* avg

	Simple stat script I made to help learn perl

* ddns-proxy

	Forwards HTTP GET requests onto another website.
	Used in my RPi for DDNS updates since router
	doesn't have enough space to support full wget with
	https support and my RPi doesn't have direct access
	to link state information on my router.

* dyn-mpd

	This program is a deviation of the dynamic playlist
	for MPD written by Tue Abrahamsen, et al. It was
	created because its author was frustrated with
	Audio::MPD's refusal to compile correctly on his
	crappy outdated system. Additionally, this version
	has different design priorities, focusing on random
	playlist generation and foregoing the scoring
	system.

	Note that this version does _not_ manage the
	playlist. Without consume mode enabled in MPD this
	daemon will not interfere with your playlist as
	long as it is above the defined threshold.

* music-volume

	Use DBus to control AmaroK volume. Was in a key
	binding on Gnome.

* oggwrapper

	Nasty little perl script for converting raw music
	on cds into oggs. Uses GVFS.

* paswitch

	Pulse Audio Sink switcher for CLI. At the time I
	was frustrated with using the GUI tools and could
	not find an easy CLI one so I wrote this wrapper
	for pacmd.

* weaboo-crc

	Check the CRC value of my animes...
