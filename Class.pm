package Socket::Class;
# =============================================================================
# Socket::Class - A class to communicate with sockets
# Use "perldoc Socket::Class" for documenation
# =============================================================================
use Carp ();

# enable for debugging
#use strict;
#use warnings;
#no warnings 'uninitialized';

use vars qw($VERSION);

BEGIN {
	$VERSION = '1.0.5';
	require XSLoader;
	XSLoader::load( __PACKAGE__, $VERSION );
	*say = \&writeline;
	*sleep = \&wait;
	*fileno = \&handle;
}

END {
	&_cleanup();
}

sub import {
	my $pkg = shift;
	my $callpkg = caller;
	@_ or return;
	require Socket::Class::Const if ! $Socket::Class::Const::VERSION;
	&Exporter::export( 'Socket::Class::Const', $callpkg, @_ );
}

sub printf {
	@_ >= 2
		or &Carp::croak( 'Usage: ' . __PACKAGE__ . '::printf(this,fmt,...)' );
	my( $sock, $fmt ) = ( shift, shift );
	return &write( $sock, sprintf( $fmt, @_ ) );
}

sub reconnect {
	@_ >= 1 && @_ <= 2
		or &Carp::croak( 'Usage: ' . __PACKAGE__ . '::reconnect(this,wait=0)' );
	&close( $_[0] ) or return undef;
	&wait( $_[0], $_[1] ) if $_[1];
	&connect( $_[0] ) or return undef;
	return 1;
}

1;

__END__

=head1 NAME

Socket::Class - A class to communicate with sockets


=head1 SYNOPSIS

  use Socket::Class;

=head1 DESCRIPTION

Socket::Class provides a simple, fast and efficient way to communicate with
sockets.
It operates outside of the PerlIO layer and can be used as a replacement
of IO::Socket.
Little parts of Bluetooth technology has been integrated. Please see below.

=head2 Bluetooth

The standard build includes Bluetooth protocols for RFCOMM (stream) and
L2CAP (datagram). Bluetooth adapters on a MS-Windows operation system must be
compatible with the Windows Bluetooth API to get it working.
More specific Bluetooth support could be added in the future.

=head2 Functions by Category

B<Main Functions>

=over 4

=item

L<accept|Socket::Class/accept>,
L<bind|Socket::Class/bind>,
L<close|Socket::Class/close>,
L<connect|Socket::Class/connect>,
L<free|Socket::Class/free>,
L<new|Socket::Class/new>,
L<listen|Socket::Class/listen>,
L<reconnect|Socket::Class/reconnect>,
L<shutdown|Socket::Class/shutdown>

=back

B<Sending and Receiving>

=over 4

=item

L<print|Socket::Class/print>,
L<printf|Socket::Class/printf>,
L<read|Socket::Class/read>,
L<readline|Socket::Class/readline>,
L<recv|Socket::Class/recv>,
L<recvfrom|Socket::Class/recvfrom>,
L<say|Socket::Class/say>,
L<send|Socket::Class/send>,
L<sendto|Socket::Class/sendto>,
L<write|Socket::Class/write>,
L<writeline|Socket::Class/writeline>

=back

B<Address Functions>

=over 4

=item

L<get_hostname|Socket::Class/get_hostname>,
L<local_addr|Socket::Class/local_addr>,
L<local_path|Socket::Class/local_path>,
L<local_port|Socket::Class/local_port>,
L<pack_addr|Socket::Class/pack_addr>,
L<remote_addr|Socket::Class/remote_addr>,
L<remote_path|Socket::Class/remote_path>,
L<remote_port|Socket::Class/remote_port>,
L<unpack_addr|Socket::Class/unpack_addr>

=back

B<Socket Options>

=over 4

=item

L<get_blocking|Socket::Class/get_blocking>,
L<get_broadcast|Socket::Class/get_broadcast>,
L<get_option|Socket::Class/get_option>,
L<get_rcvbuf_size|Socket::Class/get_rcvbuf_size>,
L<get_reuseaddr|Socket::Class/get_reuseaddr>,
L<get_sndbuf_size|Socket::Class/get_sndbuf_size>,
L<get_timeout|Socket::Class/get_so_timeout>,
L<get_tcp_nodelay|Socket::Class/get_tcp_nodelay>,
L<set_blocking|Socket::Class/set_blocking>,
L<set_broadcast|Socket::Class/set_broadcast>,
L<set_option|Socket::Class/set_option>,
L<set_rcvbuf_size|Socket::Class/set_rcvbuf_size>,
L<set_reuseaddr|Socket::Class/set_reuseaddr>,
L<set_sndbuf_size|Socket::Class/set_sndbuf_size>,
L<set_timeout|Socket::Class/set_so_timeout>,
L<set_tcp_nodelay|Socket::Class/set_tcp_nodelay>

