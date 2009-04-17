#include "sc_ssl_mod_def.h"

int mod_sc_ssl_create( char **args, int argc, sc_t **r_socket ) {
	sc_t *socket;
	int r, i, argc2 = 0, listen = 0;
	char *key, *val, **args2, *ra = NULL, *rp = NULL, *la = NULL, *lp = NULL;
	char *domain = NULL, *type = NULL, *proto = NULL;
	char *pk = NULL, *crt = NULL, *cca = NULL;
	char *caf = NULL, *cap = NULL;
	userdata_t *ud;
	if( argc % 2 ) {
		mod_sc->sc_set_errno( NULL, EINVAL );
		return SC_ERROR;
	}
	Newx( args2, argc + 6, char * );
	/* read options */
	for( i = 0; i < argc; ) {
		key = args[i ++];
		val = args[i ++];
		if( my_stricmp( key, "local_addr" ) == 0 ) {
			la = val;
		}
		else if( my_stricmp( key, "local_port" ) == 0 ) {
			lp = val;
		}
		else if( my_stricmp( key, "local_path" ) == 0 ) {
			la = val;
			domain = "unix";
			proto = "0";
		}
		else if( my_stricmp( key, "remote_addr" ) == 0 ) {
			ra = val;
		}
		else if( my_stricmp( key, "remote_port" ) == 0 ) {
			rp = val;
		}
		else if( my_stricmp( key, "remote_path" ) == 0 ) {
			ra = val;
			domain = "unix";
			proto = "0";
		}
		else if( my_stricmp( key, "private_key" ) == 0 ) {
			pk = val;
		}
		else if( my_stricmp( key, "certificate" ) == 0 ) {
			crt = val;
		}
		else if( my_stricmp( key, "client_ca" ) == 0 ) {
			cca = val;
		}
		else if( my_stricmp( key, "ca_file" ) == 0 ) {
			caf = val;
		}
		else if( my_stricmp( key, "ca_path" ) == 0 ) {
			cap = val;
		}
		else if(
			my_stricmp( key, "domain" ) == 0 ||
			my_stricmp( key, "family" ) == 0
		) {
			domain = val;
		}
		else if( my_stricmp( key, "proto" ) == 0 ) {
			proto = val;
		}
		else if( my_stricmp( key, "type" ) == 0 ) {
			type = val;
		}
		else if( my_stricmp( key, "listen" ) == 0 ) {
			listen = atoi( val );
		}
		else {
			args2[argc2 ++] = key;
			args2[argc2 ++] = val;
		}
	}
	if( domain != NULL ) {
		args2[argc2 ++] = "domain";
		args2[argc2 ++] = domain;
	}
	if( type != NULL ) {
		args2[argc2 ++] = "type";
		args2[argc2 ++] = type;
	}
	if( proto != NULL ) {
		args2[argc2 ++] = "proto";
		args2[argc2 ++] = proto;
	}
	r = mod_sc->sc_create( args2, argc2, &socket );
	Safefree( args2 );
	if( r != SC_OK )
		return r;
	Newxz( ud, 1, userdata_t );
	mod_sc->sc_set_userdata( socket, ud, free_userdata );
	if( pk != NULL ) {
		r = mod_sc_ssl_set_private_key( socket, pk );
		if( r != SC_OK )
			goto error;
	}
	if( crt != NULL ) {
		r = mod_sc_ssl_set_certificate( socket, crt );
		if( r != SC_OK )
			goto error;
	}
	if( cca != NULL ) {
		r = mod_sc_ssl_set_client_ca( socket, cca);
		if( r != SC_OK )
			goto error;
	}
	if( caf != NULL || cap != NULL ) {
		r = mod_sc_ssl_set_verify_locations( socket, caf, cap );
		if( r != SC_OK )
			goto error;
	}
	if( la != NULL || lp != NULL || listen ) {
		r = mod_sc->sc_bind( socket, la, lp );
		if( r != SC_OK )
			goto error;
	}
	if( listen ) {
		r = mod_sc_ssl_listen( socket, listen );
		if( r != SC_OK )
			goto error;
	}
	else if( ra != NULL || rp != NULL ) {
		r = mod_sc_ssl_connect( socket, ra, rp, 0 );
		if( r != SC_OK )
			goto error;
	}
	*r_socket = socket;
	return SC_OK;
error:
	mod_sc->sc_set_error( NULL,
		mod_sc->sc_get_errno( socket ), mod_sc->sc_get_error( socket )
	);
	mod_sc->sc_destroy( socket );
	return r;
}

