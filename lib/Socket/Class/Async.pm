package Socket::Class::Async;

use 5.008;

use Carp();
use Socket::Class ($SOS_LISTEN $SOS_CONNECTED);

use threads;
use threads::shared;

use strict;
no strict 'refs';
use warnings;
use bytes;

use vars qw($VERSION @ISA);

BEGIN {
	$VERSION = '1.0';
	@ISA = qw(Socket::Class);
}

our $SA_ON_ACCEPT		= 0;
our $SA_ON_READ			= 1;
our $SA_ON_CLOSE		= 2;
our $SA_ON_START		= 3;
our $SA_ON_ERROR		= 4;
our $SA_ON_STOP			= 5;
our $SA_SLEEPER			= 6;
our $SA_POINTER			= 7;

our $SSA_THREADID		= 0;
our $SSA_STATE			= 1;
our $SSA_SERVER			= 2;

# socket non shared 
our %SA = ();
# socket shared
our %SSA : shared = ();
# thread shared
our %TSA : shared = ();

END {
	my( $thread, $tid, $ssa, $nf );
	foreach $thread( threads->list() ) {
		$tid = $thread->tid();
		#print "waiting of thread $tid\n";
		$ssa = $TSA{$tid};
		if( $ssa ) {
			$ssa->[$SSA_STATE] = 0;
			$thread->join();
		}
		else {
			$thread->detach();
			$nf ++;
		}
	}
	if( $nf ) {
		&Socket::Class::wait( undef, 100 );
	}
}

sub DESTROY {
	my $sock = shift or return;
	$sock->SUPER::DESTROY();
	return if ! ( caller(0) )[8];
}

sub new {
	my( $class, %arg ) = @_;
	my $sock = $class->SUPER::new( %arg ) or return undef;
	my $this = [];
	$this->[$SA_ON_ACCEPT] = $arg{'on_accept'};
	$this->[$SA_ON_READ] = $arg{'on_read'};
	$this->[$SA_ON_CLOSE] = $arg{'on_close'};
	$this->[$SA_ON_START] = $arg{'on_start'};
	$this->[$SA_ON_STOP] = $arg{'on_stop'};
	$this->[$SA_ON_ERROR] = $arg{'on_error'};
	$this->[$SA_POINTER] = $arg{'pointer'};
	$this->[$SA_SLEEPER] = $arg{'sleep_fnc'};
	$SA{$$sock} = $this;
	return $sock;
}

sub start {
	# starting thread
	@_ == 1 or &Carp::croak( '$socket->start()' );
	my $sock = $_[0];
	my $ssa = $SSA{$$sock} = &share( [] );
	if( $sock->state == $SOS_LISTEN ) {
		$sock->set_blocking( 0 );
		my $t = threads->create( \&_server_thread, $sock );
		my $tid = $t->tid();
		$ssa->[$SSA_THREADID] = $tid;
		$ssa->[$SSA_STATE] = 1;
		$ssa->[$SSA_SERVER] = $$sock;
		$TSA{$tid} = $ssa;
	}
	elsif( $sock->state == $SOS_CONNECTED ) {
		$sock->set_blocking( 0 );
		my $t = threads->create( \&_client_thread, $sock );
		my $tid = $t->tid();
		$ssa->[$SSA_THREADID] = $tid;
		$ssa->[$SSA_STATE] = 1;
		$ssa->[$SSA_SERVER] = 0;
		$TSA{$tid} = $ssa;
	}
}

sub pause {
	@_ == 1 or &Carp::croak( '$socket->pause()' );
	my $sock = $_[0];
	my $ssa = $SSA{$$sock} or return 0;
	my $tid = $ssa->[$SSA_THREADID];
	$ssa->[$SSA_STATE] = 2;
	return 1;
}

sub resume {
	@_ == 1 or &Carp::croak( '$socket->resume()' );
	my $sock = $_[0];
	my $ssa = $SSA{$$sock} or return;
	my $tid = $ssa->[$SSA_THREADID];
	$ssa->[$SSA_STATE] = 1;
	return 1;
}