=back

B<Miscellaneous Functions>

=over 4

=item

L<fileno|Socket::Class/fileno>,
L<handle|Socket::Class/handle>,
L<is_readable|Socket::Class/is_readable>,
L<is_writable|Socket::Class/is_writable>,
L<select|Socket::Class/select>,
L<state|Socket::Class/state>,
L<to_string|Socket::Class/to_string>,
L<wait|Socket::Class/wait>

=back

B<Error Handling>

=over 4

=item

L<errno|Socket::Class/errno>,
L<error|Socket::Class/error>,
L<is_error|Socket::Class/is_error>

=back

=head1 EXAMPLES

=head2 Simple Internet Server

  use Socket::Class qw($SO_MAXCONN);
  
  # create a new socket at port 9999 and listen for clients 
  $server = Socket::Class->new(
       'local_port' => 9999,
       'listen' => $SO_MAXCONN,
  ) or die Socket::Class->error;
  
  # wait for clients
  while( $client = $server->accept() ) {
      # somebody connected to us (we are local, client's address is remote)
      print 'Incoming connection from '
          . $client->remote_addr . ' port ' . $client->remote_port . "\n";
      # do something with the client
      $client->say( 'hello client' );
      ...
      $client->wait( 100 );
      # close the client connection and free its resources
      $client->free();
  }


=head2 Simple Internet Client

  use Socket::Class;
  
  # create a new socket and connect to the server at localhost on port 9999
  $client = Socket::Class->new(
       'remote_addr' => 'localhost',
       'remote_port' => 9999,
  ) or die Socket::Class->error;
  
  # do something with the socket
  $str = $client->readline();  
  print $str, "\n";
  
  # close the client connection and free its resources
  $client->free();


=head2 Simple HTTP Client

  use Socket::Class;
  
  # create a new socket and connect to www.perl.org
  $sock = Socket::Class->new(
       'remote_addr' => 'www.perl.org',
       'remote_port' => 'http',
  ) or die Socket::Class->error;
  
  # request the main site
  $sock->write(
      "GET / HTTP/1.0\r\n" .
      "User-Agent: Not Mozilla\r\n" .
      "Host: " . $sock->remote_addr . "\r\n" .
      "Connection: Close\r\n" .
      "\r\n"
  ) or die $sock->error;
  
  # read the response (1MB max)
  $sock->read( $buf, 1048576 )
      or die $sock->error;
  
  # do something with the response
  print $buf;
  
  # close the socket an free its resources
  $sock->free();


=head2 Bluetooth RFCOMM Client

  use Socket::Class;
  
  # create a new socket and connect to a bluetooth device 
  $sock = Socket::Class->new(
      'domain' => 'bluetooth',
      'type' => 'stream',
      'proto' => 'rfcomm',
      'remote_addr' => '00:16:20:66:F2:6C',
      'remote_port' => 1, # channel
  ) or die Socket::Class->error;
  
  # do something with the socket
  $sock->send( "bluetooth works" );
  
  ...
  
  # close the connection and free its resources
  $sock->free();


=head1 METHODS

=head2 Constructing

=over 4

=item new ( [%arg] )

Creates a Socket::Class object, which is a reference to a newly created socket
handle. new optionally takes arguments, these arguments are in key-value pairs.

  remote_addr    Remote host address             <hostname> | <hostaddr>
  remote_port    Remote port or service          <service> | <number>
  remote_path    Remote path for unix sockets    "/tmp/mysql.sock"
  local_addr     Local host bind address         <hostname> | <hostaddr>
  local_port     Local host bind port            <service> | <number>
  local_path     Local path for unix sockets     "/tmp/myserver.sock"
  domain         Socket domain name (or number)  "inet" | "inet6" | ...
  proto          Protocol name (or number)       "tcp" | "udp" | ...
  type           Socket type name (or number)    "stream" | "dgram" | ...
  listen         Put socket into listen state with a specified maximal number
                 of connections in the queue
  broadcast      Set SO_BROADCAST before binding
  reuseaddr      Set SO_REUSEADDR before binding
  blocking       Enable or disable blocking mode; default is enabled
  timeout        Timeout value for various operations as floating point number;
                 defaults to 15000 (15 seconds); currently used for connect