int mod_sc_ssl_connect(
	sc_t *socket, const char *host, const char *serv, double timeout
) {
	userdata_t *ud;
	int r, err;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	r = mod_sc->sc_connect( socket, host, serv, timeout );
	if( r != SC_OK )
		return r;
	r = mod_sc_ssl_create_client_context( socket );
	if( r != SC_OK )
		return r;
	/*
	if( ud->private_key != NULL ) {
		r = mod_sc_ssl_check_private_key( socket );
		if( r != SC_OK )
			return r;
	}
	*/
	/* get new SSL state with context */
	ud->ssl = SSL_new( ud->ctx );
	/* set connection to SSL state */
	SSL_set_fd( ud->ssl, (int) mod_sc->sc_get_handle( socket ) );
	/* start the handshaking */
	r = SSL_connect( ud->ssl );
	if( r <= 0 ) {
		r = SSL_get_error( ud->ssl, r );
		err = ERR_get_error();
		if( err == 0 )
			mod_sc->sc_set_error( socket, r, my_ssl_error( r ) );
		else
			mod_sc->sc_set_error( socket, err, ERR_reason_error_string( err ) );
		return SC_ERROR;
	}
	return SC_OK;
}

int mod_sc_ssl_listen( sc_t *socket, int queue ) {
	int r;
	userdata_t *ud;
	r = mod_sc_ssl_create_server_context( socket );
	if( r != SC_OK )
		return r;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->private_key == NULL ) {
		r = mod_sc_ssl_set_certificate( socket, SC_SSL_DEFAULT_CRT );
		if( r != SC_OK )
			return r;
		r = mod_sc_ssl_set_private_key( socket, SC_SSL_DEFAULT_KEY );
		if( r != SC_OK )
			return r;
	}
	/*
	r = mod_sc_ssl_check_private_key( socket );
	if( r != SC_OK )
		return r;
	*/
	return mod_sc->sc_listen( socket, queue );
}

int mod_sc_ssl_accept( sc_t *socket, sc_t **r_client ) {
	sc_t *client;
	userdata_t *ud, *udc;
	int r, err;
	r = mod_sc->sc_accept( socket, &client );
	if( r != SC_OK )
		return SC_ERROR;
	if( client == NULL ) {
		*r_client = NULL;
		return SC_OK;
	}
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	Newxz( udc, 1, userdata_t );
	mod_sc->sc_set_userdata( client, udc, free_userdata );
	/* get new SSL state with context */
	udc->ssl = SSL_new( ud->ctx );
	/* set connection to SSL state */
	SSL_set_fd( udc->ssl, (int) mod_sc->sc_get_handle( client ) );
	/* start the handshaking */
	r = SSL_accept( udc->ssl );
	if( r < 0 ) {
		r = SSL_get_error( ud->ssl, r );
		err = ERR_get_error();
		if( err == 0 )
			mod_sc->sc_set_error( socket, r, my_ssl_error( r ) );
		else
			mod_sc->sc_set_error( socket, err, ERR_reason_error_string( err ) );
		mod_sc->sc_destroy( client );
		return SC_ERROR;
	}
#ifdef SC_DEBUG
	_debug( "cipher name %s\n", SSL_get_cipher_name( udc->ssl ) );
	_debug( "cipher version %s\n", SSL_get_cipher_version( udc->ssl ) );
#endif
	*r_client = client;
	return SC_OK;
}

