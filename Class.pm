package Socket::Class;
# =============================================================================
# Socket::Class - A class to communicate with sockets
# Use "perldoc Socket::Class" for documenation
# =============================================================================

# enable for debugging
#use strict;
#use warnings;
#no warnings 'uninitialized';

our( $VERSION );

BEGIN {
	$VERSION = '2.20';
	require XSLoader;
	XSLoader::load( __PACKAGE__, $VERSION );
	*say = \&writeline;
	*sleep = \&wait;
	*fileno = \&handle;
	*remote_name = \&get_hostname;
}

1; # return

sub import {
	my $pkg = shift;
	my $callpkg = caller;
	@_ or return;
	$Socket::Class::Const::VERSION
		or require Socket::Class::Const;
	&Socket::Class::Const::export( $callpkg, @_ );
}

sub printf {
	if( @_ < 2 ) {
		require Carp unless $Carp::VERSION;
		&Carp::croak( 'Usage: Socket::Class::printf(this,fmt,...)' );
	}
	my( $sock, $fmt ) = ( shift, shift );
	return $sock->write( sprintf( $fmt, @_ ) );
}

sub reconnect {
	if( @_ < 1 || @_ > 2 ) {
		require Carp unless $Carp::VERSION;
		&Carp::croak( 'Usage: Socket::Class::reconnect(this,wait=0)' );
	}
	my $this = shift;
	$this->close() or return undef;
	$this->wait( $_[0] ) if $_[0];
	$this->connect() or return undef;
	return 1;
}

sub include_path {
	return substr( __FILE__, 0, -16 ) . '/auto/Socket/Class';
}

__END__

=head1 NAME

Socket::Class - A class to communicate with sockets


=head1 SYNOPSIS

  use Socket::Class;

=head1 DESCRIPTION

Socket::Class provides a simple, fast and efficient way to communicate with
sockets.
It operates outside of Perl IO and socket layer. It can be used as a
B<replacement to IO::Socket>.
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

L<get_hostaddr|Socket::Class/get_hostaddr>,
L<get_hostname|Socket::Class/get_hostname>,
L<getaddrinfo|Socket::Class/getaddrinfo>,
L<getnameinfo|Socket::Class/getnameinfo>,
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
L<get_timeout|Socket::Class/get_timeout>,
L<get_tcp_nodelay|Socket::Class/get_tcp_nodelay>,
L<set_blocking|Socket::Class/set_blocking>,
L<set_broadcast|Socket::Class/set_broadcast>,
L<set_option|Socket::Class/set_option>,
L<set_rcvbuf_size|Socket::Class/set_rcvbuf_size>,
L<set_reuseaddr|Socket::Class/set_reuseaddr>,
L<set_sndbuf_size|Socket::Class/set_sndbuf_size>,
L<set_timeout|Socket::Class/set_timeout>,
L<set_tcp_nodelay|Socket::Class/set_tcp_nodelay>

=back

B<Miscellaneous Functions>

=over 4

=item