If I<local_addr>, I<local_port> or I<local_path> is defined then the socket
will bind a local address. If I<listen> is defined then the socket will put
into listen state. If I<remote_addr>, I<remote_port> or I<remote_path> is
defined then connect() is called.

Standard I<domain> is AF_INET. Standard I<type> is SOCK_STREAM. Standard
I<proto> is IPPROTO_TCP. If I<local_path> or I<remote_path> is defined the
standard domain changes to AF_UNIX and the standard protocol changes to 0.

B<Examples>

I<Create a nonblocking listening inet socket on a random local port>

  $sock = Socket::Class->new(
      'listen' => 5,
      'blocking' => 0,
  ) or die Socket::Class->error;
  
  print "listen on local port ", $sock->local_port, "\n";

I<Create a listening unix socket>

  $sock = Socket::Class->new(
      'domain' => 'unix',
      'local_path' => '/tmp/myserver.sock',
      'listen' => 5,
  ) or die Socket::Class->error;

I<Connect to smtp service (port 25) on localhost>

  $sock = Socket::Class->new(
      'remote_addr' => 'localhost',
      'remote_addr' => 'smtp',
  ) or die Socket::Class->error;

I<Create a broadcast socket>

  $sock = Socket::Class->new(
      'remote_addr' => "255.255.255.255",
      'remote_port' => 9999,
      'proto' => 'udp',
      'local_addr' => 'localhost',
      'broadcast' => 1,
  ) or die Socket::Class->error;


=back

=head2 Closing / Destructing / Freeing

In non threaded applications an undef on the reference variable will free the
socket and its resources. In threaded applications undef wont work
anymore. In this case you should use I<free()>.

=over 4

=item shutdown ( [$how] )

Disables sends and receives on the socket.

B<Parameters>

I<$how>

One of the following values that specifies the operation that will no longer
be allowed.

  Num   Const         Description
  ----------------------------------------------------------------------
  1     $SD_SEND      Disable sending on the socket.
  2     $SD_RECEIVE   Disable receiving on the socket.
  3     $SD_BOTH      Disable both sending and receiving on the socket.

B<Return Values>

Returns TRUE on succes or FALSE on failure.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  use Socket::Class qw($SD_BOTH);
  
  $sock = Socket::Class->new( ... );
  
  ...
  
  $sock->shutdown( $SD_BOTH );
  $sock->free();


=item close ()

Closes the socket without freeing internal resources.


=item free ()

Closes the socket and frees all internally allocated resources.


=back

=head2 Bind and Accept

=over 4

=item bind ( [$addr [, $port]] )

=item bind ( [$path] )

Binds the socket to a specified local address.

B<Parameters>

I<$addr> or I<$path>

On 'inet' family sockets the I<$addr> parameter can be  an IP address in
dotted-quad notation (e.g. 127.0.0.1) or a valid hostname.

On 'inet6' family sockets the I<$addr> parameter can be an IPv6 address in
hexadecimal notation (e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344) or a
valid hostname.

On 'unix' family sockets the I<$path> is the pathname of a Unix domain socket.

If I<$addr> is not defined the address from last I<bind> is used.

I<$port>

The I<$port> parameter designates the port or channel on the local host.

B<Return Values>

Returns TRUE on succes or FALSE on failure.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $sock->bind( '0.0.0.0', 9999 )
      or die "can't bind: " . $sock->error;


=item accept ()

Accepts a connection on a bound socket. Once a successful connection is made,
a new socket resource is returned, which may be used for communication.
If there are multiple connections queued on the socket, the first will be
used. If there are no pending connections, accept() will block until a
connection becomes present. If socket has been made non-blocking using
set_blocking(), 0 will be returned.

B<Return Values>

Returns a new socket class on succes or 0 on non-blocking mode and no new
connection becomes available or UNDEF on failure. The error code can be
retrieved with L<errno()|Socket::Class/errno> and the error string can
be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

I<Blocking mode (default)>

  while( $client = $sock->accept() ) {
      # do something with the connection
      print "Incoming connection: ", $client->to_string, "\n";
      ...
      $client->free();
  }

