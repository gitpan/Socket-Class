package Socket::Class::Const;

# uncomment for debugging
#use strict;
#use warnings;

our( $VERSION, $ExportLevel );

BEGIN {
	$VERSION = '2.02';
	require Socket::Class unless $Socket::Class::VERSION;
	require XSLoader;
	XSLoader::load( __PACKAGE__, $VERSION );
	$ExportLevel = 0;
}

no warnings 'redefine';
1; # return

sub import {
	my $pkg = shift;
	if( $_[0] eq '-compile' ) {
		shift @_;
		&export( $pkg, @_ );
	}
	else {
		my $pkg_export = caller( $ExportLevel );
		&export( $pkg_export, @_ );
	}
}

sub compile {
	my $pkg_export = caller( $ExportLevel );
	&export( $pkg_export, @_ );
}

__END__

=head1 NAME

Socket::Class::Const - Constants to L<Socket::Class|Socket::Class>

=head1 SYNOPSIS

  use Socket::Class qw(...);

=head1 DESCRIPTION

Socket::Class::Const contains socket related constants which can
be exported. Constants can be also exported as scalar variables.
The export tag I<:all> exports all constants.

=head1 CONSTANTS

=head2 Address Family types

=over 4

=item B<AF_INET>

Internet v4 address family

=item B<AF_INET6>

Internet v6 address family

=item B<AF_BLUETOOTH>

Bluetooth address family

=back

=head2 Protocol Family types

=over 4

=item B<PF_INET>

Internet protocol family. Same as AF_INET.

=item B<PF_INET6>

Internet v6 protocol family. Same as AF_INET6.

=item B<PF_BLUETOOTH>

Bluetooth protocol family. Same as AF_BLUETOOTH.

=back

=head2 Socket types

=over 4

=item B<SOCK_STREAM>

Connection oriented socket

=item B<SOCK_DGRAM>

Packet oriented socket

=back

=head2 IP (v4/v6) Protocols

=over 4

=item B<IPPROTO_ICMP>

The ICMP protocol

=item B<IPPROTO_TCP>

TCP protocol. Use together with SOCK_STREAM.

=item B<IPPROTO_UDP>

UDP protocol. Use together with SOCK_DGRAM.

=back

=head2 Bluetooth Protocols

=over 4

=item B<BTPROTO_RFCOMM>

Stream protocol. Use together with SOCK_STREAM.

=item B<BTPROTO_L2CAP>

Datagram protocol. Use together with SOCK_DGRAM.

=back

=head2 Listen queue

=over 4

=item B<SOMAXCONN>

=back

Listen queue max size.

=head2 Send, Recv Flags

=over 4

=item B<MSG_OOB>

Sends OOB data (stream-style socket such as SOCK_STREAM only).

=item B<MSG_PEEK>

Peeks at the incoming data. The data is copied into the buffer, but is not
removed from the input queue. 

=item B<MSG_DONTROUTE>

Specifies that the data should not be subject to routing.

=item B<MSG_CTRUNC>

Data completes record.

=item B<MSG_TRUNC>

Return the real length of the packet, even when it was longer then the
passed buffer. Only valid for packet sockets.

=item B<MSG_DONTWAIT>

Return even if it would normally have blocked.

=item B<MSG_WAITALL>

The receive request will complete only when one of the following events occurs:

=over

=item * The buffer supplied by the caller is completely full. 

=item * The connection has been closed. 

=item * The request has been canceled. 

=back

=back

=head2 Socket Option Levels

=over 4

=item B<SOL_SOCKET>

Socket option level

=item B<SOL_TCP>

TCP option level

=item B<SOL_UDP>

UDP option level

=back

=head2 Socket Options

=over 4

=item B<SO_ACCEPTCON>

Socket is listening.

=item B<SO_BROADCAST>

The default is FALSE. This option allows transmission of broadcast messages
on the socket. Valid only for protocols that support broadcasting
(IPX, UDP/IPv4, and others).

