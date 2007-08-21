print "1..$_tests\n";

require Socket::Class;
_check( 1 );

import Socket::Class qw(:all);
_check( 1 );

BEGIN {
	$_tests = 2;
	$_pos = 1;
	unshift @INC, 'blib/lib', 'blib/arch';
}

1;

sub _check {
	my( $val ) = @_;
	print "" . ( $val ? "ok" : "fail" ) . " $_pos\n";
	$_pos ++;
}
