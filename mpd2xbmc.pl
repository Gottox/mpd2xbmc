#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use IO::Socket::INET;

my $MPD_HOST = 'pi2';
my $MPD_PORT = '6600';

my $MPD_HTTP_OUTPUT = 'livingroom';
my $MPD_HTTP_PORT = '8001';

my $XBMC_HOST = 'pi1';
my $XBMC_PORT = '9090';

my $RUN = 1;

sub idle {
	my ($socket) = @_;
	my $data;

	print $socket "idle\n";

	while($data = <$socket>) {
		last if($data eq "OK\n");
	}
}
sub getOutputs {
	my ($socket) = @_;
	my ($data, $name, $enabled);

	print $socket "outputs\n";


	my $outputs = {};
	while($data = <$socket>) {
		last if($data eq "OK\n");

		$name = <$socket>;
		$enabled = <$socket>;
		$name =~ s/^outputname: (.*)\n/$1/;
		$enabled =~ s/^outputenabled: (.)\n/$1/;

		$$outputs{$name} = $enabled;
	}
	return $outputs;
}

sub getState {
	my ($socket) = @_;
	my ($data, $name, $enabled);

	print $socket "status\n";

	my $state;
	while($data = <$socket>) {
		last if($data eq "OK\n");

		if($data =~ m/^state: /) {
			$state = $data;
			$state =~ s/^state: (.*)\n/$1/;
		}
	}
	return $state;
}

sub handleHello {
	my ($socket) = @_;
	my $hello = <$socket>;

	$hello =~ m/^OK MPD .*$/ or die "ERROR unknown server Hello $hello";
}

sub activateXbmc {
	my $socket = new IO::Socket::INET->new(
		PeerHost => $XBMC_HOST,
		PeerPort => $XBMC_PORT,
		Proto => 'tcp',
	) or die "ERROR in Socket Creation : $!\n";

	$socket->autoflush(1);
	my $data;
	my $url = "http://$MPD_HOST:$MPD_HTTP_PORT/";

	print $socket '{"jsonrpc": "2.0", "method": "Player.Open", "params":{"item": {"file" : "' . $url .'" }}, "id" : "1"}';

	$socket->close();
}

sub mpdConnection {
	my $socket;
	my $data;
	my $lastState = 'stop';
	my $state;
	my $outputState;
	my $outputs;
	my $lastOutputState = 0;


	$socket = new IO::Socket::INET->new(
		PeerHost => $MPD_HOST,
		PeerPort => $MPD_PORT,
		Proto => 'tcp',
	) or die "ERROR in Socket Creation : $!\n";
	$socket->autoflush(1);

	handleHello($socket);
	

	while( $RUN ) {
		$outputs = getOutputs($socket);
		$outputState = $$outputs{$MPD_HTTP_OUTPUT};
		$state = getState($socket);
		print "Output: $outputState [$lastOutputState] State: $state [$lastState]\n";
		if($outputState == 1 &&
				$state eq "play" &&
				($lastOutputState != $outputState ||
				$lastState ne $state)) {
			print "Starting Stream\n";
			activateXbmc();
		}
		$lastOutputState = $outputState;
		$lastState = $state;
		idle($socket);
	}

	$socket->close();
	
}

mpdConnection();
