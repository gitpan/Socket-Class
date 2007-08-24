package Socket::Class::Const;

# enable for debugging
#use strict;
#use warnings;

use vars qw($VERSION $WIN);

BEGIN {
	$VERSION = '1.0.0';
	$WIN = $^O eq 'MSWin32';
}

# address family types
our $AF_UNIX			= 1;
our $AF_INET			= 2;
our $AF_INET6			= $WIN ? 23 : 10;
our $AF_BLUETOOTH		= $WIN ? 32 : 31;

# protocol family types
our $PF_UNIX 			= $AF_UNIX;
our $PF_INET			= $AF_INET;
our $PF_INET6			= $AF_INET6;
our $PF_BLUETOOTH		= $AF_BLUETOOTH;

# socket types
our $SOCK_STREAM		= 1;
our $SOCK_DGRAM			= 2;

# ip protocols
our $IPPROTO_ICMP		= 1;
our $IPPROTO_TCP		= 6;
our $IPPROTO_UDP		= 17;

# bluetooth protocols
our $BTPROTO_RFCOMM		= 3;
our $BTPROTO_L2CAP		= $WIN ? 0x0100 : 0;

# listen queue size max
our $SOMAXCONN			= $WIN ? 0x7fffffff : 128;

# send, recv flags
our $MSG_OOB			= 0x01;
our $MSG_PEEK			= 0x02;
our $MSG_DONTROUTE		= 0x04;
our $MSG_CTRUNC			= $WIN ? 200  : 0x08;
our $MSG_TRUNC			= $WIN ? 100  : 0x20;
our $MSG_DONTWAIT		= $WIN ? 0    : 0x40;
our $MSG_WAITALL		= $WIN ? 0x08 : 0x100;

# socket options level
our $SOL_SOCKET			= $WIN ? 0xffff : 1;
our $SOL_TCP			= $IPPROTO_TCP;
our $SOL_UDP			= $IPPROTO_UDP;

# socket options
our $SO_DEBUG			= 1;
our $SO_REUSEADDR		= $WIN ? 0x0004 :  2;
our $SO_TYPE			= $WIN ? 0x1008 :  3;
our $SO_ERROR			= $WIN ? 0x1007 :  4;
our $SO_DONTROUTE		= $WIN ? 0x0010 :  5;
our $SO_BROADCAST		= $WIN ? 0x0020 :  6;
our $SO_SNDBUF			= $WIN ? 0x1001 :  7;
our $SO_RCVBUF			= $WIN ? 0x1002 :  8;
our $SO_KEEPALIVE		= $WIN ? 0x0008 :  9;
our $SO_OOBINLINE		= $WIN ? 0x0100 : 10;
our $SO_LINGER			= $WIN ? 0x0080 : 13;
our $SO_RCVLOWAT		= $WIN ? 0x1004 : 18;
our $SO_SNDLOWAT		= $WIN ? 0x1003 : 19;
our $SO_RCVTIMEO		= $WIN ? 0x1006 : 20;
our $SO_SNDTIMEO		= $WIN ? 0x1005 : 21;
our $SO_ACCEPTCON		= $WIN ? 0x0002 : 80;

# tcp options
our $TCP_NODELAY		= 1;

# shutdown values
our $SD_RECEIVE			= 0;
our $SD_SEND			= 1;
our $SD_BOTH			= 2;

# socket states
our $SOS_INIT			= 0;
our $SOS_BOUND			= 1;
our $SOS_LISTEN			= 2;
our $SOS_CONNECTED		= 3;
our $SOS_CLOSED			= 4;
our $SOS_ERROR			= 99;

our @EXPORT_OK = qw(
	$AF_UNIX $AF_INET $AF_INET6 $AF_BLUETOOTH
	$PF_UNIX $PF_INET $PF_INET6 $PF_BLUETOOTH
	$SOCK_STREAM $SOCK_DGRAM
	$IPPROTO_ICMP $IPPROTO_TCP $IPPROTO_UDP
	$BTPROTO_RFCOMM $BTPROTO_L2CAP
	$SOMAXCONN
	$MSG_OOB $MSG_PEEK $MSG_DONTROUTE $MSG_CTRUNC $MSG_TRUNC $MSG_DONTWAIT
	$MSG_WAITALL
	$SOL_SOCKET $SOL_TCP $SOL_UDP
	$SO_DEBUG $SO_TYPE $SO_ERROR $SO_DONTROUTE $SO_SNDBUF
	$SO_RCVBUF $SO_OOBINLINE $SO_BROADCAST $SO_KEEPALIVE $SO_LINGER
	$SO_RCVLOWAT $SO_SNDLOWAT $SO_RCVTIMEO $SO_SNDTIMEO $SO_ACCEPTCON
	$TCP_NODELAY
	$SD_RECEIVE $SD_SEND $SD_BOTH
	$SOS_INIT $SOS_BOUND $SOS_LISTEN $SOS_CONNECTED $SOS_CLOSED $SOS_ERROR
);

our %EXPORT_TAGS = (
	'all' => \@EXPORT_OK,
);

require Exporter;
*import = \&Exporter::import;

1;

__END__

=head1 NAME

Socket::Class::Const - Constants to L<Socket::Class|Socket::Class>

