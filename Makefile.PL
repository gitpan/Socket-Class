use 5.008;
use ExtUtils::MakeMaker;

my %os_supported = ( 'linux' => 1, 'MSWin32' => 1, 'darwin' => 1, 'cygwin' => 1 );

if( ! $os_supported{$^O} ) {
print <<EOF1;
************* WARNING *************
* Your operation system has not   *
* been tested.                    *
* The installation may fail!      *
***********************************
EOF1
}

WriteMakefile(
    NAME => 'Socket::Class',
    VERSION_FROM => 'xs/Socket/Class/Class.pm',
    ABSTRACT => 'Socket class',
    PREREQ_PM => {
        'Time::HiRes' => 0,
    },
    XSPROTOARG => '-prototypes',
    OPTIMIZE => '-O3',
	OBJECT => '',
	XS => {},
	C => [],
	H => [],
    DIR => [ 'xs' ],
);

1;