L<available|Socket::Class/available>,
L<fileno|Socket::Class/fileno>,
L<handle|Socket::Class/handle>,
L<is_readable|Socket::Class/is_readable>,
L<is_writable|Socket::Class/is_writable>,
L<select|Socket::Class/select>,
L<sleep|Socket::Class/sleep>,
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

  use Socket::Class qw(SOMAXCONN);
  
  # create a new socket on port 9999 and listen for clients 
  $server = Socket::Class->new(
       'local_port' => 9999,
       'listen' => SOMAXCONN,
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
      "Host: www.perl.org\r\n" .
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

=item B<new ( [%arg] )>

Creates a Socket::Class object, which is a reference to a newly created socket
handle. I<new()> optionally takes arguments, these arguments must set as
key-value pairs.

=for formatter none

  remote_addr    Remote host address             <hostname> | <hostaddr>
  remote_port    Remote port or service          <service> | <number>
  remote_path    Remote path for unix sockets    "/tmp/mysql.sock"
  local_addr     Local host bind address         <hostname> | <hostaddr>
  local_port     Local host bind port            <service> | <number>
  local_path     Local path for unix sockets     "/tmp/myserver.sock"
  domain         Socket domain name (or number)  "inet" | "inet6" | ...
  proto          Protocol name (or number)       "tcp" | "udp" | ...
  type           Socket type name (or number)    "stream" | "dgram" | ...
  listen         Put socket into listen state with a specified maximal
                 number of connections in the queue
  broadcast      Set SO_BROADCAST before binding
  reuseaddr      Set SO_REUSEADDR before binding
  blocking       Enable or disable blocking mode; default is enabled
  timeout        Timeout value for various operations as floating point
                 number;
                 defaults to 15000 (15 seconds); currently used for connect

=for formatter perl

If I<local_addr>, I<local_port> or I<local_path> is defined, then the socket
will bind a local address. If I<listen> is defined, then the socket will put
into listen state. If I<remote_addr>, I<remote_port> or I<remote_path> is
defined then I<connect()> is called.

Standard I<domain> is AF_INET. Standard socket I<type> is SOCK_STREAM.
Standard I<proto> is IPPROTO_TCP. If I<local_path> or I<remote_path> is
defined, then the standard domain becomes AF_UNIX and the standard
protocol becomes 0.

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
      'remote_port' => 'smtp',
  ) or die Socket::Class->error;

I<Create a broadcast socket>

  $sock = Socket::Class->new(
      'remote_addr' => '255.255.255.255',
      'remote_port' => 9999,
      'proto' => 'udp',
      'local_addr' => 'localhost',
      'broadcast' => 1,
  ) or die Socket::Class->error;


=back

=head2 Closing / Destructing / Freeing

Undefining all reference variables will free the socket and its resources.

You can also call I<free()> to free the socket explicitly.

=over 4

=item B<shutdown ( [$how] )>

Disables sends and receives on the socket.

B<Parameters>

I<$how>

One of the following values that specifies the operation that will no longer
be allowed. Default is $SD_SEND.

=for formatter none

  Num   Const         Description
  ----------------------------------------------------------------------
  0     SD_SEND       Disable sending on the socket.
  1     SD_RECEIVE    Disable receiving on the socket.
  2     SD_BOTH       Disable both sending and receiving on the socket.

=for formatter perl

B<Return Values>

Returns a true value on sucess or undef on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  use Socket::Class qw(SD_BOTH);
  
  $sock = Socket::Class->new( ... );
  
  ...
  
  $sock->shutdown( SD_BOTH );
  $sock->free();


=item B<close ()>

Closes the socket without freeing internal resources.


=item B<free ()>

Closes the socket and frees all internally allocated resources.


=back

=head2 Bind, Listen and Accept

=over 4

=item B<bind ( [$addr [, $port]] )>

=item B<bind ( [$path] )>

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

Returns a true value on sucess or undef on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $sock->bind( '0.0.0.0', 9999 )
      or die "can't bind: " . $sock->error;


=item B<listen ( [$backlog] )>

Listens for a connection on a socket.

B<Parameters>

I<$backlog>

A maximum of backlog incoming connections will be queued for processing.
If a connection request arrives with the queue full the client may
receive an error with an indication of ECONNREFUSED, or, if the
underlying protocol supports retransmission, the request may be ignored
so that retries may succeed.

B<Return Values>

Returns a true value on sucess or undef on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  use Socket::Class qw(SOMAXCONN);
  ...
  $sock->listen( SOMAXCONN )
      or die $sock->error;


=item B<accept ()>

Accepts a connection on a bound socket. Once a successful connection is made,
a new socket resource is returned, which may be used for communication.
If there are multiple connections queued on the socket, the first will be
used. If there are no pending connections, accept() will block until a
connection becomes present. If socket has been made non-blocking using
set_blocking(), 0 will be returned.

B<Return Values>

Returns a new socket class on sucess or 0 on non-blocking mode and no new
connection becomes available or UNDEF on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


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

=item B<connect ( [$addr [, $port [, $timeout]]] )>