I<Non blocking mode>

  while( 1 ) {
      $client = $sock->accept();
      if( ! defined $client ) {
          # error
          die $sock->error;
      }
      elsif( ! $client ) {
          # no client, sleep for a while
          $sock->wait( 10 );
          next;
      }
      # do something with the connection
      print "Incoming connection: ", $client->to_string, "\n";
      ...
      $client->free();
  }


=back

=head2 Connect

=over 4

=item connect ( [$addr [, $port [, $timeout]]] )

=item connect ( [$path [,$timeout]] )

Initiates a connection.

B<Parameters>

I<$addr> or I<$path>

On 'inet' family sockets the I<$addr> parameter can be  an IP address in
dotted-quad notation (e.g. 127.0.0.1) or a valid hostname.

On 'inet6' family sockets the I<$addr> parameter can be an IPv6 address in
hexadecimal notation (e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344) or a
valid hostname.

On 'unix' family sockets the I<$path> is the pathname of a Unix domain socket.

If I<$addr> is not defined the address from last I<connect> is used.

I<$port>

The I<$port> parameter designates the port or service on the remote host to
which a connection should be made.

I<$timeout>

Optionally timeout in milliseconds as floating point number.

B<Return Values>

Returns a TRUE value on succes or UNDEF on failure.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $sock->connect( 'www.perl.org', 'http' )
      or die "can't connect: " . $sock->error;


=item reconnect ( [$timeout] )

Closes the current connection, waits I<$timeout> milliseconds and
reconnects the socket to the connection previously made.

B<Return Values>

Returns a TRUE value on succes or UNDEF on failure.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  if( $sock->is_error ) {
  retry:
     print "socket error: ", $sock->error, "\n";
     # try to reconnect
     $r = $sock->reconnect( 1000 );
     if( ! $r ) {
         # can't connect
         goto retry;
     }
  }


=back

=head2 Low level sending and receiving data

=over 4

=item send ( $buf [, $flags] )

Sends data to a connected socket.

B<Parameters>

I<$buf>

A buffer containing the data that will be sent to the remote host.

I<$flags>

The value of I<$flags> can be any combination of the following: 

  Number  Constant         Description
  -------------------------------------------------------------
  0x1     $MSG_OOB         Process OOB (out-of-band) data  
  0x2     $MSG_PEEK        Peek at incoming message  
  0x4     $MSG_DONTROUTE   Bypass routing, use direct interface  
  0x8     $MSG_CTRUNC      Data completes record  
  0x100   $MSG_WAITALL     Data completes transaction  


B<Return Values>

Returns the number of bytes sent or UNDEF if an error occured.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $r = $sock->send( "important message" );
  if( ! defined $r ) {
      # error
      die "can't sent: " . $sock->error;
  }
  print "sent $r bytes\n";

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item recv ( $buf, $len [, $flags] )

Receives data from a connected socket.

B<Parameters>

I<$buf>

A variable to write the received bytes into.

I<$len>

The number of bytes to receive.

I<$flags>

The value of I<$flags> can be any combination of the following: 

  Number  Constant         Description
  ---------------------------------------------------------------------------
  0x1     $MSG_OOB         Process OOB (out-of-band) data  
  0x2     $MSG_PEEK        Peek at incoming message  
  0x4     $MSG_DONTROUTE   Bypass routing, use direct interface  
  0x8     $MSG_CTRUNC      Data completes record
  0x20    $MSG_TRUNC       Return the real length of the packet, even when it
                           was longer than the passed buffer.
                           Only valid for packet sockets. 

B<Return Values>

Returns the number of bytes received or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item sendto ( $buf [, $to [, $flags]] )

Sends a message to a socket, whether it is connected or not.

B<Parameters>

I<$buf>

A buffer containing the data that will be sent to the remote host.

I<$to>

Packed address of the remote host. (See pack_addr function)

I<$flags>

The value of I<$flags> can be any combination of the following: 

  Number  Constant         Description
  -------------------------------------------------------------
  0x1     $MSG_OOB         Process OOB (out-of-band) data  
  0x2     $MSG_PEEK        Peek at incoming message  
  0x4     $MSG_DONTROUTE   Bypass routing, use direct interface  

B<Return Values>

Returns the bytes sent to the remote host or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $sock = Socket::Class->new( 'proto' => 'udp' );
  
  $paddr = $sock->pack_addr( 'localhost', 9999 );
  $sock->sendto( 'PING', $paddr );

OR

  $sock = Socket::Class->new(
      'proto' => 'udp',
      'remote_addr' => 'localhost',
      'remote_port' => 9999,
  );
  
  $sock->sento( 'PING' );

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item recvfrom ( $buf, $len [, $flags] )

