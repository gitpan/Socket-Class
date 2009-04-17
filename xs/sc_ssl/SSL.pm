package Socket::Class::SSL;

# uncomment for debugging
#use strict;
#use warnings;

use Socket::Class;

our( $VERSION, @ISA );

BEGIN {
	$VERSION = '1.11';
	@ISA = qw(Socket::Class);
	require XSLoader;
	XSLoader::load( __PACKAGE__, $VERSION );
	*say = \&writeline;
}

1; # return

sub include_path {
	return substr( __FILE__, 0, -20 ) . '/auto/Socket/Class/SSL';
}

__END__

=head1 NAME

Socket::Class::SSL - SSL support for Socket::Class


=head1 SYNOPSIS

  use Socket::Class::SSL;
  
  $s = Socket::Class::SSL->new( ... );

=head1 DESCRIPTION

The module inherits L<Socket::Class> and adds SSL support implemented
by the OpenSSL Toolkit.
Only the differences to Socket::Class are documented here.

=head1 EXAMPLES

=head2 Simple HTTPS Server

  use Socket::Class::SSL;
  
  $s = Socket::Class::SSL->new(
      'local_port' => 10443,
      'listen' => 10,
      #'private_key' => 'cert/server.key',
      #'certificate' => 'cert/server.crt',
  ) or die Socket::Class->error;
  
  while( $c = $s->accept ) {
      # read request header
      while( $l = $c->readline ) {
          print $l, "\n";
      }
      # send response header
      $c->write(
          "HTTP/1.0 200 OK\r\n" .
          "Server: SSL Server\r\n" .
          "\r\n"
      );
      # send response content
      $c->write( "content" );
  }

=head2 Simple HTTPS Client

  use Socket::Class::SSL;
  
  $c = Socket::Class::SSL->new(
      'remote_port' => 10443,
  ) or die Socket::Class->error;
  
  # send request
  $c->write(
      "GET / HTTP/1.0\r\n" .
      "Host: localhost\r\n" .
      "\r\n"
  );
  
  # read response header
  while( $l = $c->readline ) {
      print $l, "\n";
  }
  
  # read response content
  $c->read( $buf, 1048576 );
  print $buf;

=head1 METHODS

=over

=item B<new ( [%arg] )>

Additional arguments for the constructor.

=for formatter none

  certificate    Path to certificate file in PEM format
  private_key    Path to private key file in PEM format
  client_ca      Path to PEM formatted file with CA certificates
                 to send to the client
  ca_file        A file of CA certificates in PEM format
  ca_path        A directory containing CA certificates in PEM format

=for formatter perl

Detailed information about the arguments are documented in the functions below.

=item B<set_certificate ( $certificate )>