sub stop {
	# stopping thread
	@_ >= 1 && @_ <= 2 or &Carp::croak( '$socket->stop()' );
	my( $sock ) = @_;
	my( $ssa, $r, $tid, $t );
	$ssa = $SSA{$$sock} or return 0;
	$tid = $ssa->[$SSA_THREADID] or return 0;
	$ssa->[$SSA_STATE] or return 0;
	$ssa->[$SSA_STATE] = 0;
	$t = threads->object( $tid );
	if( $t ) {
		$tid != threads->self->tid ? $t->join() : $t->detach();
	}
	return 1;
}

sub free {
	@_ == 1 or &Carp::croak( '$socket->free()' );
	my( $sock ) = @_;
	my( $sa, $ssa, $t );
	$sa = $SA{$$sock};
	$ssa = $SSA{$$sock} or return $sock->SUPER::free();
	if( $sa->[$SA_ON_CLOSE] && $sock->fileno() ) {
		$sa->[$SA_ON_CLOSE]->( $sock, $ssa->[$SSA_SERVER] == $$sock, $sa->[$SA_POINTER] );
	}
	$sock->stop() if $ssa->[$SSA_STATE];
	return $sock->SUPER::free();
}

sub free_all {
	@_ == 1 or &Carp::croak( '$socket->free_all()' );
	my( $sock ) = @_;
	my( $k, $ssa, $sid, $t );
	$sid = $$sock;
	$sock->free();
	while( ( $k, $ssa ) = each %SSA ) {
		if( $k != $sid && $ssa->[$SSA_SERVER] == $sid ) {
			$t = threads->object( $ssa->[$SSA_THREADID] );
			if( $t ) {
				$ssa->[$SSA_STATE] = 99;
				$t->join();
			}
			else {
				$ssa->[$SSA_STATE] = 88;
			}
		}
	}
}

sub close {
	@_ == 1 or &Carp::croak( '$socket->close()' );
	my( $sock ) = @_;
	my( $sa, $ssa, $t );
	$sa = $SA{$$sock};
	$ssa = $SSA{$$sock} or return $sock->SUPER::close();
	if( $sa->[$SA_ON_CLOSE] && $sock->fileno() ) {
		$sa->[$SA_ON_CLOSE]->( $sock, $ssa->[$SSA_SERVER] == $$sock, $sa->[$SA_POINTER] );
	}
	$sock->stop() if $ssa->[$SSA_STATE];
	return $sock->SUPER::close();
}

sub _server_thread {
	my( $sock, $sa, $ssa, $client, $ct, $oac, $cssa, $r, $sleep, $ctid,
		$thrd, $slp, $ptr );
	$sock = $_[0];
	$sa = $SA{$$sock};
	$ssa = $SSA{$$sock};
	$thrd = threads->self;
	while( ! defined $ssa->[$SSA_STATE] ) {
		$sock->wait( 1 );
	}
	if( $sa->[$SA_ON_START] ) {
		$sa->[$SA_ON_START]->( $sock, 1, $sa->[$SA_POINTER] );
	}
	$oac = $sa->[$SA_ON_ACCEPT];
	$slp = $sa->[$SA_SLEEPER] || \&sleep_default;
	$ptr = $sa->[$SA_POINTER];
	while( 1 ) {
		if( $ssa->[$SSA_STATE] == 2 ) {
			$thrd->yield;
			$sock->wait( 50 );
		}
		elsif( $ssa->[$SSA_STATE] != 1 ) {
			last;
		}
		$client = $sock->accept();
		if( ! defined $client ) {
			# error
			$ssa->[$SSA_STATE] = 0;
			if( $sa->[$SA_ON_ERROR] ) {
				$sa->[$SA_ON_ERROR]->( $sock, 1, $ptr );
			}
			$thrd->detach();
			last;
		}
		elsif( ! $client ) {
			$thrd->yield;
			&$slp();
			next;
		}
		$r = $oac ? $oac->( $sock, $client ) : 1;
		if( ! $r ) {
			$client->SUPER::free();
			next;
		}
		$SA{$$client} = $sa;
		$SSA{$$client} = $cssa = &share( [] );
		$client->set_blocking( 0 );
		$ct = threads->create( \&_client_thread, $client );
		$ctid = $ct->tid();
		$cssa->[$SSA_THREADID] = $ctid;
		$cssa->[$SSA_STATE] = 1;
		$cssa->[$SSA_SERVER] = $$sock;
		$TSA{$ctid} = $cssa;
	}
	$slp = $ssa->[$SSA_STATE];
	$ssa->[$SSA_STATE] = 0;
	if( $sa->[$SA_ON_STOP] && $sock->fileno() ) {
		$sa->[$SA_ON_STOP]->( $sock, 1, $ptr );
	}
	{
		lock( %SSA );
		delete $TSA{$thrd->tid};
		delete $SSA{$$sock};
	}
	return 1;
}