=item B<connect ( [$path [,$timeout]] )>

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

Returns a TRUE value on sucess or UNDEF on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $sock->connect( 'www.perl.org', 'http' )
      or die "can't connect: " . $sock->error;


=item B<reconnect ( [$timeout] )>

Closes the current connection, waits I<$timeout> milliseconds and
reconnects the socket to the connection previously made.

B<Return Values>

Returns a true value on sucess or undef on failure.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

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

=item B<send ( $buf [, $flags] )>

Sends data to a connected socket.

B<Parameters>

I<$buf>

A buffer containing the data that will be sent to the remote host.

I<$flags>

The value of I<$flags> can be any combination of the following: 

=for formatter none

  Number  Constant         Description
  -------------------------------------------------------------
  0x1     MSG_OOB          Process OOB (out-of-band) data  
  0x2     MSG_PEEK         Peek at incoming message  
  0x4     MSG_DONTROUTE    Bypass routing, use direct interface  
  0x8     MSG_CTRUNC       Data completes record  
  0x100   MSG_WAITALL      Data completes transaction  

=for formatter perl


B<Return Values>

Returns the number of bytes sent or undef if an error occured.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $r = $sock->send( "important message" );
  if( ! defined $r ) {
      # error
      die "can't sent: " . $sock->error;
  }
  print "sent $r bytes\n";

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item B<recv ( $buf, $len [, $flags] )>

Receives data from a connected socket.

B<Parameters>

I<$buf>

A variable to write the received bytes into.

I<$len>

The number of bytes to receive.

I<$flags>

The value of I<$flags> can be any combination of the following: 

=for formatter none

  Number  Constant         Description
  ----------------------------------------------------------------------
  0x1     MSG_OOB          Process OOB (out-of-band) data  
  0x2     MSG_PEEK         Peek at incoming message  
  0x4     MSG_DONTROUTE    Bypass routing, use direct interface  
  0x8     MSG_CTRUNC       Data completes record
  0x20    MSG_TRUNC        Return the real length of the packet, even
                           when it was longer than the passed buffer.
                           Only valid for packet sockets. 

=for formatter perl

B<Return Values>

Returns the number of bytes received or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item B<sendto ( $buf [, $to [, $flags]] )>

Sends a message to a socket, whether it is connected or not.

B<Parameters>

I<$buf>

A buffer containing the data that will be sent to the remote host.

I<$to>

Packed address of the remote host. (See pack_addr function)

I<$flags>

The value of I<$flags> can be any combination of the following: 

=for formatter none

  Number  Constant         Description
  -------------------------------------------------------------
  0x1     MSG_OOB          Process OOB (out-of-band) data  
  0x2     MSG_PEEK         Peek at incoming message  
  0x4     MSG_DONTROUTE    Bypass routing, use direct interface  

=for formatter perl

B<Return Values>

Returns the bytes sent to the remote host or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

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


=item B<recvfrom ( $buf, $len [, $flags] )>

Receives data from a socket whether or not it is connection-oriented

B<Parameters>

I<$buf>

The data received will be fetched to the variable specified with buf.

I<$len>

Up to len bytes will be fetched from remote host.

I<$flags>

The following table contains the different flags that can be set using the
I<$flags> parameter. Use the OR logic operator (|) to use more than one flag.

=for formatter none

  Number  Constant         Description
  -----------------------------------------------------------------------
  0x1     MSG_OOB          Process OOB (out-of-band) data  
  0x2     MSG_PEEK         Receive data from the beginning of the receive
                           queue without removing it from the queue.
  0x40    MSG_DONTWAIT     With this flag set, the function returns even
                           if it would normally have blocked. 
  0x100   MSG_WAITALL      Block until at least len are received. However,
                           if a signal is caught or the remote host
                           disconnects, the function may return less data.

=for formatter perl

B<Return Values>

Returns a packed address of the sender or 0 on non-blocking mode and no data
becomes available or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

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

=item B<write ( $buffer [, $start [, $length]] )>

Writes to the socket from the given buffer.

B<Parameters>

I<$buffer>