=item B<SO_DEBUG>

Get or set debugging mode.

=item B<SO_DONTROUTE>

The default is FALSE. This option indicates that routing is disabled, and
outgoing data should be sent on whatever interface the socket and bound to.
Valid for message oriented protocols only.

=item B<SO_ERROR>

The default is zero (0). This option returns and resets the per socket�based
error code.

=item B<SO_KEEPALIVE>

The default is FALSE. An application or the socket client can request that
a TCP/IP service provider enable the use of keep-alive packets on TCP
connections by turning on the SO_KEEPALIVE socket option.

=item B<SO_LINGER>

The default is 1 (ON). This option controls the action taken when unsent
data is queued on a socket and a L<close()|Socket::Class/close> or
L<free()|Socket::Class::free> is performed. 

=item B<SO_OOBINLINE>

The default is FALSE. This option indicates OOB data should be returned
in-line with regular data. Valid for connection oriented protocols which
support out-of-band data.

=item B<SO_RCVBUF>

This option specifies the total per-socket buffer space reserved for receives.

=item B<SO_RCVLOWAT>

Receives low watermark.

=item B<SO_RCVTIMEO>

Receives time-out in milliseconds.

=item B<SO_REUSEADDR>

The default is FALSE. Allows the socket to be bound to an address that is
already in use. 

=item B<SO_SNDBUF>

This option specifies the total per-socket buffer space reserved for sends.

=item B<SO_SNDLOWAT>

Sends low watermark.

=item B<SO_SNDTIMEO>

Sends time-out in milliseconds.

=item B<SO_TYPE>

Get the type of the socket. (Readonly)

=back

=head2 TCP Options

=over 4

=item B<TCP_NODELAY>

Disables the Nagle algorithm for send coalescing.

=back

=head2 Shutdown values

=over 4

=item B<SD_RECEIVE>

Disable receiving on the socket.

=item B<SD_SEND>

Disable sending on the socket.

=item B<SD_BOTH>

Disable both sending and receiving on the socket.

=back

=head2 Socket States

=over 4

=item B<SC_STATE_INIT>

Socket is created

=item B<SC_STATE_BOUND>

Sock is bound

=item B<SC_STATE_LISTEN>

Socket is listening

=item B<SC_STATE_CONNECTED>

Socket is connected

=item B<SC_STATE_CLOSED>

Socket is closed

=item B<SC_STATE_ERROR>

Socket got an error on last send oder receive

=back

=head2 Flags for getaddrinfo()

=over 4

=item B<AI_PASSIVE>

The socket address will be used in a call to the bind function.

=item B<AI_CANONNAME>

The canonical name is returned in the first I<canonname> member.

=item B<AI_NUMERICHOST>

The I<node> parameter passed to the getaddrinfo function must be a
numeric string.

=item B<AI_ADDRCONFIG>

B<Windows only!>

The getaddrinfo will resolve only if a global address is configured.
The IPv6 and IPv4 loopback address is not considered a valid global address.

=item B<AI_NUMERICSERV>

B<Posix only!>

Don't use name resolution.

=back

=head2 Flags for getnameinfo()

=over 4

=item B<NI_NUMERICHOST>

If set, then the numeric form of the hostname is returned. 
(When not set, this will still happen in case the node's name cannot be looked
up.)

=item B<NI_NUMERICSERV>

If set, then the service address is returned in numeric form, for example by
its port number.

=item B<NI_NOFQDN>

If set, return only the hostname part of the FQDN for local hosts.

=item B<NI_NAMEREQD>

If set, then a error is returned if the hostname cannot be looked up.

=item B<NI_DGRAM>

If set, then the service is datagram (UDP) based rather than stream (TCP)
based. This is required for the few ports (512-514) that have different
services for UDP and TCP.

=back

=head1 AUTHORS

Navalla org., Christian Mueller, L<http://www.navalla.org/>

=head1 COPYRIGHT

The Socket::Class::Const module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic
License, as specified in the Perl README file.

=cut