int mod_sc_ssl_recv( sc_t *socket, char *buf, int len, int flags, int *p_len ) {
	userdata_t *ud;
	int r, err, len2 = 0;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL ) {
		mod_sc->sc_set_errno( socket, ENOTCONN );
		return SC_ERROR;
	}
	if( ud->rcvbuf_pos > 0 ) {
		/* read from rcvbuf */
		len2 = ud->rcvbuf_pos < len ? ud->rcvbuf_pos : len;
#ifdef SC_DEBUG
		_debug( "read %d bytes from internal buffer\n", len2 );
#endif
		Copy( ud->rcvbuf, buf, len2, char );
		if( (flags & MSG_PEEK) == 0 ) {
			ud->rcvbuf_pos -= len2;
			if( ud->rcvbuf_pos > 0 )
				memmove( ud->rcvbuf, ud->rcvbuf + len2, ud->rcvbuf_pos );
		}
		len -= len2;
		if( len == 0 || ! SSL_pending( ud->ssl ) ) {
			*p_len = len2;
			return SC_OK;
		}
	}
	if( flags & MSG_PEEK ) {
		if( ud->rcvbuf_len < len + ud->rcvbuf_pos ) {
			ud->rcvbuf_len = len + ud->rcvbuf_pos;
			Renew( ud->rcvbuf, ud->rcvbuf_len, char );
		}
#ifdef SC_DEBUG
		_debug( "read %d bytes into internal buffer\n", len );
#endif
		r = SSL_read( ud->ssl, ud->rcvbuf + ud->rcvbuf_pos, len );
	}
	else {
#ifdef SC_DEBUG
		_debug( "read %d bytes\n", len );
#endif
		r = SSL_read( ud->ssl, buf + len2, len );
	}
#ifdef SC_DEBUG
	_debug( "got %d bytes from SSL_read\n", r );
#endif
	if( r <= 0 ) {
		r = SSL_get_error( ud->ssl, r );
		if( r == SSL_ERROR_WANT_READ ) {
			*p_len = len2;
			return SC_OK;
		}
		err = ERR_get_error();
		if( err == 0 )
			mod_sc->sc_set_error( socket, r, my_ssl_error( r ) );
		else
			mod_sc->sc_set_error( socket, err, ERR_reason_error_string( err ) );
		mod_sc->sc_set_state( socket, SC_STATE_ERROR );
		return SC_ERROR;
	}
	if( flags & MSG_PEEK ) {
		Copy( ud->rcvbuf + ud->rcvbuf_pos, buf + len2, r, char );
		ud->rcvbuf_pos += r;
	}
	*p_len = len2 + r;
	return SC_OK;
}

int mod_sc_ssl_send(
	sc_t *socket, const char *buf, int len, int flags, int *p_len
) {
	userdata_t *ud;
	int r, err;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL ) {
		mod_sc->sc_set_errno( socket, ENOTCONN );
		return SC_ERROR;
	}
#ifdef SC_DEBUG
	_debug( "write %d bytes\n", len );
#endif
	r = SSL_write( ud->ssl, buf, len );
#ifdef SC_DEBUG
	_debug( "wrote %d bytes\n", r );
#endif
	if( r <= 0 ) {
		r = SSL_get_error( ud->ssl, r );
		if( r == SSL_ERROR_WANT_WRITE ) {
			*p_len = 0;
			return SC_OK;
		}
		err = ERR_get_error();
		if( err == 0 )
			mod_sc->sc_set_error( socket, r, my_ssl_error( r ) );
		else
			mod_sc->sc_set_error( socket, err, ERR_reason_error_string( err ) );
		mod_sc->sc_set_state( socket, SC_STATE_ERROR );
		return SC_ERROR;
	}
	*p_len = r;
	return SC_OK;
}

int mod_sc_ssl_recvfrom(
	sc_t *sock, char *buf, int len, int flags, int *p_len
) {
	mod_sc->sc_set_error(
		sock, -9999, "recvfrom() is not available on SSL sockets" );
	return SC_ERROR;
}