The buffer to be written. 

I<$start>

The optional parameter I<$start> can specify an alternate offset in the
buffer.

I<$length>

The optional parameter I<$length> can specify an alternate length of bytes
written to the socket. If this length is greater then the buffer length,
it is silently truncated to the length of the buffer. 

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Notes>

Note: write () does not necessarily write all bytes from the given buffer.
It's valid that, depending on the network buffers etc., only a certain amount
of data, even one byte, is written though your buffer is greater. You have
to watch out so you don't unintentionally forget to transmit the rest of
your data. 

B<Examples>

  # generate 1mb of data
  $data = '#' x 1048576;
  # send the data out
  $start = 0;
  $size = length( $data );
  while( ! $sock->is_error && $start < $size ) {
      if( $sock->is_writable( 100 ) ) {
          $start += $sock->write( $data, $start );
      }
  }

=item B<read ( $buffer, $length )>

Reads a maximum of length bytes from a socket.

B<Parameters>

I<$buffer>

A variable to write the read bytes into.

I<$length>

The maximum number of bytes read is specified by the length parameter.

B<Return Values>

Returns number of bytes read, or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  # read from socket until error
  $data = '';
  while( ! $sock->is_error ) {
      if( $sock->is_readable( 100 ) ) {
          $sock->read( $buffer, 4096 )
              or last;
          $data .= $buffer;
      }
  }
  printf "received %d bytes\n", length( $data );


=item B<print ( ... )>

Writes to the socket from the given parameters. I<print> maps to I<write>

B<Return Values>

Returns the number of bytes successfully written to the socket, or undef on
error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $sock->print( 'hello client', "\n" );


=item B<printf ( $fmt, ... )>

Writes formated string to the socket.

B<Parameters>

I<$fmt>

Defines the format of the string. See Perl I<printf> and I<sprintf> for more
details

B<Return Values>

Returns the number of bytes successfully written to the socket or UNDEF on
error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  # round number to 3 digits after decimal point and send it
  $sock->printf( "%.3f", $number );
  
  # does the same like above
  $sock->write( sprintf( "%.3f", $number ) );


=item B<writeline ( ... )>

=item B<say ( ... )>

Writes to the socket from the given string plus a carriage return and a newline
char (\r\n).
I<say> is a synonym for I<writeline>.

B<Return Values>

Returns the number of bytes successfully written to the socket, or undef on
error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $sock->say( 'hello client' );


=item B<readline ()>

Reads characters from the socket and stops at \r\n, \n\r, \n, \r or \0.

B<Return Values>

Returns a string value, or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=back

=head2 Socket options

=over 4

=item B<set_blocking ( [$int] )>

Changes the blocking mode of the socket.

B<Parameters>

I<$int>

=for formatter none

  1 - blocking mode
  0 - non-blocking mode

=for formatter perl

B<Return Values>

Returns a true value on success, or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_blocking ()>

Returns the current blocking state.

B<Return Values>

Returns TRUE value on blocking mode, or FALSE on non-blocking mode,
or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_reuseaddr ( [$int] )>

Sets the SO_REUSEADDR socket option.

B<Parameters>

I<$int>

=for formatter none

  1 - enable reuseaddr
  0 - disable reuseaddr

=for formatter perl

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_reuseaddr ()>

Returns the current value of SO_REUSEADDR.

B<Return Values>

Returns the value of SO_REUSEADDR or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_broadcast ( [$int] )>

Sets the SO_BROADCAST socket option.

B<Parameters>

I<$int>

=for formatter none

  1 - set SO_BROADCAST 
  0 - unset SO_BROADCAST

=for formatter perl

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_broadcast ()>

Returns the current value of SO_BROADCAST.

B<Return Values>

Returns the value of SO_BROADCAST or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_rcvbuf_size ( [$size] )>

Sets the SO_RCVBUF socket option.

B<Parameters>

I<$size>

The size of the receive buffer.

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_rcvbuf_size ()>

Returns the current value of SO_RCVBUF.

B<Return Values>

