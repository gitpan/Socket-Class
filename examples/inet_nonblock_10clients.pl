#!/usr/bin/perl

use threads;
use threads::shared;

use Time::HiRes;
use Socket::Class;

sub say { print @_, "\n"; }

our $RUNNING : shared = 1;

$server = Socket::Class->new(
	'local_addr' => '127.0.0.1',
	'listen' => 5,
	'blocking' => 0,
) or die Socket::Class->error;
threads->create( \&server_thread, $server );

our $client_count = 0;
our $client_ts = &microtime();

for $i( 1 .. 10 ) {
	$client = Socket::Class->new(
		'remote_addr' => '127.0.0.1',
		'remote_port' => $server->local_port,
		'blocking' => 0,
	) or die Socket::Class->error;

	threads->create( \&client_thread, $client );
	
	$client->write( "S" x 512 );
}

sleep( 20 );
$RUNNING = 0;
foreach $thread( threads->list() ) {
	$thread->join();
}

1;

sub server_thread {
	my( $sock ) = @_;
	my( $client, $buf );
	say "\nstarting server thread";
	say "\nServer running at " . $sock->local_addr . ' port ' . $sock->local_port;
	while( $RUNNING ) {
		if( $client = $sock->accept() ) {
			threads->create( \&response_thread, $client );
		}
		else {
			$sock->wait( 100 );
		}
	}
	say "\nclosing server thread";
	$sock->free();
}

sub response_thread {
	my( $sock ) = @_;
	my( $got, $buf, $trhd );
	$trhd = threads->self;
	say "\nstarting response thread";
	say "Incoming connection from " . $sock->remote_addr . ":" . $sock->remote_port;
	$sock->set_blocking( 0 );
	while( $RUNNING ) {
		$got = $sock->read( $buf, 4096 );
		if( ! defined $got ) {
			# error
			warn $sock->error;
			last;
		}
		elsif( $got == 0 ) {
			$trhd->yield;
			$sock->wait( 1 );
			next;
		}
		$sock->write( "C" x 512 );
	}
	say "\nclosing response thread\n";
	$sock->free();
	threads->self->detach() if $RUNNING;
	return 1;
}

sub client_thread {
	my( $sock ) = @_;
	my( $got, $buf, $trhd, $tid );
	say "\nstarting client thread";
	$client_ts = &microtime();
	$trhd = threads->self;
	$tid = $trhd->tid;
	while( $RUNNING ) {
		$got = $sock->read( $buf, 4096 );
		if( ! defined $got ) {
			# error
			warn $sock->error;
			last;
		}
		elsif( $got == 0 ) {
			$trhd->yield;
			$sock->wait( 1 );
			next;
		}
		$client_count ++;
		if( ($client_count % 100) == 0 ) {
			my $ac = sprintf( '%0.1f', $client_count / (&microtime() - $client_ts) );
			print "$tid got $client_count packets a $got bytes ($ac p/s)\n";
		}
		$sock->write( "S" x 512 );
	}
	say "\nclosing client thread";
	$sock->free();
	threads->self->detach() if $RUNNING;
	return 1;
}

sub microtime {
	my( $sec, $usec ) = &Time::HiRes::gettimeofday();
	return $sec + $usec / 1000000;
}