int mod_sc_ssl_sendto(
	sc_t *sock, const char *buf, int len, int flags, sc_addr_t *peer,
	int *p_len
) {
	mod_sc->sc_set_error(
		sock, -9999, "sendto() is not available on SSL sockets" );
	return SC_ERROR;
}

int mod_sc_ssl_read( sc_t *socket, char *buf, int len, int *p_len ) {
	return mod_sc_ssl_recv( socket, buf, len, 0, p_len );
}

int mod_sc_ssl_write( sc_t *socket, const char *buf, int len, int *p_len ) {
	return mod_sc_ssl_send( socket, buf, len, 0, p_len );
}

int mod_sc_ssl_readline( sc_t *socket, char **p_buf, int *p_len ) {
	userdata_t *ud;
	int r, l;
	size_t i, pos = 0, len = 256;
	char *p, ch;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	p = ud->buffer;
	while( 1 ) {
		if( ud->buffer_len < (int) (pos + len) ) {
			ud->buffer_len = (int) (pos + len);
			Renew( ud->buffer, ud->buffer_len, char );
			p = ud->buffer + pos;
		}
		r = mod_sc_ssl_recv( socket, p, (int) len, MSG_PEEK, &l );
		if( r != SC_OK ) {
			if( pos > 0 )
				break;
			return SC_ERROR;
		}
		if( l == 0 ) {
			*p_buf = ud->buffer;
			*p_len = (int) pos;
			return SC_OK;
		}
		for( i = 0; i < (size_t) l; i ++, p ++ ) {
			if( *p != '\n' && *p != '\r' && *p != '\0' )
				continue;
			/* found newline */
#ifdef SC_DEBUG
			_debug( "found newline at %d + %d of %d\n", pos, i, l );
#endif
			ch = *p;
			*p = '\0';
			*p_buf = ud->buffer;
			*p_len = (int) (pos + i);
			if( ch == '\r' || ch == '\n' ) {
				if( i < (size_t) l ) {
					if( p[1] == (ch == '\r' ? '\n' : '\r') )
						i ++;
				}
				else if( l == (int) len ) {
					r = mod_sc_ssl_recv( socket, p, 1, MSG_PEEK, &l );
					if( r == SC_OK && l == 1 &&
						*p == (ch == '\r' ? '\n' : '\r')
					) {
						mod_sc_ssl_recv( socket, p, 1, 0, &l );
					}
				}
			}
			mod_sc_ssl_recv( socket, ud->buffer + pos, (int) i + 1, 0, &l );
			return SC_OK;
		}
		mod_sc_ssl_recv( socket, ud->buffer + pos, (int) i, 0, &l );
		pos += i;
		if( r < (int) len )
			break;
	}
	ud->buffer[pos] = '\0';
	*p_buf = ud->buffer;
	*p_len = (int) pos;
	return SC_OK;
}

int mod_sc_ssl_writeln( sc_t *socket, const char *buf, int len, int *p_len ) {
	userdata_t *ud;
	char *p;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( len <= 0 )
		len = (int) strlen( buf );
	if( ud->buffer_len < len + 2 ) {
		ud->buffer_len = len + 2;
		Renew( ud->buffer, len, char );
	}
	p = ud->buffer;
	Copy( buf, p, len, char );
	p[len ++] = '\r';
	p[len ++] = '\n';
	return mod_sc_ssl_send( socket, p, len, 0, p_len );
}

int mod_sc_ssl_printf( sc_t *socket, const char *fmt, ... ) {
	int r;
	va_list vl;
	va_start( vl, fmt );
	r = mod_sc_ssl_vprintf( socket, fmt, vl );
	va_end( vl );
	return r;
}