Receives data from a socket whether or not it is connection-oriented

B<Parameters>

I<$buf>

The data received will be fetched to the variable specified with buf.

I<$len>

Up to len bytes will be fetched from remote host.

I<$flags>

The following table contains the different flags that can be set using the
I<$flags> parameter. Use the OR logic operator (|) to use more than one flag.

  Number  Constant         Description
  ---------------------------------------------------------------------------
  0x1     $MSG_OOB         Process OOB (out-of-band) data  
  0x2     $MSG_PEEK        Receive data from the beginning of the receive queue
                           without removing it from the queue.
  0x40    $MSG_DONTWAIT    With this flag set, the function returns even if it
                           would normally have blocked. 
  0x100   $MSG_WAITALL     Block until at least len are received. However,
                           if a signal is caught or the remote host
                           disconnects, the function may return less data.

B<Return Values>

Returns a packed address of the sender or 0 on non-blocking mode and no data
becomes available or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

I<Blocking mode (default)>

  while( $paddr = $sock->recvfrom( $buf, 1024 ) ) {
      ( $r_addr, $r_port ) = $sock->unpack_addr( $paddr );
      print "Incoming message from $r_addr port $r_port\n";
  }

I<Non blocking mode>

  while( 1 ) {
      $paddr = $sock->recvfrom( $buf, 1024 );
      if( ! defined $paddr ) {
          # error
          die $sock->error;
      }
      elsif( ! $paddr ) {
          # no data, sleep for a while
          $sock->wait( 10 );
          next;
      }
      ( $r_addr, $r_port ) = $sock->unpack_addr( $paddr );
      print "Incoming message from $r_addr port $r_port\n";
  }

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=back

=head2 Higher level sending and receiving

=over 4

=item write ( $buffer [, $length] )

Writes to the socket from the given buffer.

B<Parameters>

I<$buffer>

The buffer to be written. 

I<$length>

The optional parameter I<$length> can specify an alternate length of bytes
written to the socket. If this length is greater then the buffer length,
it is silently truncated to the length of the buffer. 

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Notes>

Note: write () does not necessarily write all bytes from the given buffer.
It's valid that, depending on the network buffers etc., only a certain amount
of data, even one byte, is written though your buffer is greater. You have
to watch out so you don't unintentionally forget to transmit the rest of
your data. 


=item read ( $buffer, $length )

Reads a maximum of length bytes from a socket.

B<Parameters>

I<$buffer>

A variable to write the read bytes into.

I<$length>

The maximum number of bytes read is specified by the length parameter.

B<Return Values>

Returns number of bytes read or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item print ( ... )

Writes to the socket from the given parameters. I<print> maps to I<write>

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $sock->print( 'hello client', "\n" );


=item printf ( $fmt, ... )

Writes formated string to the socket.

B<Parameters>

I<$fmt>

Defines the format of the string. See Perl I<printf> and I<sprintf> for more
details

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  # round number to 3 digits after decimal point and send it
  $sock->printf( "%.3f", $number );
  
  # does the same like above
  $sock->write( sprintf( "%.3f", $number ) );


=item say ( ... )

=item writeline ( ... )

Writes to the socket from the given string plus a newline char (\n).
I<writeline> is a synonym for I<say>.

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $sock->say( 'hello client' );


=item readline ()

Reads characters from the socket and stops at \n or \r\n.

B<Return Values>

Returns a string value or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=back

=head2 Socket options

=over 4

=item set_blocking ( [$int] )

Sets blocking mode on the socket.

B<Parameters>

I<$int>

On 1 set blocking mode, on 0 set non-blocking mode.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_blocking ()

Returns the current blocking state.

B<Return Values>

Return a TRUE value on blocking mode, or FALSE on non-blocking mode,
or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_reuseaddr ( [$int] )

Sets the SO_REUSEADDR socket option.

B<Parameters>

I<$int>

On 1 enable reusaddr, on 0 disable reusaddr.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_reuseaddr ()

Returns the current value of SO_REUSEADDR.

B<Return Values>

Return the value of SO_REUSEADDR or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_broadcast ( [$int] )

Sets the SO_BROADCAST socket option.

B<Parameters>

I<$int>

On 1 enable reusaddr, on 0 disable reusaddr.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_broadcast ()

Returns the current value of SO_BROADCAST.

B<Return Values>