sub _client_thread {
	my( $sock, $sa, $ssa, $tid, $got, $buf, $data, $dread, $sleep, $thrd, $ord,
		$slp, $ptr );
	$sock = $_[0];
	$sa = $SA{$$sock};
	$ssa = $SSA{$$sock};
	$thrd = threads->self;
	$tid = $thrd->tid;
	while( ! defined $ssa->[$SSA_STATE] ) {
		$sock->wait( 1 );
	}
	if( $sa->[$SA_ON_START] ) {
		$sa->[$SA_ON_START]->( $sock, 0, $sa->[$SA_POINTER] );
	}
	$data = '';
	$dread = 0;
	$ord = $sa->[$SA_ON_READ];
	$slp = $sa->[$SA_SLEEPER] || \&sleep_default;
	$ptr = $sa->[$SA_POINTER];
	while( 1 ) {
		if( $ssa->[$SSA_STATE] == 2 ) {
			$thrd->yield;
			$sock->wait( 50 );
		}
		elsif( $ssa->[$SSA_STATE] != 1 ) {
			last;
		}
		$got = $sock->recv( $buf, 4096 );
		if( ! defined $got ) {
			# error
			$ssa->[$SSA_STATE] = 0;
			if( $sa->[$SA_ON_ERROR] ) {
				$sa->[$SA_ON_ERROR]->( $sock, 0, $ptr );
			}
			$thrd->detach();
			last;
		}
		elsif( ! $got ) {
			if( $data ) {
				if( $ord ) {
					$ssa->[$SSA_STATE] = 0;
					$ord->( $sock, $data, $dread, $ptr )
						or last;
					$ssa->[$SSA_STATE] ||= 1;
				}
				$data = '';
				$dread = 0;
			}
		}
		else {
			$dread += $got;
			$data .= $buf;
			next;
		}
		$thrd->yield;
		&$slp();
	}
	$slp = $ssa->[$SSA_STATE];
	$ssa->[$SSA_STATE] = 0;
	if( $sa->[$SA_ON_STOP] && $sock->fileno() ) {
		$sa->[$SA_ON_STOP]->( $sock, 0, $ptr );
	}
	if( $slp == 1 ) {
		$thrd->detach();
	}
	elsif( $slp >= 88 ) {
		if( $sa->[$SA_ON_CLOSE] && $sock->fileno() ) {
			$sa->[$SA_ON_CLOSE]->( $sock, 0, $ptr );
		}
		$sock->SUPER::free();
		$slp != 88 or $thrd->detach();
	}
	{
		lock( %SSA );
		delete $TSA{$thrd->tid};
		delete $SSA{$$sock};
	}
	return 1;
}

sub sleep_default {
	&Socket::Class::wait( undef, 1 );
}

1;

__END__

=head1 NAME

Socket::Class::Async - Asynchronous socket operations

=head1 SYNOPSIS

  use Socket::Class::Async;

=head1 DESCRIPTION

Socket::Class::Async provides asynchronous socket operations.

This Module is experimental and may change in future.

=head1 AUTHORS

Christian Mueller <christian_at_hbr1.com>

=head1 COPYRIGHT

The Socket::Class::Async module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic
License, as specified in the Perl README file.

=cut