int mod_sc_ssl_vprintf( sc_t *socket, const char *fmt, va_list vl ) {
	const char *s, *s2;
	char *tmp;
	int isbig, size = (int) strlen( fmt ) + 64, r;
	va_list vlc;
#if defined (va_copy)
	va_copy( vlc, vl );
#elif defined (__va_copy)
	__va_copy( vlc, vl );
#else
	vlc = vl;
#endif
	for( s = fmt; *s != '\0'; s ++ ) {
		if( *s != '%' )
			continue;
		s ++;
		if( *s == '%' )
			continue;
		for( ; *s < 'a' || *s > 'z'; s ++ ) {
			if( *s == '\0' )
				goto finish;
		}
		isbig = 0;
again:
		switch( *s ) {
		case 'l':
			isbig = 1;
			s ++;
			goto again;
		case 'c':
		case 'C':
			va_arg( vlc, int );
			size += 4;
			break;
		case 'd':
		case 'i':
		case 'u':
		case 'o':
		case 'x':
		case 'X':
			if( isbig ) {
				va_arg( vlc, XLONG );
				size += sizeof( XLONG ) / 2 * 5 + 1;
			}
			else {
				va_arg( vlc, long );
				size += sizeof( long ) / 2 * 5 + 1;
			}
			break;
		case 'a':
		case 'A':
		case 'e':
		case 'E':
		case 'f':
		case 'g':
		case 'G':
			if( isbig ) {
				va_arg( vlc, long double );
				size += 128;
			}
			else {
				va_arg( vlc, double );
				size += 64;
			}
			break;
		case 's':
		case 'S':
			s2 = va_arg( vlc, const char * );
			size += (int) strlen( s2 );
			break;
		case 'p':
			s2 = va_arg( vlc, const void * );
			size += sizeof( void * ) / 2 * 5;
			break;
		}
	}
finish:
	va_end( vlc );
#ifdef SC_DEBUG
	_debug( "vprintf size %u\n", size );
#endif
	Newx( tmp, size, char );
	size = vsnprintf( tmp, size, fmt, vl );
#ifdef SC_DEBUG
	_debug( "vprintf size %u\n", size );
#endif
	r = mod_sc_ssl_send( socket, tmp, size, 0, &size );
	Safefree( tmp );
	return r;
}

int mod_sc_ssl_available( sc_t *socket, int *p_len ) {
	userdata_t *ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL ) {
		mod_sc->sc_set_errno( socket, ENOTCONN );
		return SC_ERROR;
	}
	*p_len = SSL_pending( ud->ssl );
	return SC_OK;
}

void mod_sc_ssl_set_userdata( sc_t *socket, void *p, void (*free) (void *p) ) {
	userdata_t *ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	ud->user_data = p;
	ud->free_user_data = free;
}

void *mod_sc_ssl_get_userdata( sc_t *socket ) {
	userdata_t *ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	return ud->user_data;
}

int mod_sc_ssl_set_private_key( sc_t *socket, const char *s ) {
	userdata_t *ud;
	int r, l;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	l = (int) strlen( s );
	Renew( ud->private_key, l + 1, char );
	Copy( s, ud->private_key, l + 1, char );
	if( ud->ctx != NULL ) {
		/* set the private key from KeyFile */
#ifdef SC_DEBUG
		_debug( "use private key from '%s'\n", ud->private_key );
#endif
		r = SSL_CTX_use_PrivateKey_file(
			ud->ctx, ud->private_key, SSL_FILETYPE_PEM );
		if( ! r )
			goto error;
	}
	return SC_OK;
error:
	r = ERR_get_error();
	mod_sc->sc_set_error( socket, r, ERR_reason_error_string( r ) );
	return SC_ERROR;
}

int mod_sc_ssl_set_certificate( sc_t *socket, const char *s ) {
	userdata_t *ud;
	int r, l;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	l = (int) strlen( s );
	Renew( ud->certificate, l + 1, char );
	Copy( s, ud->certificate, l + 1, char );
	if( ud->ctx != NULL ) {
		/* set the local certificate from CertFile */
#ifdef SC_DEBUG
		_debug( "use certificate from '%s'\n", ud->certificate );
#endif
		r = SSL_CTX_use_certificate_chain_file(
			ud->ctx, ud->certificate );
		if( ! r )
			goto error;
	}
	return SC_OK;
error:
	r = ERR_get_error();
	mod_sc->sc_set_error( socket, r, ERR_reason_error_string( r ) );
	return SC_ERROR;
}