Returns the value of SO_RCVBUF or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_sndbuf_size ( [$size] )>

Sets the SO_SNDBUF socket option.

B<Parameters>

I<$size>

The size of the send buffer.

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_sndbuf_size ()>

Returns the current value of SO_SNDBUF.

B<Return Values>

Returns the value of SO_SNDBUF or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_timeout ( [$ms] )>

Sets the timeout for various operations.

B<Parameters>

I<$ms>

The timeout in milliseconds as floating point number.

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_timeout ()>

Returns the current timeout.

B<Return Values>

Returns the timeout in milliseconds or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_tcp_nodelay ( [$int] )>

Sets the TCP_NODELAY socket option.

B<Parameters>

I<$int>

On 1 disable the naggle algorithm, on 0 enable it.

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<get_tcp_nodelay ()>

Returns the current value of TCP_NODELAY.

B<Return Values>

Returns the value of TCP_NODELAY or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<set_option ( $level, $optname, $optval, ... )>

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

The value in packed or unpacked format.
If I<$optval> is an integer value it will be packed as int.
For SO_LINGER, SO_RCVTIMEO and SO_SNDTIMEO one or two values are accepted.
Please see examples below.

B<Return Values>

Returns a TRUE value on sucess or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  use Socket::Class qw(SOL_SOCKET SO_LINGER SO_RCVTIMEO);
  
  $sock = Socket::Class->new( ... );
  
  # disable linger
  $sock->set_option( SOL_SOCKET, SO_LINGER, 0, 0 );
  # same like
  $sock->set_option( SOL_SOCKET, SO_LINGER, pack( 'S!S!', 0, 0 ) );
  
  # set rcv timeout to 0sec + 100000usec
  $sock->set_option( SOL_SOCKET, SO_RCVTIMEO, 0, 100000 );
  # or in milliseconds
  $sock->set_option( SOL_SOCKET, SO_RCVTIMEO, 100 );

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=item B<get_option ( $level, $optname )>

Gets socket options for the socket.

B<Parameters>

I<$level>

The level parameter specifies the protocol level at which the option resides.
For example, to retrieve options at the socket level, a level parameter of
SOL_SOCKET would be used. Other levels, such as TCP, can be used by specifying
the protocol number of that level.

I<$optname>

A valid socket option. 

=for formatter none

  Option             Description
  -----------------------------------------------------------------------
  SO_DEBUG           Reports whether debugging information is being
                     recorded.  
  SO_ACCEPTCONN      Reports whether socket listening is enabled.  
  SO_BROADCAST       Reports whether transmission of broadcast messages
                     is supported.  
  SO_REUSEADDR       Reports whether local addresses can be reused.  
  SO_KEEPALIVE       Reports whether connections are kept active with
                     periodic transmission of messages. If the connected
                     socket fails to respond to these messages, the
                     connection is broken and processes writing to that
                     socket are notified with a SIGPIPE signal.  
  SO_LINGER          Reports whether the socket lingers on close()
                     if data is present.  
  SO_OOBINLINE       Reports whether the socket leaves out-of-band data
                     inline.  
  SO_SNDBUF          Reports send buffer size information.  
  SO_RCVBUF          Reports recieve buffer size information.  
  SO_ERROR           Reports information about error status and clears it.  
  SO_TYPE            Reports the socket type.  
  SO_DONTROUTE       Reports whether outgoing messages bypass the standard
                     routing facilities.  
  SO_RCVLOWAT        Reports the minimum number of bytes to process for
                     socket input operations. ( Defaults to 1 )  
  SO_RCVTIMEO        Reports the timeout value for input operations.  
  SO_SNDLOWAT        Reports the minimum number of bytes to process for
                     socket output operations.  
  SO_SNDTIMEO        Reports the timeout value specifying the amount of
                     time that an output function blocks because flow
                     control prevents data from being sent.  

=for formatter perl

B<Return Values>

