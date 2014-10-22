print "1..$_tests\n";

no warnings;

require Socket::Class;
import Socket::Class qw(:all);

#if( $Socket::Class::OLDNET ) {
#	_skip_all();
#	goto _end;
#}

$sock = Socket::Class->new(
	'domain' => 'inet6',
) or die Socket::Class->error;

if( ! $sock ) {
	_skip_all();
	goto _end;
}

_check( $sock );
$r = $sock->bind( '::1', 0 )
	or warn "Error: " . $sock->error;
if( ! $r ) {
	_skip_all();
	goto _end;
}
_check( $r );
$r = $sock->listen()
	or warn "Error: " . $sock->error;
_check( $r );
$r = $sock->close()
	or warn "Error: " . $sock->error;
_check( $r );
$r = $sock->set_timeout( 1000 );
_check( $r );
$r = $sock->free();
_check( $r );
$r = $sock->free();
_check( ! $r );


BEGIN {
	$_tests = 7;
	$_pos = 1;
	unshift @INC, 'blib/lib', 'blib/arch';
}

_end:

1;

sub _check {
	my( $val ) = @_;
	print "" . ( $val ? "ok" : "fail" ) . " $_pos\n";
	$_pos ++;
}

sub _skip_all {
	print STDERR "Skip: probably not supported on this platform\n";
	for( ; $_pos <= $_tests; $_pos ++ ) {
		print "ok $_pos\n";
	}
}

sub _fail_all {
	for( ; $_pos <= $_tests; $_pos ++ ) {
		print "fail $_pos\n";
	}
}