int mod_sc_ssl_set_client_ca( sc_t *socket, const char *s ) {
	int l;
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	l = (int) strlen( s );
	Renew( ud->client_ca, l + 1, char );
	Copy( s, ud->client_ca, l + 1, char );
	if( ud->ctx != NULL ) {
		SSL_CTX_set_client_CA_list(
			ud->ctx, SSL_load_client_CA_file( ud->client_ca ) );
	}
	return SC_OK;
}

int mod_sc_ssl_set_verify_locations(
	sc_t *socket, const char *cafile, const char *capath
) {
	userdata_t *ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	int r;
	if( cafile != NULL ) {
		r = (int) strlen( cafile );
		Renew( ud->ca_file, r + 1, char );
		Copy( cafile, ud->ca_file, r + 1, char );
	}
	else if( ud->ca_file != NULL ) {
		Safefree( ud->ca_file );
		ud->ca_file = NULL;
	}
	if( capath != NULL ) {
		r = (int) strlen( capath );
		Newx( ud->ca_path, r + 1, char );
		Copy( capath, ud->ca_path, r + 1, char );
	}
	else if( ud->ca_path != NULL ) {
		Safefree( ud->ca_path );
		ud->ca_path = NULL;
	}
	if( ud->ctx != NULL ) {
		r = SSL_CTX_load_verify_locations( ud->ctx, cafile, capath );
		if( ! r )
			goto error;
	}
	return SC_OK;
error:
	r = ERR_get_error();
	mod_sc->sc_set_error( socket, r, ERR_reason_error_string( r ) );
	return SC_ERROR;
}

int mod_sc_ssl_shutdown( sc_t *socket ) {
	userdata_t *ud;
	int r, err;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl != NULL ) {
		r = SSL_shutdown( ud->ssl );
		if( r <= 0 ) {
			r = SSL_get_error( ud->ssl, r );
			err = ERR_get_error();
			if( err == 0 )
				mod_sc->sc_set_error( socket, r, my_ssl_error( r ) );
			else
				mod_sc->sc_set_error( socket, err, ERR_reason_error_string( err ) );
			return SC_ERROR;
		}
	}
	return SC_OK;
}

int mod_sc_ssl_create_client_context( sc_t *socket ) {
	userdata_t *ud;
	int r;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl != NULL ) {
		mod_sc->sc_close( socket );
		SSL_free( ud->ssl );
		ud->ssl = NULL;
	}
	if( ud->method != SSLv23_client_method() ) {
		if( ud->ctx != NULL )
			SSL_CTX_free( ud->ctx );
		/* create ssl instance */
		ud->method = SSLv23_client_method();
		/* create context */
		ud->ctx = SSL_CTX_new( ud->method );
		/* load verify locations */
		if( ud->ca_file != NULL || ud->ca_path != NULL ) {
			r = SSL_CTX_load_verify_locations(
				ud->ctx, ud->ca_file, ud->ca_path );
			if( ! r )
				goto error;
		}
		if( ud->certificate != NULL ) {
			/* set the local certificate from CertFile */
#ifdef SC_DEBUG
			_debug( "use certificate from '%s'\n", ud->certificate );
#endif
			r = SSL_CTX_use_certificate_file(
				ud->ctx, ud->certificate, SSL_FILETYPE_PEM );
			if( ! r )
				goto error;
		}
		if( ud->private_key != NULL ) {
			/* set the private key from KeyFile */
#ifdef SC_DEBUG
			_debug( "use private key from '%s'\n", ud->private_key );
#endif
			r = SSL_CTX_use_PrivateKey_file(
				ud->ctx, ud->private_key, SSL_FILETYPE_PEM );
			if( ! r )
				goto error;
		}
		/* set auto retry */
		SSL_CTX_set_mode( ud->ctx, SSL_MODE_AUTO_RETRY );
	}
	return SC_OK;