Returns the value of the given option, or UNDEF on error.
If the size of the value equals the size of int the value will be unpacked into
integer.
For SO_LINGER, SO_RCVTIMEO and SO_SNDTIMEO the value is unpacked, too.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  use Socket::Class qw(SOL_SOCKET SO_LINGER SO_RCVTIMEO);
  
  $sock = Socket::Class->new( ... );
  
  # get linger
  ($l_onoff, $l_linger) =
      $sock->get_option( SOL_SOCKET, SO_LINGER );
  
  # get rcv timeout
  ($tv_sec, $tv_usec) =
      $sock->get_option( SOL_SOCKET, SO_RCVTIMEO );
  # or in milliseconds
  $ms = $sock->get_option( SOL_SOCKET, SO_RCVTIMEO );

B<See Also>

L<Socket::Class::Const|Socket::Class::Const>


=back

=head2 Address Functions

=over 4

=item B<local_addr ()>

Returns the local address of the socket


=item B<local_port ()>

Returns the local port of the socket


=item B<local_path ()>

Returns the local path of 'unix' family sockets


=item B<remote_addr ()>

Returns the remote address of the socket


=item B<remote_port ()>

Returns the remote port of the socket


=item B<remote_path ()>

Returns the remote path of 'unix' family sockets


=item B<pack_addr ( $addr [, $port] )>

Packs a given address and returns it.

B<Parameters>

I<$addr>

IP address on 'inet' family sockets or a unix path on 'unix' family sockets.

I<$port>

Port number of the address.

B<Return Values>

Returns the packed address.

B<Examples>

  $paddr = $sock->pack_addr( 'localhost', 9999 );
  ($addr, $port) = $sock->unpack_addr( $paddr );


=item B<unpack_addr ( $paddr )>

Unpacks a given address and returns it.

B<Parameters>

I<$paddr>

A packed address.

B<Return Values>

Returns the unpacked address.

B<Examples>

  $paddr = $sock->pack_addr( 'localhost', 9999 );
  ($addr, $port) = $sock->unpack_addr( $paddr );
  # in scalar context only the address part will return
  $addr = $sock->unpack_addr( $paddr );


=item B<get_hostname ()>

=item B<get_hostname ( $addr )>

=item B<remote_name ()>

Resolves the name of a given host address. I<remote_name> is a synonym for
I<get_hostname>.

B<Parameters>

I<$addr>

The host address in plain (e.g. '192.168.0.1') or packed format.
If no address is specified the remote address of the socket is used.

B<Return Values>

Returns the first hostname found, or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $str = $sock->get_hostname( '127.0.0.1' );
  
  # -or-
  
  $paddr = $sock->pack_addr( '127.0.0.1', 9999 );
  $str = $sock->get_hostname( $paddr );
  
  # -or-
  
  $sock->connect( 'www.perl.org', 'http' )
      or die $sock->error;
  print "conntected to ", $sock->remote_name || $sock->remote_addr, "\n";


=item B<get_hostaddr ( $name )>

Resolves the address of a given host name.

B<Parameters>

I<$name>

The host name as a string.

B<Return Values>

Returns the host address, or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

  $host = 'www.perl.org';
  $addr = $sock->get_hostaddr( $host );
  print "address of $host is $addr\n";


=item B<getaddrinfo
	( $node [, $service [, $family [, $proto [, $type [, $flags]]]]] )>

The getaddrinfo function provides protocol-independent translation of
host names to an address.
The function can be exported.

B<Parameters>

I<$node>

A string that contains a host (node) name or a numeric host address string.
For the internet protocol, the numeric host address string is a
dotted-decimal IPv4 address or an IPv6 hex address.

I<$service>

A service name or port number, or undef to get all services.

I<$family>

The address family as name or number, or undef to get all families.

I<$proto>

The protocol type as name or number, or undef to get all protocols.

I<$type>

The socket type as name or number, or undef to get all socket types.

I<$flags>

Flags that indicate options used.
See L<getaddrinfo() flags|Socket::Class::Const/"Flags for getaddrinfo()">
in the L<Socket::Class::Const|Socket::Class::Const> module

B<Return Values>

Returns an array of hashes with address information, or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

Address information structure:

