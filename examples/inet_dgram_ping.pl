#!/usr/bin/perl

use threads;
use threads::shared;

use Time::HiRes;
use Socket::Class;

sub say { print @_, "\n"; }

our $RUNNING : shared = 1;

$server = Socket::Class->new(
	'proto' => 'udp',
	'local_addr' => '0.0.0.0',
	'local_port' => 0,
	'reuseaddr' => 1,
) or die Socket::Class->error;

threads->create( \&server_thread, $server );

$client = Socket::Class->new(
	'proto' => 'udp',
) or die Socket::Class->error;

$paddr = $client->pack_addr( '127.0.0.1', $server->local_port );

$pingcount = 0;
$pingtime = 0;

while( 1 ) {
	$r = $client->sendto( "PING " . microtime(), $paddr );
	if( ! defined $r ) {
		warn $client->error;
		last;
	}
	$r = $client->recv( $buf, 4096 );
	if( ! defined $r ) {
		warn $client->error;
		last;
	}
	elsif( ! $r ) {
		# got nothing
		$client->wait( 1 );
		next;
	}
	( $cmd, $arg ) = $buf =~ m/^(\w+)\s+(.*)/;
	if( $cmd eq 'RPING' ) {
		$pingcount ++;
		$pingtime += ( &microtime() - $arg );
	}
	if( ( $pingcount % 100 ) == 0 ) {
		$ac = $pingtime / $pingcount;
		$ac = sprintf( '%0.3f', $ac * 1000 );
		print "average ping time $ac ms\n";
	}
}

$server->wait( 9000 );

$RUNNING = 0;
foreach $thread( threads->list() ) {
	$thread->join();
}

sub server_thread {
	my( $sock ) = @_;
	my( $caddr, $buf, $r, $ra, $rp, $cmd, $arg );
	say "\nServer running at " . $sock->local_addr . ' port ' . $sock->local_port;
	$sock->set_blocking( 0 );
	while( $RUNNING ) {
		$caddr = $sock->recvfrom( $buf, 4096 );
		if( ! defined $caddr ) {
			warn $sock->error;
			last;
		}
		elsif( ! $caddr ) {
			$sock->wait( 1 );
			next;
		}
		( $ra, $rp ) = $sock->unpack_addr( $caddr );
		( $cmd, $arg ) = $buf =~ m/^(\w+)\s+(.*)/;
		if( $cmd eq 'PING' ) {
			$r = $sock->sendto( "RPING " . $arg, $caddr );
			if( ! defined $r ) {
				warn $sock->error;
				last;
			}
		}
	}
	$sock->free();
	print "\nclosing server thread\n";
}

sub microtime {
	my( $sec, $usec ) = &Time::HiRes::gettimeofday();
	return $sec + $usec / 1000000;
}