=head1 SYNOPSIS

  use Socket::Class qw(...);

=head1 DESCRIPTION

Socket::Class::Const contains socket related constants which can
be exported. For better performance constants are declared as scalar
variables.

=head1 VARIABLES

=head2 Address Family types

=over 4

=item $AF_INET

Internet v4 address family

=item $AF_INET6

Internet v6 address family

=item $AF_BLUETOOTH

Bluetooth address family

=back

=head2 Protocol Family types

=over 4

=item $PF_INET

Internet protocol family. Same as $AF_INET.

=item $PF_INET6

Internet v6 protocol family. Same as $AF_INET6.

=item $PF_BLUETOOTH

Bluetooth protocol family. Same as $AF_BLUETOOTH.

=back

=head2 Socket types

=over 4

=item $SOCK_STREAM

Connection oriented socket

=item $SOCK_DGRAM

Packet oriented socket

=back

=head2 IP (v4/v6) Protocols

=over 4

=item $IPPROTO_ICMP

The ICMP protocol

=item $IPPROTO_TCP

TCP protocol. Use together with $SOCK_STREAM.

=item $IPPROTO_UDP

UDP protocol. Use together with $SOCK_DGRAM.

=back

=head2 Bluetooth Protocols

=over 4

=item $BTPROTO_RFCOMM

Stream protocol. Use together with $SOCK_STREAM.

=item $BTPROTO_L2CAP

Datagram protocol. Use together with $SOCK_DGRAM.

=back

=head2 Listen queue

=over 4

=item $SOMAXCONN

=back

Listen queue max size.

=head2 Send, Recv Flags

=over 4

=item $MSG_OOB

Sends OOB data (stream-style socket such as SOCK_STREAM only).

=item $MSG_PEEK

Peeks at the incoming data. The data is copied into the buffer, but is not
removed from the input queue. 

=item $MSG_DONTROUTE

Specifies that the data should not be subject to routing.

=item $MSG_CTRUNC

Data completes record.

=item $MSG_TRUNC

Return the real length of the packet, even when it was longer then the
passed buffer. Only valid for packet sockets.

=item $MSG_DONTWAIT

Return even if it would normally have blocked.

=item $MSG_WAITALL

The receive request will complete only when one of the following events occurs:

  - The buffer supplied by the caller is completely full. 
  - The connection has been closed. 
  - The request has been canceled. 

=back

=head2 Socket Option Levels

=over 4

=item $SOL_SOCKET

Socket option level

=item $SOL_TCP

TCP option level

=item $SOL_UDP

UDP option level

=back

=head2 Socket Options

=over 4

=item $SO_ACCEPTCON

Socket is listening.

=item $SO_BROADCAST

The default is FALSE. This option allows transmission of broadcast messages
on the socket. Valid only for protocols that support broadcasting
(IPX, UDP/IPv4, and others).

=item $SO_DEBUG

Get or set debugging mode.

=item $SO_DONTROUTE

The default is FALSE. This option indicates that routing is disabled, and
outgoing data should be sent on whatever interface the socket and bound to.
Valid for message oriented protocols only.

=item $SO_ERROR

The default is zero (0). This option returns and resets the per socket–based
error code.

=item $SO_KEEPALIVE

The default is FALSE. An application or the socket client can request that
a TCP/IP service provider enable the use of keep-alive packets on TCP
connections by turning on the SO_KEEPALIVE socket option.

=item $SO_LINGER

The default is 1 (ON). This option controls the action taken when unsent
data is queued on a socket and a L<close()|Socket::Class/close> or
L<free()|Socket::Class::free> is performed. 

=item $SO_OOBINLINE

The default is FALSE. This option indicates OOB data should be returned
in-line with regular data. Valid for connection oriented protocols which
support out-of-band data.

=item $SO_RCVBUF

This option specifies the total per-socket buffer space reserved for receives.

=item $SO_RCVLOWAT

Receives low watermark.

=item $SO_RCVTIMEO

Receives time-out in milliseconds.

=item $SO_REUSEADDR

The default is FALSE. Allows the socket to be bound to an address that is
already in use. 

=item $SO_SNDBUF

This option specifies the total per-socket buffer space reserved for sends.

=item $SO_SNDLOWAT

Sends low watermark.

=item $SO_SNDTIMEO

Sends time-out in milliseconds.

=item $SO_TYPE

Get the type of the socket. (Readonly)

=back

=head2 TCP Options

=over 4

=item $TCP_NODELAY

Disables the Nagle algorithm for send coalescing.

=back

=head2 Shutdown values

=over 4

=item $SD_RECEIVE

Disable receiving on the socket.

=item $SD_SEND

Disable sending on the socket.

=item $SD_BOTH

Disable both sending and receiving on the socket.

=back

=head2 Socket States

=over 4

=item $SOS_INIT

Socket is created

=item $SOS_BOUND

Sock is bound

=item $SOS_LISTEN

Socket is listening

=item $SOS_CONNECTED

Socket is connected

=item $SOS_CLOSED

Socket is closed

=item $SOS_ERROR

Socket got an error on last send oder receive

=back

=head1 AUTHORS

Christian Mueller <christian_at_hbr1.com>

=head1 COPYRIGHT

The Socket::Class::Const module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic
License, as specified in the Perl README file.

=cut