Return the value of SO_BROADCAST or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_rcvbuf_size ( [$size] )

Sets the SO_RCVBUF socket option.

B<Parameters>

I<$size>

The size of the receive buffer.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_rcvbuf_size ()

Returns the current value of SO_RCVBUF.

B<Return Values>

Return the value of SO_RCVBUF or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_sndbuf_size ( [$size] )

Sets the SO_SNDBUF socket option.

B<Parameters>

I<$size>

The size of the send buffer.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_sndbuf_size ()

Returns the current value of SO_SNDBUF.

B<Return Values>

Return the value of SO_SNDBUF or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_timeout ( [$ms] )

Sets the timeout for various operations.

B<Parameters>

I<$ms>

The timeout in milliseconds as floating point number.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_timeout ()

Returns the current timeout.

B<Return Values>

Return the timeout in milliseconds or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_tcp_nodelay ( [$int] )

Sets the TCP_NODELAY socket option.

B<Parameters>

I<$int>

On 1 disable the naggle algorithm, on 0 enable it.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item get_tcp_nodelay ()

Returns the current value of TCP_NODELAY.

B<Return Values>

Return the value of TCP_NODELAY or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item set_option ( $level, $optname, $optval, ... )

Sets socket options for the socket.

B<Parameters>

I<$level>

The level parameter specifies the protocol level at which the option resides.
For example, to retrieve options at the socket level, a level parameter of
SOL_SOCKET would be used. Other levels, such as TCP, can be used by specifying
the protocol number of that level.

I<$optname>

A valid socket option. 

I<$optval> ...

The option value in packed or unpacked format.
If I<$optval> is an integer value it will be packed as int.
For SO_LINGER, SO_RCVTIMEO and SO_SNDTIMEO one or two values are accepted
and are packed in the right format.

B<Return Values>

Return a TRUE value on succes or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  use Socket::Class qw($SOL_SOCKET $SO_LINGER $SO_RCVTIMEO);
  
  $sock = Socket::Class->new( ... );
  
  # disable linger
  $sock->set_option( $SOL_SOCKET, $SO_LINGER, 0, 0 );
  # same like
  $sock->set_option( $SOL_SOCKET, $SO_LINGER, pack( 'S!S!', 0, 0 ) );
  
  # set rcv timeout to 0sec + 100000usec
  $sock->set_option( $SOL_SOCKET, $SO_RCVTIMEO, 0, 100000 );
  # or in milliseconds
  $sock->set_option( $SOL_SOCKET, $SO_RCVTIMEO, 100 );

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item get_option ( $level, $optname )

Gets socket options for the socket.

B<Parameters>

I<$level>

The level parameter specifies the protocol level at which the option resides.
For example, to retrieve options at the socket level, a level parameter of
SOL_SOCKET would be used. Other levels, such as TCP, can be used by specifying
the protocol number of that level.

I<$optname>

A valid socket option. 

  Option             Description
  -----------------------------------------------------------------------------
  $SO_DEBUG          Reports whether debugging information is being recorded.  
  $SO_ACCEPTCONN     Reports whether socket listening is enabled.  
  $SO_BROADCAST      Reports whether transmission of broadcast messages is
                     supported.  
  $SO_REUSEADDR      Reports whether local addresses can be reused.  
  $SO_KEEPALIVE      Reports whether connections are kept active with periodic
                     transmission of messages. If the connected socket fails to
                     respond to these messages, the connection is broken and
                     processes writing to that socket are notified with a
                     SIGPIPE signal.  
  $SO_LINGER         Reports whether the socket lingers on close()
                     if data is present.  
  $SO_OOBINLINE      Reports whether the socket leaves out-of-band data inline.  
  $SO_SNDBUF         Reports send buffer size information.  
  $SO_RCVBUF         Reports recieve buffer size information.  
  $SO_ERROR          Reports information about error status and clears it.  
  $SO_TYPE           Reports the socket type.  
  $SO_DONTROUTE      Reports whether outgoing messages bypass the standard
                     routing facilities.  
  $SO_RCVLOWAT       Reports the minimum number of bytes to process for socket
                     input operations. ( Defaults to 1 )  
  $SO_RCVTIMEO       Reports the timeout value for input operations.  
  $SO_SNDLOWAT       Reports the minimum number of bytes to process for socket
                     output operations.  
  $SO_SNDTIMEO       Reports the timeout value specifying the amount of time
                     that an output function blocks because flow control
                     prevents data from being sent.  