Adds a certificate chain. The certificates must be in PEM format and must
be sorted starting with the subject`s certificate (actual client or server
certificate), followed by intermediate CA certificates if applicable, and
ending at the highest level (root) CA.

B<Parameters>

=over

=item I<$certificate>

Path to certificate file in PEM format.

=back

B<Return Values>

Returns a TRUE value on sucess or UNDEF on failure.

=item B<set_private_key ( $private_key )>

Adds a private key to the socket.
To change a certificate, private key pair the new certificate needs
to be set before setting the private key.

B<Parameters>

=over

=item I<$private_key>

Path to private key file in PEM format.

=back

B<Return Values>

Returns a TRUE value on sucess or UNDEF on failure.

=item B<check_private_key ()>

Verifies that the private key agrees with the corresponding public key
in the certificate.

Returns a TRUE value on success or UNDEF on failure.

The most likely causes of errors: 

=over

=item * The private key file does not match the corresponding public key
in the certificate. 

=item * A certificate file was not loaded. 

=item * A key file was not loaded. 

=back

=item B<set_client_ca ( $client_ca )>

Reads a file of PEM formatted certificates and sets the list of CA names
sent to the client when requesting a client certificate

B<Parameters>

=over

=item I<$client_ca>

Path to PEM formatted file with CA certificates to send to the client.

=back

B<Return Values>

Returns a true value on sucess or undef on failure.

B<Note>

The CAs listed do not become trusted (list only contains the names, not
the complete certificates); use I<set_verify_locations()> to additionally
load them for verification.

These function is only useful for TLS/SSL servers.

=item B<set_verify_locations ( $ca_file, $ca_path )>

Specifies the locations at which CA certificates for verification purposes
are located.

When building its own certificate chain, an OpenSSL client/server will
try to fill in missing certificates from I<$ca_file>/I<$ca_path>, if the
certificate chain was not explicitly specified.

B<Parameters>

=over

=item I<$ca_file>

If I<$ca_file> is defined, it points to a file of CA certificates in
PEM format. The file can contain several CA certificates identified by 

=for formatter none

 -----BEGIN CERTIFICATE-----
 ... (CA certificate in base64 encoding) ...
 -----END CERTIFICATE-----

=for formatter perl

sequences. Before, between, and after the certificates text is allowed
which can be used e.g. for descriptions of the certificates. 

=item I<$ca_path>

If I<$ca_path> is defined, it points to a directory containing CA
certificates in PEM format. Each file contains one CA certificate.
The files are looked up by the CA subject name hash value, which must
be available. If more than one CA certificate with the same name
hash value exists, the extension must be different
(e.g. 9d66eef0.0, 9d66eef0.1 etc). The search is performed in the order
of the extension numbers, regardless of other properties of the certificates.

=back

When looking up CA certificates, the OpenSSL library will search the
certificates in I<$ca_file> first, then those in $I<ca_path>.
Certificate matching is done based on the subject name, the key
identifier (if present), and the serial number as taken from the certificate
to be verified. If these data do not match, the next certificate will be tried.
The verification process will be performed on the first matching certificate.
In case of failure no other certificates with the same parameters are searched.

B<Return Values>

Returns a true value on success or undef on failure.

B<Note>

In server mode, when requesting a client certificate, the server must
send the list of CAs to accept client certificates. This
list is not influenced by the contents of I<$ca_file> or I<$ca_path>
and must explicitly be set using the I<set_client_ca()> function. 

=item B<create_client_context ()>

Creates a SSL context explicitly for client sockets that supports
Secure Sockets Layer version 2 (SSLv2), Secure Sockets Layer version 3
(SSLv3), and Transport Layer Security version 1 (TLSv1).

The L<connect()|Socket::Class/connect> function implicitly creates the
client context.

=item B<create_server_context ()>

Creates a SSL context explicitly for server sockets that supports
Secure Sockets Layer version 2 (SSLv2), Secure Sockets Layer version 3
(SSLv3), and Transport Layer Security version 1 (TLSv1).

The L<listen()|Socket::Class/listen> function implicitly creates the
server context.

=item B<enable_compatibility ()>

Enables all bug workarounds available in the OpenSSL library.

See L<http://www.openssl.org/docs/ssl/SSL_CTX_set_options.html> for a list.

=item B<get_cipher_name ()>

Returns the name of the cipher in the current connection, or undef if no
connection exists.

=item B<get_cipher_version ()>

Returns the version of the cipher in the current connection, or undef if no
connection exists.

=back

=head1 XS / C API

The module provides a C interface for extension writers.

B<Example XS>

=for formatter cpp

  #include <Socket/Class/SSL/mod_sc_ssl.h>
  
  /* global pointer to the socket class ssl interface */
  mod_sc_ssl_t *g_mod_sc_ssl;
  
  MODULE = MyModule		PACKAGE = MyModule
  
  BOOT:
  {
      SV **psv;
      psv = hv_fetch(PL_modglobal, "Socket::Class::SSL", 18, 0);
      if (psv == NULL)
          croak("Socket::Class::SSL required");
      g_mod_sc_ssl = INT2PTR(mod_sc_ssl_t *, SvIV(*psv));
  }
  
  void
  test()
  PREINIT:
      sc_t *socket;
      char *args[8];
      int r;
      SV *sv;
  PPCODE:
      args[0] = "local_port";
      args[1] = "443";
      args[2] = "listen";
      args[3] = "10";
      args[4] = "private_key";
      args[5] = "/path/to/private_key.pem";
      args[6] = "certificate";
      args[7] = "/path/to/certificate.pem";
      r = g_mod_sc_ssl->sc_create(args, 8, &socket);
      if (r != SC_OK)
          croak(g_mod_sc_ssl->sc_get_error(NULL));
      g_mod_sc_ssl->sc_create_class(socket, NULL, &sv);
      ST(0) = sv_2mortal(sv);
      XSRETURN(1);

=for formatter perl

See I<[sitearch]/auto/Socket/Class/SSL/mod_sc_ssl.h> for the definition.

=head1 SEE ALSO

The L<Socket::Class> manpage

OpenSSL, L<http://www.openssl.org/>

=head1 AUTHORS

Navalla org., Christian Mueller, L<http://www.navalla.org/>

=head1 COPYRIGHT AND LICENSE

This distribution contains multiple components, some of which fall under
different licenses. By using Socket::Class::SSL or any of the bundled
components enumerated below, you agree to be bound by the conditions of
the license foreach respective component.

=head2 Socket::Class::SSL License

The Socket::Class::SSL module is free software. You may distribute under the
terms of either the GNU General Public License or the Artistic License,
as specified in the Perl README file.

=head2 OpenSSL License

=for formatter none

 * ====================================================================
 * Copyright (c) 1998-2008 The OpenSSL Project.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer. 
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. All advertising materials mentioning features or use of this
 *    software must display the following acknowledgment:
 *    "This product includes software developed by the OpenSSL Project
 *    for use in the OpenSSL Toolkit. (http://www.openssl.org/)"
 *
 * 4. The names "OpenSSL Toolkit" and "OpenSSL Project" must not be used to
 *    endorse or promote products derived from this software without
 *    prior written permission. For written permission, please contact
 *    openssl-core@openssl.org.
 *
 * 5. Products derived from this software may not be called "OpenSSL"
 *    nor may "OpenSSL" appear in their names without prior written
 *    permission of the OpenSSL Project.
 *
 * 6. Redistributions of any form whatsoever must retain the following
 *    acknowledgment:
 *    "This product includes software developed by the OpenSSL Project
 *    for use in the OpenSSL Toolkit (http://www.openssl.org/)"
 *
 * THIS SOFTWARE IS PROVIDED BY THE OpenSSL PROJECT ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE OpenSSL PROJECT OR
 * ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 * ====================================================================
 *
 * This product includes cryptographic software written by Eric Young
 * (eay@cryptsoft.com).  This product includes software written by Tim
 * Hudson (tjh@cryptsoft.com).

=for formatter perl

=head2 Original SSLeay License

=for formatter none

 * Copyright (C) 1995-1998 Eric Young (eay@cryptsoft.com)
 * All rights reserved.
 *
 * This package is an SSL implementation written
 * by Eric Young (eay@cryptsoft.com).
 * The implementation was written so as to conform with Netscapes SSL.
 * 
 * This library is free for commercial and non-commercial use as long as
 * the following conditions are aheared to.  The following conditions
 * apply to all code found in this distribution, be it the RC4, RSA,
 * lhash, DES, etc., code; not just the SSL code.  The SSL documentation
 * included with this distribution is covered by the same copyright terms
 * except that the holder is Tim Hudson (tjh@cryptsoft.com).
 * 
 * Copyright remains Eric Young's, and as such any Copyright notices in
 * the code are not to be removed.
 * If this package is used in a product, Eric Young should be given attribution
 * as the author of the parts of the library used.
 * This can be in the form of a textual message at program startup or
 * in documentation (online or textual) provided with the package.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *    "This product includes cryptographic software written by
 *     Eric Young (eay@cryptsoft.com)"
 *    The word 'cryptographic' can be left out if the rouines from the library
 *    being used are not cryptographic related :-).
 * 4. If you include any Windows specific code (or a derivative thereof) from 
 *    the apps directory (application code) you must include an acknowledgement:
 *    "This product includes software written by Tim Hudson (tjh@cryptsoft.com)"
 * 
 * THIS SOFTWARE IS PROVIDED BY ERIC YOUNG ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 * 
 * The licence and distribution terms for any publically available version or
 * derivative of this code cannot be changed.  i.e. this code cannot simply be
 * copied and put under another distribution licence
 * [including the GNU Public Licence.]

=for formatter perl

=cut