error:
	r = ERR_get_error();
	mod_sc->sc_set_error( socket, r, ERR_reason_error_string( r ) );
	return SC_ERROR;
}

int mod_sc_ssl_create_server_context( sc_t *socket ) {
	userdata_t *ud;
	int r;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl != NULL ) {
		mod_sc->sc_close( socket );
		SSL_free( ud->ssl );
		ud->ssl = NULL;
	}
	if( ud->method != SSLv23_server_method() ) {
		if( ud->ctx != NULL )
			SSL_CTX_free( ud->ctx );
		/* create ssl instance */
		ud->method = SSLv23_server_method();
		/* create context */
		ud->ctx = SSL_CTX_new( ud->method );
		/* load verify locations */
		if( ud->ca_file != NULL || ud->ca_path != NULL ) {
			r = SSL_CTX_load_verify_locations(
				ud->ctx, ud->ca_file, ud->ca_path );
			if( ! r )
				goto error;
		}
		if( ud->client_ca != NULL ) {
			/* set the client ca */
#ifdef SC_DEBUG
			_debug( "use client ca from '%s'\n", ud->client_ca );
#endif
			SSL_CTX_set_client_CA_list(
				ud->ctx, SSL_load_client_CA_file( ud->client_ca ) );
		}
		if( ud->certificate != NULL ) {
			/* set the local certificate from CertFile */
#ifdef SC_DEBUG
			_debug( "use certificate from '%s'\n", ud->certificate );
#endif
			r = SSL_CTX_use_certificate_file(
				ud->ctx, ud->certificate, SSL_FILETYPE_PEM );
			if( ! r )
				goto error;
		}
		if( ud->private_key != NULL ) {
			/* set the private key from KeyFile */
#ifdef SC_DEBUG
			_debug( "use private key from '%s'\n", ud->private_key );
#endif
			r = SSL_CTX_use_PrivateKey_file(
				ud->ctx, ud->private_key, SSL_FILETYPE_PEM );
			if( ! r )
				goto error;
		}
		/* set auto retry */
		SSL_CTX_set_mode( ud->ctx, SSL_MODE_AUTO_RETRY );
	}
	return SC_OK;
error:
	r = ERR_get_error();
	mod_sc->sc_set_error( socket, r, ERR_reason_error_string( r ) );
	return SC_ERROR;
}

int mod_sc_ssl_check_private_key( sc_t *socket ) {
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ctx == NULL ) {
		mod_sc->sc_set_error( socket, -9999, "Invalid context" );
		return SC_ERROR;
	}
	/* verify private key */
	if( ! SSL_CTX_check_private_key( ud->ctx ) ) {
#ifdef SC_DEBUG
		_debug( "!!! invalid private key !!!\n" );
#endif
		mod_sc->sc_set_error( socket, -9999, "Invalid private key" );
		return SC_ERROR;
	}
	return SC_OK;
}

int mod_sc_ssl_enable_compatibility( sc_t *socket ) {
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ctx == NULL ) {
		mod_sc->sc_set_error( socket, -9999, "Invalid context" );
		return SC_ERROR;
	}
	SSL_CTX_set_options( ud->ctx, SSL_OP_ALL );
	return SC_OK;
}

const char *mod_sc_ssl_get_cipher_name( sc_t *socket ) {
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL )
		return NULL;
	return SSL_get_cipher_name( ud->ssl );
}

const char *mod_sc_ssl_get_cipher_version( sc_t *socket ) {
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL )
		return NULL;
	return SSL_get_cipher_version( ud->ssl );
}

const char *mod_sc_ssl_get_version( sc_t *socket ) {
	userdata_t *ud;
	ud = (userdata_t *) mod_sc->sc_get_userdata( socket );
	if( ud->ssl == NULL )
		return NULL;
	return SSL_get_version( ud->ssl );
}