B<Return Values>

Returns the value of the given option, or UNDEF on error.
If the size of the value equals the size of int the value will be unpacked as
integer.
For SO_LINGER, SO_RCVTIMEO and SO_SNDTIMEO the value will be unpacked also.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  use Socket::Class qw($SOL_SOCKET $SO_LINGER $SO_RCVTIMEO);
  
  $sock = Socket::Class->new( ... );
  
  # get linger
  ( $l_onoff, $l_linger ) =
      $sock->get_option( $SOL_SOCKET, $SO_LINGER );
  
  # get rcv timeout
  ( $tv_sec, $tv_usec ) =
      $sock->get_option( $SOL_SOCKET, $SO_RCVTIMEO );
  # or in milliseconds
  $ms = $sock->get_option( $SOL_SOCKET, $SO_RCVTIMEO );

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=back

=head2 Address Functions

=over 4

=item local_addr ()

Returns the local adress of the socket


=item local_port ()

Returns the local port of the socket


=item local_path ()

Returns the local path of 'unix' family sockets


=item remote_addr ()

Returns the remote adress of the socket


=item remote_port ()

Returns the remote port of the socket


=item remote_path ()

Returns the remote path of 'unix' family sockets


=item pack_addr ( $addr [, $port] )

Packs a given address and returns it.

B<Parameters>

I<$addr>

IP address on 'inet' family sockets or a unix path on 'unix' family sockets.

I<$port>

Port number of the address.

B<Return Values>

Returns a packed version of the given address.

B<Examples>

  $paddr = $sock->pack_addr( 'localhost', 9999 );
  ( $addr, $port ) = $sock->unpack_addr( $paddr );


=item unpack_addr ( $paddr )

Unpacks a given address and returns it.

B<Parameters>

I<$paddr>

A packed address.

B<Return Values>

Returns the unpacked version of the given address.

B<Examples>

  $paddr = $sock->pack_addr( 'localhost', 9999 );
  ( $addr, $port ) = $sock->unpack_addr( $paddr );


=item get_hostname ( $addr )

Resolves the name of a given host address.

B<Parameters>

I<$addr>

The host address in plain (e.g. '192.168.0.1') or packed format.

B<Return Values>

Returns the first hostname found, or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Examples>

  $str = $sock->get_hostname( '127.0.0.1' );
  
  # -or-
  
  $paddr = $sock->pack_addr( '127.0.0.1', 9999 );
  $str = $sock->get_hostname( $paddr );

=back

=head2 Miscellaneous Functions

=over 4

=item is_readable ( [$timeout] )

Does a read select on the socket and returns the result.

B<Parameters>

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, is_readable will return immediately;
this is used to poll the readability of the socket.
If the value is undef (no timeout), I<is_readable()> can block indefinitely.

B<Return Values>

Return 1 if the socket is readable, or 0 if it is not, or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item is_writable ( [$timeout] )

Does a write select on the socket and returns the result.

B<Parameters>

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, is_writable will return immediately;
this is used to poll the writability of the socket.
If the value is undef (no timeout), I<is_writable()> can block indefinitely.

B<Return Values>

Return 1 if the socket is writable, or 0 if it is not, or UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 


=item select ( [$read [, $write [, $error [, $timeout]]]] )

Runs the I<select()> system call on the socket with a specified timeout.

B<Parameters>

I<$read> [in/out]

If the I<$read> parameter is set, then the socket will be watched to see if
characters become available for reading.
Out: Indicates the state of readability.

I<$write> [in/out]

If the I<$write> parameter is set, then the socket will be watched to see if
a write will not block.
Out: Indicates the state of writability.

I<$except> [in/out]

If the I<$except> parameter is set, then the socket will be watched for
exceptions.
Out: Indicates the a socket exception.

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, is_writable will return immediately;
this is used to poll the writability of the socket.
If the value is undef (no timeout), I<select()> can block indefinitely.

B<Return Values>

Returns a number between 0 to 3 which indicates the parameters set to TRUE, or
UNDEF on error.
The error code can be retrieved with L<errno()|Socket::Class/errno>
and the error string can be retrieved with L<error()|Socket::Class/error>. 

B<Remarks>

In summary, the socket will be identified in a particular set when select
returns if:

I<read:>

=over 4

=item *

If listen has been called and a connection is pending, accept will succeed. 

=item *

Data is available for reading (includes OOB data if SO_OOBINLINE is enabled). 

=item *

Connection has been closed/reset/terminated. 

