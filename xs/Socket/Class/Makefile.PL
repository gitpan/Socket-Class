use 5.008;
use ExtUtils::MakeMaker;
use Config;

$Verbose = 0;

%_MAKEOPTS = (
    NAME => 'Socket::Class',
    VERSION_FROM => 'Class.pm', # finds $VERSION
    LIBS => [], # e.g., '-lm'
    DEFINE => '', # e.g., '-DHAVE_SOMETHING'
    INC => '-I../../../', # e.g., '-I. -I/usr/include/other'
    XSPROTOARG => '-noprototypes',
    PREREQ_PM => {
    },
    OBJECT => '$(O_FILES)',
    XS => { 'Class.xs' => 'Class.c' },
    C => ['socket_class.c', 'Class.c'],
    H => ['socket_class.h'],
);

if( $Config{'usethreads'} ) {
	$_MAKEOPTS{'DEFINE'} .= ' -DSC_THREADS';
}
if( $^O eq 'MSWin32' ) {
	$_MAKEOPTS{'DEFINE'} .= ' -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS -D_MT';
}
elsif( $^O eq 'cygwin' ) {
	push @{$_MAKEOPTS{'LIBS'}}, '-L/lib/w32api -lole32 -lversion -lws2_32';
}

if( $^O ne 'MSWin32' ) {
	@_IP = qw(/usr/local/include /usr/include);
	$r = find_header_item( \@_IP, 'netdb.h', 'freeaddrinfo' );
	if( ! $r ) {
		$_MAKEOPTS{'DEFINE'} .= ' -DSC_OLDNET';
	}
}

if( $^O eq 'linux' && 0 ) {
	unshift @{$_MAKEOPTS{'C'}}, 'sc_bluez.c';
	unshift @{$_MAKEOPTS{'H'}}, 'sc_bluez.h';
	push @{$_MAKEOPTS{'LIBS'}}, '-lbluetooth';
	$_MAKEOPTS{'DEFINE'} .= ' -DSC_USE_BLUEZ -DSC_HAS_BLUETOOTH';
	$_MAKEOPTS{'XS'}->{'Bluetooth.xs'} = 'Bluetooth.c';
	push @{$_MAKEOPTS{'C'}}, 'Bluetooth.c';
}
elsif( $^O eq 'MSWin32' && 0 ) {
	unshift @{$_MAKEOPTS{'C'}}, 'sc_ws2bth.c';
	unshift @{$_MAKEOPTS{'H'}}, 'sc_ws2bth.h';
	#push @{$_MAKEOPTS{'LIBS'}}, '-lbluetooth';
	$_MAKEOPTS{'DEFINE'} .= ' -DSC_USE_WS2BTH -DSC_HAS_BLUETOOTH';
	$_MAKEOPTS{'XS'}->{'Bluetooth.xs'} = 'Bluetooth.c';
	push @{$_MAKEOPTS{'C'}}, 'Bluetooth.c';
}

WriteMakefile( %_MAKEOPTS );

1;

sub find_header_item {
	my( $inc, $file, $item, $level, $reflist ) = @_;
	my( $fh, @ct, $p );
	$reflist ||= {};
	$reflist->{$file} = 1;
	$level ||= 0;
	$level or print "Looking for '$item' ... ";
	foreach $p( @$inc ) {
		$_ = $p . '/' . $file;
		-f or next;
		open $fh, '<' . $_;
		@ct = <$fh>;
		close $fh;
		foreach( @ct ) {
			if( m!^\#include\s+[\<\"]([\w\.\_\/\\]+?\.h\w*)[\"\>]! ) {
			#if( m!^\#include! ) {
				next if $reflist->{$1};
				#print "include $1\n";
				return 1 if find_header_item( $inc, $1, $item, $level + 1, $reflist );
			}
			if( index( $_, $item ) >= 0 ) {
				print "found\n";
				return 1;
			}
		}
	}
	$level or print "not found\n";
	return 0;
}