=for formatter none

  'family'         => address family as number
  'socktype'       => socket type as number
  'protocol'       => protocol type as number
  'paddr'          => address in packed format
  'canonname'      => [opt] canonical name for the host
  'familyname'     => [opt] name of address family (eg. 'INET')
  'sockname'       => [opt] name of socket type (eg. 'STREAM')
  'protocolname'   => [opt] name of protocol type (eg. 'TCP')
  'addr'           => [opt] readable version of IP v4/6 address
  'port'           => [opt] readable version of IP v4/6 port

=for formatter perl


B<Examples>

I<getaddrinfo()> as global function

  @list = Socket::Class->getaddrinfo( 'localhost' )
      or die Socket::Class->error;


I<getaddrinfo()> within an object

  $sock = Socket::Class->new();
  @list = $sock->getaddrinfo( 'localhost' )
      or die $sock->error;


=item B<getnameinfo ( $addr [, $service [, $flags]] )>

=item B<getnameinfo ( $paddr [, $flags] )>

The getnameinfo function provides protocol-independent name resolution from
an address to a host name and from a port number to the service name.
The function can be exported.

B<Parameters>

I<$addr>

The host address in plain (e.g. '192.168.0.1') format.

I<$service>

A service name or port number.

I<$paddr>

A packed host address. See also L<pack_addr()|Socket::Class/pack_addr>,
L<getaddrinfo()|Socket::Class/getaddrinfo>

I<$flags>

A value used to customize processing of the I<getnameinfo> function.
See L<getnameinfo() flags|Socket::Class::Const/Flags for getnameinfo()>
in the L<Socket::Class::Const|Socket::Class::Const> module

B<Return Values>

Returns the hostname in scalar context, or hostname and service in array
context, or undef on error. 
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Examples>

I<getnameinfo()> as global function

  ($host, $service) = Socket::Class->getnameinfo( '127.0.0.1', 80 )
      or die Socket::Class->error;
  print "host: $host, service: $service\n";


I<getnameinfo()> within an object

  $sock = Socket::Class->new();
  ($host, $service) = $sock->getnameinfo( '127.0.0.1', 80 )
      or die $sock->error;
  print "host: $host, service: $service\n";


=back

=head2 Miscellaneous Functions

=over 4

=item B<available ()>

Gets the amount of data that is available to be read.

B<Return Values>

Returns the number of bytes that is available to be read, or undef on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

B<Remarks>

On blocking sockets the function can block infinitely. In this case you
should call L<is_readable()|Socket::Class/is_readable> before running the
function.

B<Examples>

  while( ! $sock->is_error ) {
      if( $sock->is_readable( 1000 ) ) {
          $size = $sock->available
              or die $sock->error;
          print "bytes to read: $size\n";
          $got = $sock->read( $buf, $size );
              or die $sock->error;
      }
  }

=item B<is_readable ( [$timeout] )>

Checks the socket for readability.

B<Parameters>

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, is_readable will return immediately;
this is used to poll the readability of the socket.
If the value is undef (no timeout), I<is_readable()> can block indefinitely.

B<Return Values>

Returns TRUE if the socket is readable, or FALSE if it is not,
or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<is_writable ( [$timeout] )>

Checks the socket for writability.

B<Parameters>

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, is_writable will return immediately;
this is used to poll the writability of the socket.
If the value is undef (no timeout), I<is_writable()> can block indefinitely.

B<Return Values>

Returns TRUE if the socket is writable, or FALSE if it is not, or UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 


=item B<select ( [$read [, $write [, $except [, $timeout]]]] )>

Runs the I<select()> system call on the socket with a specified timeout.

B<Parameters>

I<$read> - [in/out]

If the I<$read> parameter is set, the socket will be watched to see if
characters become available for reading.
Out: Indicates the state of readability.

I<$write> - [in/out]

If the I<$write> parameter is set, the socket will be watched to see if
a write will not block.
Out: Indicates the state of writability.

I<$except> - [in/out]

If the I<$except> parameter is set, the socket will be watched for
exceptions.
Out: Indicates a socket exception.