=back

I<write:>

=over 4

=item *

If processing a connect call (nonblocking), connection has succeeded. 

=item *

Data can be sent. 

=back

I<except:>

=over 4

=item *

If processing a connect call (nonblocking), connection attempt failed. 

=item *

OOB data is available for reading (only if SO_OOBINLINE is disabled). 

=back

B<Examples>

  # watch all states and return within 1 second
  $v = $sock->select( $r = 1, $w = 1, $e = 1, 1000 );
  if( ! defined $v ) {
      die $sock->error;
  }
  if( $e ) {
      # socket error
      $e = $sock->get_option( $SOL_SOCKET, $SO_ERROR );
      die $sock->error( $e );
  }
  if( $r ) {
      # socket is readable
      ...
  }
  if( $w ) {
      # socket is writable
      ...
  }

=item state ()

Returns the state of the socket.

B<Return Values>

  Number   Constant         Description
  ---------------------------------------------------
  0        $SOS_INIT        Socket is created
  1        $SOS_BOUND       Socket is bound
  2        $SOS_LISTEN      Socket is listening
  3        $SOS_CONNECTED   Socket is connected
  4        $SOS_CLOSED      Socket is closed
  99       $SOS_ERROR       Socket got an error on last send or receive


=item to_string ()

Returns a readable version of the socket.


=item handle ()

=item fileno ()

Returns the internal socket handle. I<fileno> is a synonym for I<handle>.


=item wait ( $ms )

=item sleep ( $ms )

Sleeps the given number of milliseconds. I<sleep> is a synonym for I<wait>.

B<Parameters>

I<$ms>

The number of milliseconds to sleep.


=back

=head2 Error handling

=over 4

=item is_error ()

Indicates a socket error. Returns a true value on socket state SOS_ERROR, or a
false value on other states.


=item errno ()

Returns the last error code.


=item error ( [code] )

Returns the error message of the error code provided by I<$code> parameter, or
from the last occurred error.

=back

=head1 MORE EXAMPLES

=head2 Internet Server using Threads

  use threads;
  use threads::shared;
  
  use Socket::Class;
  
  our $RUNNING : shared = 1;
  
  our $Server = Socket::Class->new(
      'local_addr' => '0.0.0.0',
      'local_port' => 9999,
      'listen' => 30,
      'blocking' => 0,
      'reuseaddr' => 1,
  ) or die Socket::Class->error;
  
  # catch interrupt signals to provide clean shutdown
  $SIG{'INT'} = \&quit;
  #$SIG{'TERM'} = \&quit;
  
  threads->create( \&server_thread, $Server );
  
  while( $RUNNING ) {
      # do other things here
      # ...
      # sleep for a while
      $Server->wait( 100 );
  }
  
  1;
  
  sub quit {
      my( $thread );
      $RUNNING = 0;
      foreach $thread( threads->list ) {
          $thread->join();
      }
      $Server->free();
      exit( 0 );
  }
  
  sub server_thread {
      my( $server ) = @_;
      my( $client );
      print 'Server running at ' . $server->local_addr .
          ' port ' . $server->local_port . "\n";
      while( $RUNNING ) {
      	  $client = $server->accept();
          if( ! defined $client ) {
              # server is closed
              last;
          }
          elsif( ! $client ) {
              # no connection available, sleep for a while
              $server->wait( 10 );
              next;
          }
          threads->create( \&client_thread, $client );
      }
      return 1;
  }
  
  sub client_thread {
      my( $client ) = @_;
      my( $buf, $got );
      print 'Connection from ' . $client->remote_addr .
          ' port ' . $client->remote_port . "\n";
      # do something with the client
      $client->set_blocking( 0 );
      while( $RUNNING ) {
          $got = $client->read( $buf, 4096 );
          if( ! defined $got ) {
              # error
              warn $client->error;
              last;
          }
          elsif( ! $got ) {
              # no data available, sleep for a while
              $client->wait( 10 );
              next;
          }
          print "Got $got bytes from client\n";
          $client->write( 'thank you!' );
      }
      # close the client and free allocated resources
      $client->wait( 50 );
      $client->free();
      $client->wait( 50 );
      # detach thread
      threads->self->detach() if $RUNNING;
      return 1;
  }

=head1 AUTHORS

Christian Mueller <christian_at_hbr1.com>

=head1 COPYRIGHT

The Socket::Class module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic
License, as specified in the Perl README file.

=cut
