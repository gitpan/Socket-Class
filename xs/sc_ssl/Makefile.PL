package Socket::Class::SSL::Install;
use 5.006;
use ExtUtils::MakeMaker;
use Config;

my( $openssldir );

$_DEBUG = $ENV{'SC_DEBUG'};

my @argv = ();
foreach my $p( @ARGV ) {
	$_ = lc( $p );
	if( /--debug/ ) {
		if( /--debug=(\d+)/ ) {
			$_DEBUG = $1;
		}
		else {
			$_DEBUG = 1;
		}
	}
	elsif( /--verbose/ ) {
		$Verbose = 1;
	}
	elsif( /--help/ ) {
		&print_usage();
	}
	elsif( /--openssl-dir=(.+)/ ) {
		$openssldir = $1;
	}
	else {
		push @argv, $p;
	}
}
@ARGV = @argv;

my %makeopts = (
	'NAME' => 'Socket::Class::SSL',
	'VERSION_FROM' => 'SSL.pm',
	'ABSTRACT' => 'SSL support for Socket::Class',
	'XSPROTOARG' => '-noprototypes',
	'LIBS' => [''],
	'DEFINE' => '',
	'INC' => '-I. -I../../',
	'OBJECT' => '$(O_FILES)',
	'XS' => {'SSL.xs' => 'SSL.c'},
	'C' => ['sc_ssl_mod_def.c', 'SSL.c'],
	'H' => ['sc_ssl_mod_def.h'],
);

if( $_DEBUG ) {
	print "Enable debug messages in Socket::Class::SSL level($_DEBUG)\n";
	$makeopts{'DEFINE'} .= ' -DSC_DEBUG=' . $_DEBUG;
	if( $^O eq 'linux' ) {
		$makeopts{'DEFINE'} .= ' -Wall';
	}
}

@search = qw{/usr/local /usr /opt};

if( $openssldir ) {
	#$makeopts{'INC'} .= " -I${openssldir}/include";
	#$makeopts{'LIBS'}[0] = "-L${openssldir}/lib";
	@search = ( $openssldir );
}
elsif( $^O eq 'solaris' ) {
	if( -d '/opt/csw/include/openssl' ) {
		push @search, '/opt/csw';
		#$makeopts{'INC'} .= " -I/opt/csw/include";
		#$makeopts{'LIBS'}[0] = "-L/opt/csw/lib";
	}
}

if( $^O eq 'MSWin32' ) {
	$makeopts{'DEFINE'} .= ' -D_CRT_SECURE_NO_DEPRECATE -D_CRT_SECURE_NO_WARNINGS';
	if( ! $openssldir ) {
		$makeopts{'INC'} .= ' -I./openssl/include';
		if( $Config{'archname'} =~ /x64/ ) {
			$makeopts{'LIBS'}[0] = '-Lopenssl/lib/win64';
		}
		else {
			$makeopts{'LIBS'}[0] = '-Lopenssl/lib/win32';
		}
	}
	$makeopts{'LIBS'}[0] .= ' -llibeay32 -lssleay32';
	# cpan bug #37639
	$ExtUtils::MM_Win32::Config{'ccversion'} = 13;
}
else {
	$found = 0;
	foreach( @search ) {
		if( -f "$_/include/openssl/ssl.h" ) {
			print "Found OpenSSL in $_\n";
			$makeopts{'INC'} .= " -I$_/include";
			if( -d "$_/lib64" ) {
				$makeopts{'LIBS'}[0] = "-L$_/lib64 -L$_/lib";
			}
			else {
				$makeopts{'LIBS'}[0] = "-L$_/lib";
			}
			$found = 1;
			last;
		}
	}
	unless( $found ) {
		print "OpenSSL not found\n";
		rename 't', '_t' if -d 't';
		WriteMakefile(
			'NAME' => 'Socket::Class::SSL',
			'VERSION_FROM' => 'SSL.pm',
			'XS' => {},
			'C' => [],
			'H' => [],
		);
		return;
	}
	if( $^O eq 'cygwin' ) {
		$makeopts{'LIBS'}[0] .= ' -L/lib/w32api -lole32 -lversion -lws2_32 -lssl -lcrypto';
	}
	else {
		$makeopts{'LIBS'}[0] .= ' -lssl -lcrypto';
	}
}

rename '_t', 't' if -d '_t';
WriteMakefile( %makeopts );

&build_cmodule( '../../mod_sc.h' );

1;

sub print_usage {
	print <<EOTH;

Usage: perl $0 [options]
Options:
    --help                 print this message
    --debug[=LEVEL]        compile with debug messages (level 0-2)
    --verbose              enable MakeMakers verbosity
    --openssl-dir=DIR      path to the OpenSSL Toolkit

EOTH
	exit 256;
}

sub build_cmodule {
	my( $path ) = @_;
	my( $fh, $step, $ct, $ct1, $ct2 );
	open $fh, "< mod_sc_ssl.inc.h";
	$ct = join( '', <$fh> );
	close $fh;
	open $fh, "< $path";
	$step = 0;
	foreach( <$fh> ) {
		if( $step == 0 ) {
			if( /\s*struct st_mod_sc {/ ) {
				$ct1 = index( $ct, '/* !include st_mod_sc */' );
				$ct2 = substr( $ct, $ct1 + 25 );
				$ct1 = substr( $ct, 0, $ct1 );
				$step = 1;
			}
		}
		elsif( $step == 1 ) {
			if( /^\s*};/ ) {
				$ct = $ct1 . $ct2;
				$step = 0;
			}
			else {
				$ct1 .= $_;
			}
		}
	}
	close $fh;
	#$path = $Config{'sitearch'} . '/auto/Socket/Class';
	#$path =~ s/\\/\//g;
	$ct =~ s!/\* \!include mod_sc\.h \*/!#include "../mod_sc.h"!;
	$path = $Config{'sitearch'} . '/auto/Socket/Class/SSL';
	$path =~ s/\\/\//g;
	$ct =~ s!/\* \!include default_pk \*/!#define SC_SSL_DEFAULT_KEY "$path/server.key"!;
	$ct =~ s!/\* \!include default_crt \*/!#define SC_SSL_DEFAULT_CRT "$path/server.crt"!;
	open $fh, "> mod_sc_ssl.h";
	print $fh $ct;
	close $fh;
}

package MY;

sub cflags {
    my $inherited = shift->SUPER::cflags( @_ );
    if( $^O eq 'MSWin32' ) {
	    $inherited =~ s/-O1/-O2/sg;
    	# set static linking to crt
	    $inherited =~ s/-MD/-MT/sg;
	}
    $inherited;
}

sub const_loadlibs {
    my $inherited = shift->SUPER::const_loadlibs( @_ );
    if( $^O eq 'MSWin32' ) {
    	# set static linking to crt
	    $inherited =~ s/msvcrt\.lib/libcmt\.lib/sgi;
	}
    $inherited;
}