I<$timeout>

The timeout in milliseconds as a floating point value.
If I<$timeout> is initialized to 0, select will return immediately;
this is used to poll the state of the socket.
If the value is undef (no timeout), I<select()> can block indefinitely.

B<Return Values>

Returns a number between 0 to 3 which indicates the parameters set to TRUE, or
UNDEF on error.
Use L<errno()|Socket::Class/errno> and L<error()|Socket::Class/error>
to retrieve the error code and message. 

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

  use Socket::Class qw($SOL_SOCKET $SO_ERROR);
  
  ...
  
  # watch all states and return within 1000 milliseconds
  $v = $sock->select( $r = 1, $w = 1, $e = 1, 1000 );
  unless( defined $v ) {
      die "select failed: " . $sock->error;
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

=item B<state ()>

Returns the state of the socket.

B<Return Values>

=for formatter none

  Number   Constant             Description
  ---------------------------------------------------
  0        SC_STATE_INIT        Socket is created
  1        SC_STATE_BOUND       Socket is bound
  2        SC_STATE_LISTEN      Socket is listening
  3        SC_STATE_CONNECTED   Socket is connected
  4        SC_STATE_CLOSED      Socket is closed
  99       SC_STATE_ERROR       Socket got an error on last send or receive

=for formatter perl


=item B<to_string ()>

Returns a readable version of the socket.


=item B<handle ()>

=item B<fileno ()>

Returns the internal socket handle. I<fileno> is a synonym for I<handle>.


=item B<wait ( $ms )>

=item B<sleep ( $ms )>

Sleeps the given number of milliseconds. I<sleep> is a synonym for I<wait>.

B<Parameters>

I<$ms>

The number of milliseconds to sleep as floating point number.


=back

=head2 Error handling

=over 4

=item B<is_error ()>

Indicates a socket error. Returns TRUE on socket state SC_STATE_ERROR,
or FALSE value on other state.


=item B<errno ()>

Returns the last error code.


=item B<error ( [code] )>

Returns the error message for the error code provided by the I<$code>
parameter, or for the last error occurred.

=back

=head1 MORE EXAMPLES

=head2 Internet Server using threads

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
  
  # catch interrupt signals for a clean shutdown
  $SIG{'INT'} = \&quit;
  #$SIG{'TERM'} = \&quit;
  
  # create the server thread
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
          eval {
              $thread->join();
          };
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
      # detach thread
      threads->self->detach() if $RUNNING;
      return 1;
  }

=head1 XS / C API

The module provides a C interface for extension writers.

B<Example XS>

=for formatter cpp

  #include <mod_sc.h>
  
  /* global pointer to the socket class interface */
  mod_sc_t *g_mod_sc;
  
  MODULE = MyModule		PACKAGE = MyModule
  
  BOOT:
  {
      SV **psv;
      psv = hv_fetch(PL_modglobal, "Socket::Class", 13, 0);
      if (psv == NULL)
          croak("Socket::Class 2.0 or higher required");
      g_mod_sc = INT2PTR(mod_sc_t *, SvIV(*psv));
  }
  
  void
  test()
  PREINIT:
      sc_t *socket;
      char *args[4];
      int r;
      SV *sv;
  PPCODE:
      args[0] = "local_port";
      args[1] = "8080";
      args[2] = "listen";
      args[3] = "10";
      r = g_mod_sc->sc_create(args, 4, &socket);
      if (r != SC_OK)
          croak(g_mod_sc->sc_get_error(NULL));
      g_mod_sc->sc_create_class(socket, NULL, &sv);
      ST(0) = sv_2mortal(sv);
      XSRETURN(1);

=for formatter perl

See I<mod_sc.h> for the definition and the source code of I<Class.xs>
for an implementation.

Use I<Socket::Class::include_path()> to get the path to I<mod_sc.h>.

=head1 AUTHORS

Navalla org., Christian Mueller, L<http://www.navalla.org/>

=head1 COPYRIGHT AND LICENSE

The Socket::Class module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic
License, as specified in the Perl README file.

=cut