void free_userdata( void *p ) {
	userdata_t *ud = (userdata_t *) p;
	if( ud->user_data != NULL && ud->free_user_data != NULL )
		ud->free_user_data( ud->user_data );
#ifdef SC_DEBUG
	_debug( "free userdata\n" );
#endif
	if( ud->ctx != NULL )
		SSL_CTX_free( ud->ctx );
	if( ud->ssl != NULL )
		SSL_free( ud->ssl );
	Safefree( ud->rcvbuf );
	Safefree( ud->buffer );
	Safefree( ud->private_key );
	Safefree( ud->certificate );
	Safefree( ud->client_ca );
	Safefree( ud->ca_file );
	Safefree( ud->ca_path );
	Safefree( ud );
}

const char *my_ssl_error( int code ) {
	switch( code ) {
	case SSL_ERROR_NONE:
		return "No error";
	case SSL_ERROR_SSL:
		return "SSL library error, usually a protocol error";
	case SSL_ERROR_WANT_READ:
		return "The read operation did not complete";
	case SSL_ERROR_WANT_WRITE:
		return "The write operation did not complete";
	case SSL_ERROR_SYSCALL:
		return "Some I/O error occurred";
#ifdef SSL_ERROR_ZERO_RETURN
	case SSL_ERROR_ZERO_RETURN:
		return "The TLS/SSL connection has been closed";
#endif
#ifdef SSL_ERROR_WANT_X509_LOOKUP
	case SSL_ERROR_WANT_X509_LOOKUP:
		return "The operation did not complete because an application"
			" callback has asked to be called again";
#endif
#ifdef SSL_ERROR_WANT_CONNECT
	case SSL_ERROR_WANT_CONNECT:
		return "The connect operation did not complete";
#endif
#ifdef SSL_ERROR_WANT_ACCEPT
	case SSL_ERROR_WANT_ACCEPT:
		return "The accept operation did not complete";
#endif
	default:
		return "Unknown TLS/SSL error";
	}
}

char *my_strcpy( char *dst, const char *src ) {
	register char ch;
	while( 1 ) {
		if( (ch = *src ++) == '\0' ) {
			break;
		}
		*dst ++ = ch;
	}
	*dst = '\0';
	return dst;
}

int my_stricmp( const char *cs, const char *ct ) {
	register signed char res;
	while( 1 ) {
		if( (res = toupper( *cs ) - toupper( *ct ++ )) != 0 || ! *cs ++ )
			break;
	}
	return res;
}

#ifdef SC_DEBUG

int my_debug( const char *fmt, ... ) {
	va_list a;
	int r;
	size_t l;
	char *tmp, *s1;
	l = strlen( fmt );
	tmp = malloc( 64 + l );
	s1 = my_strcpy( tmp, "[Socket::Class::SSL] " );
	s1 = my_strcpy( s1, fmt );
	va_start( a, fmt );
	r = vfprintf( stderr, tmp, a );
	fflush( stderr );
	va_end( a );
	free( tmp );
	return r;
}

#if SC_DEBUG > 1

HV					*hv_dbg_mem = NULL;
perl_mutex			dbg_mem_lock;
int					dbg_lock = FALSE;

void debug_init() {
	_debug( "init memory debugger\n" );
	MUTEX_INIT( &dbg_mem_lock );
	hv_dbg_mem = newHV();
	SvSHARE( (SV *) hv_dbg_mem );
	dbg_lock = TRUE;
}

void debug_free() {
	SV *sv_val;
	char *key, *val;
	I32 klen;
	STRLEN lval;
	_debug( "hv_dbg_mem entries %u\n", HvKEYS( hv_dbg_mem ) );
	if( HvKEYS( hv_dbg_mem ) ) {
		hv_iterinit( hv_dbg_mem );
		while( (sv_val = hv_iternextsv( hv_dbg_mem, &key, &klen )) != NULL ) {
			val = SvPV( sv_val, lval );
			_debug( "unfreed memory from %s\n", val );
		}
	}
	sv_2mortal( (SV *) hv_dbg_mem );
	dbg_lock = FALSE;
	MUTEX_DESTROY( &dbg_mem_lock );
}

#endif /* SC_DEBUG > 1 */

#endif /* SC_DEBUG */
