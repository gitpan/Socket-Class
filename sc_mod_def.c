#include "socket_class.h"
#include "sc_mod_def.h"

int mod_sc_create( char **args, int argc, sc_t **p_sc ) {
	socket_class_t *sc;
	char *key, *val, **arge;
	char *la = NULL, *ra = NULL, *lp = NULL, *rp = NULL;
	double tmo = -1;
	int r, ln = 0, bc = 0, bl = 1, rua = 0;
	fd_set fds;
	socklen_t sl;

	if( argc % 2 ) {
		GLOBAL_ERROR( -1, "invalid arguments" );
		return SC_ERROR;
	}
	Newxz( sc, 1, socket_class_t );
	sc->s_domain = AF_INET;
	sc->s_type = SOCK_STREAM;
	sc->s_proto = IPPROTO_TCP;
	sc->timeout.tv_sec = 15;
	/* read options */
	for( arge = args + argc; args < arge; ) {
		key = *args ++;
		val = *args ++;
		if( my_stricmp( key, "domain" ) == 0 ||
			my_stricmp( key, "family" ) == 0
		) {
			sc->s_domain = Socket_domainbyname( val );
			if( sc->s_domain == AF_UNIX ) {
				sc->s_proto = 0;
			}
			else if( sc->s_domain == AF_BLUETOOTH ) {
				sc->s_proto = BTPROTO_RFCOMM;
			}
		}
		else if( my_stricmp( key, "type" ) == 0 ) {
			sc->s_type = Socket_typebyname( val );
		}
		else if( my_stricmp( key, "proto" ) == 0 ) {
			sc->s_proto = Socket_protobyname( val );
			if( sc->s_proto == IPPROTO_UDP ) {
				sc->s_type = SOCK_DGRAM;
			}
		}
		else if( my_stricmp( key, "local_addr" ) == 0 ) {
			la = val;
			if( lp == NULL )
				lp = "0";
		}
		else if( my_stricmp( key, "local_path" ) == 0 ) {
			la = val;
			sc->s_domain = AF_UNIX;
			sc->s_proto = 0;
		}
		else if( my_stricmp( key, "local_port" ) == 0 ) {
			lp = val;
		}
		else if( my_stricmp( key, "remote_addr" ) == 0 ) {
			ra = val;
		}
		else if( my_stricmp( key, "remote_path" ) == 0 ) {
			ra = val;
			sc->s_domain = AF_UNIX;
			sc->s_proto = 0;
		}
		else if( my_stricmp( key, "remote_port" ) == 0 ) {
			rp = val;
		}
		else if( my_stricmp( key, "listen" ) == 0 ) {
			ln = (int) atoi( val );
			if( ln < 0 || ln > SOMAXCONN )
				ln = SOMAXCONN;
		}
		else if( my_stricmp( key, "blocking" ) == 0 ) {
			bl = val != NULL && *val != '0';
		}
		else if( my_stricmp( key, "broadcast" ) == 0 ) {
			bc = val != NULL && *val != '0';
		}
		else if( my_stricmp( key, "reuseaddr" ) == 0 ) {
			rua = val != NULL && *val != '0';
		}
		else if( my_stricmp( key, "timeout" ) == 0 ) {
			tmo = atof( val );
		}
	}
	/* create the socket */
	sc->sock = socket( sc->s_domain, sc->s_type, sc->s_proto );
	if( sc->sock == INVALID_SOCKET ) {
#ifdef SC_DEBUG
		_debug( "socket(%d,%d,%d) create error %d\n",
			sc->s_domain, sc->s_type, sc->s_proto, sc->sock );
#endif
		goto error;
	}
	/* set socket options */
	if( bc &&
		setsockopt(
			sc->sock, SOL_SOCKET, SO_BROADCAST, (void *) &bc, sizeof( int )
		) == SOCKET_ERROR
	) goto error;
	if( rua &&
		setsockopt(
			sc->sock, SOL_SOCKET, SO_REUSEADDR, (void *) &rua, sizeof( int )
		) == SOCKET_ERROR
	) goto error;
	/* set timeout */
	if( tmo >= 0 ) {
		sc->timeout.tv_sec = (long) (tmo / 1000.0);
		sc->timeout.tv_usec = (long) (sc->timeout.tv_sec * 1000 - tmo) * 1000;
	}
	/* bind and listen */
	if( la != NULL || lp != NULL || ln != 0 ) {
		switch( sc->s_domain ) {
		case AF_INET:
		case AF_INET6:
		default:
			r = Socket_setaddr_INET( sc, la, lp, ADDRUSE_LISTEN );
			if( r < 0 ) {
#ifndef _WIN32
				GLOBAL_ERROR( r, sc->last_error );
#else
				GLOBAL_ERRNO( r );
#endif
				goto error2;
			}
			else if( r != 0 ) {
				GLOBAL_ERRNO( r );
				goto error2;
			}
			break;
		case AF_UNIX:
			remove( la );
			Socket_setaddr_UNIX( &sc->l_addr, la );
			break;
		}
#ifdef SC_DEBUG
		_debug( "bind socket %d\n", sc->sock );
#endif
		if( bind(
				sc->sock, (struct sockaddr *) sc->l_addr.a, sc->l_addr.l
			) == SOCKET_ERROR
		) goto error;
		sc->state = SC_STATE_BOUND;
		sc->l_addr.l = SOCKADDR_SIZE_MAX;
		getsockname( sc->sock, (struct sockaddr *) sc->l_addr.a, &sc->l_addr.l );
		if( ln != 0 ) {
#ifdef SC_DEBUG
			_debug( "listen on %s %s\n", la, lp );
#endif
			if( listen( sc->sock, ln ) == SOCKET_ERROR )
				goto error;
			sc->state = SC_STATE_LISTEN;
		}
	}
	/* connect */
	if( ra != NULL || rp != NULL ) {
		switch( sc->s_domain ) {
		case AF_INET:
		case AF_INET6:
		default:
			r = Socket_setaddr_INET( sc, ra, rp, ADDRUSE_CONNECT );
			if( r < 0 ) {
#ifndef _WIN32
				GLOBAL_ERROR( r, sc->last_error );
#else
				GLOBAL_ERRNO( r );
#endif
				goto error2;
			}
			else if( r != 0 ) {
				GLOBAL_ERRNO( r );
				goto error2;
			}
			break;
		case AF_UNIX:
			Socket_setaddr_UNIX( &sc->r_addr, ra );
			break;
		}
		if( Socket_setblocking( sc->sock, 0 ) == SOCKET_ERROR )
			goto error;
#ifdef SC_DEBUG
		_debug( "connect to %s %s\n", ra, rp );
#endif
		if( connect(
				sc->sock, (struct sockaddr *) sc->r_addr.a, sc->r_addr.l
			) == SOCKET_ERROR
		) {
			r = Socket_errno();
			if( r == EINPROGRESS || r == EWOULDBLOCK ) {
				FD_ZERO( &fds ); 
				FD_SET( sc->sock, &fds );
				if( select(
						(int) (sc->sock + 1), NULL, &fds, NULL, &sc->timeout
					) > 0
				) {
					sl = sizeof( int );
					if( getsockopt(
							sc->sock, SOL_SOCKET, SO_ERROR, (void *) (&r), &sl
						) == SOCKET_ERROR
					) {
						goto error;
					}
					if( r ) {
#ifdef SC_DEBUG
						_debug( "getsockopt SO_ERROR %d\n", r );
#endif
						GLOBAL_ERRNO( r );
						goto error2;
					}
				}
				else {
#ifdef SC_DEBUG
					_debug( "connect timed out %u\n", ETIMEDOUT );
#endif
					GLOBAL_ERRNO( ETIMEDOUT );
					goto error2;
				}	
			}
			else {
#ifdef SC_DEBUG
				_debug( "connect failed %d\n", r );
#endif
				GLOBAL_ERRNO( r );
				goto error2;
			}
		}
		if( bl ) {
			if( Socket_setblocking( sc->sock, 1 ) == SOCKET_ERROR )
				goto error;
		}
		else
			sc->non_blocking = 1;
		sc->l_addr.l = SOCKADDR_SIZE_MAX;
		getsockname( sc->sock, (struct sockaddr *) sc->l_addr.a, &sc->l_addr.l );
		sc->state = SC_STATE_CONNECTED;
	}
	if( ! bl && ! sc->non_blocking ) {
		if( Socket_setblocking( sc->sock, 0 ) == SOCKET_ERROR )
			goto error;
		sc->non_blocking = 1;
	}
	GLOBAL_ERROR( 0, "" );
	socket_class_add( sc );
	*p_sc = sc;
	return SC_OK;
error:
	GLOBAL_ERRNOLAST();
error2:
	Safefree( sc );
	return SC_ERROR;
}

int mod_sc_create_class( sc_t *socket, const char *pkg, SV **psv ) {
	HV *hv;
	SV *sv;
	size_t len;
	if( pkg != NULL && *pkg != '\0' ) {
		len = strlen( pkg );
		Renew( socket->classname, len + 1, char );
		Copy( pkg, socket->classname, len + 1, char );
	}
	else {
		pkg = socket->classname != NULL ? socket->classname : "Socket::Class";
	}
	hv = gv_stashpv( pkg, FALSE );
	if( hv == NULL ) {
		snprintf( socket->last_error, sizeof( socket->last_error ),
			"Invalid package '%s'", pkg );
		socket->last_errno = -1;
		return SC_ERROR;
	}
	sv = sv_2mortal( (SV *) newHV() );
	(void) hv_store( (HV *) sv, "_sc_", 4, newSViv( (IV) socket->id ), 0 );
#ifdef SC_DEBUG
	_debug( "bless socket %d with %s\n", socket->sock, pkg );
#endif
	*psv = sv_bless( newRV( sv ), hv );
	return SC_OK;
}

void mod_sc_destroy( sc_t *socket ) {
	socket_class_rem( socket );
}

void mod_sc_destroy_class( SV *sv ) {
	sc_t *socket = socket_class_find( sv );
	if( socket == NULL )
		return;
	mod_sc_destroy( socket );
	sv_2mortal( sv );
}

sc_t *mod_sc_get_socket( SV *sv ) {
	return socket_class_find( sv );
}

int mod_sc_connect(
	sc_t *sock, const char *host, const char *serv, double timeout
) {
	fd_set fds;
	int r;
	socklen_t sl;
	sock->last_error[0] = '\0';
	if( timeout > 0 ) {
		sock->timeout.tv_sec = (long) (timeout / 1000);
		sock->timeout.tv_usec = (long) (timeout * 1000) % 1000000;
	}
	switch( sock->s_domain ) {
	case AF_INET:
	case AF_INET6:
	default:
		if( host == NULL && serv == NULL ) {
			if( sock->state != SC_STATE_CLOSED ) {
				sock->last_errno =
					Socket_setaddr_INET( sock, NULL, NULL, ADDRUSE_CONNECT );
				if( sock->last_errno != 0 )
					goto error;
			}
		}
		else {
			sock->last_errno =
				Socket_setaddr_INET( sock, host, serv, ADDRUSE_CONNECT );
			if( sock->last_errno != 0 )
				goto error;
		}
		break;
	case AF_UNIX:
		if( host == NULL ) {
			if( sock->state != SC_STATE_CLOSED ) {
				Socket_setaddr_UNIX( &sock->r_addr, NULL );
			}
		}
		else {
			Socket_setaddr_UNIX( &sock->r_addr, host );
		}
		break;
	}
	if( sock->state == SC_STATE_CONNECTED ) {
		Socket_close( sock->sock );
		sock->state = SC_STATE_CLOSED;
	}
	if( sock->sock == INVALID_SOCKET ) {
		sock->sock = socket(
			sock->s_domain, sock->s_type, sock->s_proto );
		if( sock->sock == INVALID_SOCKET ) {
			sock->last_errno = Socket_errno();
			goto error;
		}
	}
#ifdef SC_DEBUG
	_debug( "connecting socket %d state %d addrlen %d\n",
		sock->sock, sock->state, sock->r_addr.l );
#endif
	if( ! sock->non_blocking ) {
		if( Socket_setblocking( sock->sock, 0 ) == SOCKET_ERROR ) {
			sock->last_errno = Socket_errno();
			goto error;
		}
	}
	r = connect( sock->sock,
		(struct sockaddr *) sock->r_addr.a, sock->r_addr.l );
	if( r == SOCKET_ERROR ) {
		r = Socket_errno();
		if( r == EINPROGRESS || r == EWOULDBLOCK ) {
			FD_ZERO( &fds ); 
			FD_SET( sock->sock, &fds );
			if( select(
					(int) (sock->sock + 1), NULL, &fds, NULL, &sock->timeout
				) > 0
			) {
				sl = sizeof( int );
				if( getsockopt(
						sock->sock, SOL_SOCKET, SO_ERROR, (void*) (&r), &sl
					) == SOCKET_ERROR
				) {
					sock->last_errno = Socket_errno();
					goto error;
				}
				if( r ) {
#ifdef SC_DEBUG
					_debug( "getsockopt SO_ERROR %d\n", r );
#endif
					sock->last_errno = r;
					goto error;
				}
			}
			else {
#ifdef SC_DEBUG
				_debug( "connect timed out %u\n", ETIMEDOUT );
#endif
				sock->last_errno = ETIMEDOUT;
				goto error;
			}	
		}
		else {
#ifdef SC_DEBUG
			_debug( "connect failed %d\n", r );
#endif
			sock->last_errno = r;
			goto error;
		}
	}
	if( ! sock->non_blocking ) {
		if( Socket_setblocking( sock->sock, 1 ) == SOCKET_ERROR ) {
			sock->last_errno = Socket_errno();
			goto error;
		}
	}
	sock->l_addr.l = SOCKADDR_SIZE_MAX;
	getsockname( sock->sock,
		(struct sockaddr *) sock->l_addr.a, &sock->l_addr.l );
	sock->state = SC_STATE_CONNECTED;
	sock->last_errno = 0;
	return SC_OK;
error:
	return SC_ERROR;
}

int mod_sc_shutdown( sc_t *sock, int how ) {
	if( shutdown( sock->sock, how ) == SOCKET_ERROR ) {
		sock->last_errno = Socket_errno();
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	sock->last_errno = 0;
	sock->state = SC_STATE_SHUTDOWN;
	return SC_OK;
}

int mod_sc_close( sc_t *sock ) {
	Socket_close( sock->sock );
	if( sock->s_domain == AF_UNIX ) {
		remove( ((struct sockaddr_un *) sock->l_addr.a)->sun_path );
	}
	sock->state = SC_STATE_CLOSED;
	memset( &sock->l_addr, 0, sizeof( sock->l_addr ) );
	memset( &sock->r_addr, 0, sizeof( sock->r_addr ) );
	return SC_OK;
}

int mod_sc_bind( sc_t *sock, const char *host, const char *serv ) {
	sock->last_error[0] = '\0';
	switch( sock->s_domain ) {
	case AF_INET:
	case AF_INET6:
	default:
		if( host == NULL && serv == NULL ) {
			if( sock->state != SC_STATE_CLOSED ) {
				sock->last_errno =
					Socket_setaddr_INET( sock, NULL, NULL, ADDRUSE_LISTEN );
				if( sock->last_errno != 0 )
					return SC_ERROR;
			}
		}
		else {
			sock->last_errno =
				Socket_setaddr_INET( sock, host, serv, ADDRUSE_LISTEN );
			if( sock->last_errno != 0 )
				return SC_ERROR;
		}
		break;
	case AF_UNIX:
		if( host == NULL ) {
			if( sock->state != SC_STATE_CLOSED ) {
				Socket_setaddr_UNIX( &sock->l_addr, NULL );
			}
		}
		else {
			Socket_setaddr_UNIX( &sock->l_addr, host );
		}
		remove( ((struct sockaddr_un *) sock->l_addr.a)->sun_path );
		break;
	}
	if( sock->sock == INVALID_SOCKET ) {
		sock->sock = socket( sock->s_domain, sock->s_type, sock->s_proto );
		if( sock->sock == INVALID_SOCKET ) {
			sock->last_errno = Socket_errno();
			return SC_ERROR;
		}
	}
	if( bind( sock->sock, (struct sockaddr *) sock->l_addr.a, sock->l_addr.l )
		== SOCKET_ERROR
	) {
		sock->last_errno = Socket_errno();
		return SC_ERROR;
	}
	getsockname( sock->sock,
		(struct sockaddr *) sock->l_addr.a, &sock->l_addr.l );
	sock->state = SC_STATE_BOUND;
	sock->last_errno = 0;
	return SC_OK;
}

int mod_sc_listen( sc_t *sock, int queue ) {
	if( listen( sock->sock, queue ) == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	sock->state = SC_STATE_LISTEN;
	return SC_OK;
}

int mod_sc_accept( sc_t *sock, sc_t **client ) {
	socket_class_t *sc2;
	SOCKET s;
	my_sockaddr_t addr;
	addr.l = SOCKADDR_SIZE_MAX;
	s = accept( sock->sock, (struct sockaddr *) addr.a, &addr.l );
	if( s == INVALID_SOCKET ) {			
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*client = NULL;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "accept error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	Newxz( sc2, 1, sc_t );
	sc2->s_domain = sock->s_domain;
	sc2->s_type = sock->s_type;
	sc2->s_proto = sock->s_proto;
	sc2->sock = s;
	sc2->state = SC_STATE_CONNECTED;
	Copy( &addr, &sc2->r_addr, MYSASIZE( addr ), BYTE );
	sc2->l_addr.l = SOCKADDR_SIZE_MAX;
	getsockname( s, (struct sockaddr *) sc2->l_addr.a, &sc2->l_addr.l );
	socket_class_add( sc2 );
#ifdef SC_DEBUG
	_debug( "accepted socket %d sc %lu\n", s, sc2->id );
#endif
	*client = sc2;
	return SC_OK;
}

int mod_sc_recv( sc_t *sock, char *buf, int len, int flags, int *p_len ) {
	int r;
	/*
	if( sock->rcvbuf_len < len ) {
		sock->rcvbuf_len = len;
		Renew( sock->rcvbuf, len, char );
	}
	*/
	r = recv( sock->sock, buf, (int) len, flags );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*p_len = 0;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "recv error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	else if( r != 0 ) {
		sock->last_errno = 0;
		*p_len = r;
		return SC_OK;
	}
	sock->last_errno = ECONNRESET;
	sock->state = SC_STATE_ERROR;
	return SC_ERROR;
}

int mod_sc_send( sc_t *sock, const char *buf, int len, int flags, int *p_len ) {
	int r;
	r = send( sock->sock, buf, len, flags );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*p_len = 0;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "send error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	else if( r != 0 ) {
		sock->last_errno = 0;
		*p_len = r;
		return SC_OK;
	}
	sock->last_errno = ECONNRESET;
#ifdef SC_DEBUG
	_debug( "send error %u\n", sock->last_errno );
#endif
	sock->state = SC_STATE_ERROR;
	return SC_ERROR;
}

int mod_sc_recvfrom( sc_t *sock, char *buf, int len, int flags, int *p_len ) {
	int r;
	sc_addr_t peer;
	peer.l = SOCKADDR_SIZE_MAX;
	r = recvfrom(
		sock->sock, buf, len, flags,
		(struct sockaddr *) peer.a, &peer.l
	);
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*p_len = 0;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "recvfrom error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	else if( r != 0 ) {
		sock->last_errno = 0;
		*p_len = r;
		/* remember who we received from */
		Copy( &peer, &sock->r_addr, peer.l + sizeof( int ), BYTE );
		return SC_OK;
	}
	sock->last_errno = ECONNRESET;
	sock->state = SC_STATE_ERROR;
	return SC_ERROR;
}

int mod_sc_sendto(
	sc_t *sock, const char *buf, int len, int flags, sc_addr_t *peer, int *p_len
) {
	int r;
	if( peer != NULL ) {
		/* remember who we send to */
		Copy( peer, &sock->r_addr, MYSASIZE( *peer ), BYTE );
	}
	else {
		peer = &sock->r_addr;
	}
	r = sendto(
		sock->sock, buf, len, flags, (struct sockaddr *) peer->a, peer->l );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*p_len = 0;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "sendto error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	else if( r != 0 ) {
		sock->last_errno = 0;
		*p_len = r;
		return SC_OK;
	}
	sock->last_errno = ECONNRESET;
	sock->state = SC_STATE_ERROR;
	return SC_ERROR;
}

int mod_sc_read( sc_t *sock, char *buf, int len, int *p_len ) {
	int r;
	r = recv( sock->sock, buf, len, 0 );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			*p_len = 0;
			return SC_OK;
		default:
#ifdef SC_DEBUG
			_debug( "read error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
	}
	else if( r == 0 ) {
		sock->last_errno = ECONNRESET;
#ifdef SC_DEBUG
		_debug( "read error %u\n", sock->last_errno );
#endif
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	sock->last_errno = 0;
	*p_len = r;
	return SC_OK;
}

int mod_sc_write( sc_t *sock, const char *buf, int len, int *p_len ) {
	int r = Socket_write( sock, buf, len );
	if( r != SOCKET_ERROR ) {
		*p_len = r;
		return SC_OK;
	}
	return SC_ERROR;
}

int mod_sc_writeln( sc_t *sock, const char *buf, int len, int *p_len ) {
	char *tmp;
	int r;
	if( len <= 0 )
		len = (int) strlen( buf );
	Newx( tmp, len + 2, char );
	Copy( buf, tmp, len, char );
	tmp[len ++] = '\r';
	tmp[len ++] = '\n';
	r = Socket_write( sock, buf, len );
	Safefree( tmp );
	if( r != SOCKET_ERROR ) {
		*p_len = r;
		return SC_OK;
	}
	return SC_ERROR;
}

int mod_sc_printf( sc_t *sock, const char *fmt, ... ) {
	int r;
	va_list vl;
	va_start( vl, fmt );
	r = mod_sc_vprintf( sock, fmt, vl );
	va_end( vl );
	return r;
}

int mod_sc_vprintf( sc_t *sock, const char *fmt, va_list vl ) {
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
	r = mod_sc_write( sock, tmp, size, &size );
	Safefree( tmp );
	return r;
}

int mod_sc_readline( sc_t *sock, char **p_buf, int *p_len ) {
	int r;
	size_t i, pos = 0, len = 256;
	char *p;
	p = sock->rcvbuf;
	while( 1 ) {
		if( sock->rcvbuf_len < pos + len ) {
			sock->rcvbuf_len = pos + len;
			Renew( sock->rcvbuf, sock->rcvbuf_len, char );
			p = sock->rcvbuf + pos;
		}
		r = recv( sock->sock, p, (int) len, MSG_PEEK );
		if( r == SOCKET_ERROR ) {
			if( pos > 0 )
				break;
			sock->last_errno = Socket_errno();
			switch( sock->last_errno ) {
			case EWOULDBLOCK:
				/* threat not as an error */
				sock->last_errno = 0;
				sock->rcvbuf[0] = '\0';
				*p_buf = sock->rcvbuf;
				*p_len = 0;
				return SC_OK;
			}
#ifdef SC_DEBUG
			_debug( "readline error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
		else if( r == 0 ) {
			if( pos > 0 )
				break;
			sock->last_errno = ECONNRESET;
#ifdef SC_DEBUG
			_debug( "readline error %u\n", sock->last_errno );
#endif
			sock->state = SC_STATE_ERROR;
			return SC_ERROR;
		}
		for( i = 0; i < (size_t) r; i ++, p ++ ) {
			if( *p != '\n' && *p != '\r' && *p != '\0' )
				continue;
			/* found newline */
#ifdef SC_DEBUG
			_debug( "found newline at %d + %d of %d\n", pos, i, r );
#endif
			sock->rcvbuf[pos + i] = '\0';
			*p_buf = sock->rcvbuf;
			*p_len = (int) (pos + i);
			if( *p == '\r' ) {
				if( i < (size_t) r ) {
					if( p[1] == '\n' )
						i ++;
				}
				else if( r == (int) len ) {
					r = recv( sock->sock, p, 1, MSG_PEEK );
					if( r == 1 && *p == '\n' )
						recv( sock->sock, p, 1, 0 );
				}
			}
			recv( sock->sock, sock->rcvbuf + pos, (int) i + 1, 0 );
			return SC_OK;
		}
		recv( sock->sock, sock->rcvbuf + pos, (int) i, 0 );
		pos += i;
		if( r < (int) len )
			break;
	}
	sock->rcvbuf[pos] = '\0';
	*p_buf = sock->rcvbuf;
	*p_len = (int) pos;
	return SC_OK;
}

int mod_sc_available( sc_t *sock, int *p_len ) {
	socklen_t ol = sizeof(int);
	int r, len;
	char *tmp;
	r = getsockopt( sock->sock, SOL_SOCKET, SO_RCVBUF, (char *) &len, &ol );
	if( r != 0 ) {
		sock->last_errno = Socket_errno();
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	Newx( tmp, len, char );
	r = recv( sock->sock, tmp, len, MSG_PEEK );
	switch( r ) {
	case SOCKET_ERROR:
		sock->last_errno = Socket_errno();
		switch( sock->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			sock->last_errno = 0;
			r = 0;
			break;
		default:
			sock->state = SC_STATE_ERROR;
			Safefree( tmp );
			return SC_ERROR;
		}
	case 0:
		sock->last_errno = ECONNRESET;
		sock->state = SC_STATE_ERROR;
		Safefree( tmp );
		return SC_ERROR;
	}
	*p_len = r;
	Safefree( tmp );
	return SC_OK;
}

int mod_sc_pack_addr(
	sc_t *sock, const char *host, const char *serv, sc_addr_t *addr
) {
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	int r;
#else
	struct hostent *he;
#endif
	SOCKADDR_L2CAP *l2a;
	switch( sock->s_domain ) {
	case AF_UNIX:
		Socket_setaddr_UNIX( addr, host );
		return SC_OK;
	case AF_BLUETOOTH:
		if( sock->s_proto == BTPROTO_L2CAP ) {
			addr->l = sizeof( SOCKADDR_L2CAP );
			l2a = (SOCKADDR_L2CAP *) addr->a;
			l2a->bt_family = AF_BLUETOOTH;
			my_str2ba( host, &l2a->bt_bdaddr );
			l2a->bt_port = serv != NULL ? (uint8_t) atoi( serv ) : 0;
			return SC_OK;
		}
		else
			goto _default;
		break;
#ifndef SC_OLDNET
	case AF_INET:
	case AF_INET6:
	default:
_default:
		memset( &aih, 0, sizeof( struct addrinfo ) );
		aih.ai_family = sock->s_domain;
		aih.ai_socktype = sock->s_type;
		aih.ai_protocol = sock->s_proto;
		r = getaddrinfo( host, serv == NULL ? "" : serv, &aih, &ail );
		if( r != 0 ) {
#ifdef SC_DEBUG
			_debug( "getaddrinfo('%s', '%s') failed %d\n", host, serv, r );
#endif
			SOCK_ERRNO( sock, r );
#ifndef _WIN32
			{
				const char *s1 = gai_strerror( r );
				strncpy( sock->last_error, s1, sizeof( sock->last_error ) );
			}
#endif
			return SC_ERROR;
		}
		addr->l = (socklen_t) ail->ai_addrlen;
		memcpy( addr->a, ail->ai_addr, ail->ai_addrlen );
		freeaddrinfo( ail );
		return SC_OK;
#else
	case AF_INET:
		GLOBAL_LOCK();
		addr->l = sizeof( struct sockaddr_in );
		memset( addr->a, 0, addr->l );
		((struct sockaddr_in *) addr->a)->sin_family = AF_INET;
		if( host[0] >= '0' && host[0] <= '9' ) {
			((struct sockaddr_in *) addr->a)->sin_addr.s_addr = inet_addr( host );
		}
		else {
			he = gethostbyname( host );
			if( he == NULL ) {
				SOCK_ERRNOLAST( sock );
				GLOBAL_UNLOCK();
				return SC_ERROR;
			}
			((struct sockaddr_in *) addr->a)->sin_addr =
				*(struct in_addr*) he->h_addr;
		}
		if( serv != NULL && *serv != '\0' ) {
			if( serv[0] >= '0' && serv[0] <= '9' )
				((struct sockaddr_in *) addr->a)->sin_port
					= htons( atoi( serv ) );
			else {
				struct servent *se;
				se = getservbyname( serv, NULL );
				if( se == NULL ) {
					SOCK_ERRNOLAST( sock );
					GLOBAL_UNLOCK();
					return SC_ERROR;
				}
				((struct sockaddr_in *) addr->a)->sin_port = se->s_port;
			}
		}
		GLOBAL_UNLOCK();
		return SC_OK;
	case AF_INET6:
		GLOBAL_LOCK();
		addr->l = sizeof( struct sockaddr_in6 );
		memset( addr->a, 0, addr->l );
		((struct sockaddr_in6 *) addr->a)->sin6_family = AF_INET6;
#ifndef _WIN32
		if( ( host[0] >= '0' && host[0] <= '9' ) || host[0] == ':' ) {
			if( inet_pton(
					AF_INET6, host,
					&((struct sockaddr_in6 *) addr->a)->sin6_addr
				) != 0 )
			{
#ifdef SC_DEBUG
				_debug( "inet_pton failed %d\n", Socket_errno() );
#endif
				SOCK_ERRNOLAST( sock );
				GLOBAL_UNLOCK();
				return SC_ERROR;
			}
		}
		else {
			he = gethostbyname( host );
			if( he == NULL ) {
				SOCK_ERRNOLAST( sock );
				GLOBAL_UNLOCK();
				return SC_ERROR;
			}
			if( he->h_addrtype != AF_INET6 ) {
				SOCK_ERROR( sock, "invalid address family type" );
				GLOBAL_UNLOCK();
				return SC_ERROR;
			}
			Copy(
				he->h_addr, &((struct sockaddr_in6 *) addr->a)->sin6_addr,
				he->h_length, char
			);
		}
		if( serv != NULL && *serv != '\0' ) {
			if( serv[0] >= '0' && serv[0] <= '9' )
				((struct sockaddr_in6 *) addr->a)->sin6_port
					= htons( atol( serv ) );
			else {
				struct servent *se;
				se = getservbyname( serv, NULL );
				if( se == NULL ) {
					SOCK_ERRNOLAST( sock );
					GLOBAL_UNLOCK();
					return SC_ERROR;
				}
				((struct sockaddr_in6 *) addr->a)->sin6_port = se->s_port;
			}
		}
#endif
		GLOBAL_UNLOCK();
		return SC_OK;
	default:
_default:
		SOCK_ERROR( sock, "invalid address type" );
		return SC_ERROR;
#endif
	}
}

int mod_sc_unpack_addr(
	sc_t *sock, sc_addr_t *addr, char *host, int *host_len, char *serv,
	int *serv_len
) {
	char *s1;
	int r;
	switch( sock->s_domain ) {
	case AF_UNIX:
		s1 = ((struct sockaddr_un *) addr->a )->sun_path;
		s1 = my_strncpy( host, s1, *host_len );
		*host_len = (int) (s1 - host);
		*serv = '\0';
		*serv_len = 0;
		break;
	case AF_BLUETOOTH:
		if( *host_len >= 18 ) {
			r = my_ba2str(
				(bdaddr_t *) &addr->a[sizeof(sa_family_t)], host );
			*host_len = r;
		}
		else {
			*host = '\0';
			*host_len = 0;
		}
		if( *serv_len >= 6 ) {
			switch( sock->s_proto ) {
			case BTPROTO_RFCOMM:
				s1 = my_itoa( serv,
					((SOCKADDR_RFCOMM *) addr->a)->bt_port, 10 );
				*serv_len = (int) (s1 - serv);
				break;
			case BTPROTO_L2CAP:
				s1 = my_itoa( serv,
					((SOCKADDR_L2CAP *) addr->a)->bt_port, 10 );
				break;
			default:
				goto bt_noport;
			}
		}
		else {
bt_noport:
			*serv = '\0';
			*serv_len = 0;
		}
		break;
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) addr->a )->sin_addr.s_addr );
		r = snprintf( host, *host_len, "%u.%u.%u.%u", IP4( r ) );
		*host_len = r;
		if( *serv_len >= 6 ) {
			r = ntohs( ((struct sockaddr_in *) addr->a )->sin_port );
			s1 = my_itoa( serv, r, 10 );
			*serv_len = (int) (s1 - serv);
		}
		else {
			*serv = '\0';
			*serv_len = 0;
		}
		break;
	case AF_INET6:
		s1 = (char *) &((struct sockaddr_in6 *) addr->a )->sin6_addr;
		r = snprintf( host, *host_len,
			"%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) s1 )
		);
		*host_len = r;
		if( *serv_len >= 6 ) {
			r = ntohs( ((struct sockaddr_in6 *) addr->a )->sin6_port );
			s1 = my_itoa( serv, r, 10 );
			*serv_len = (int) (s1 - serv);
		}
		else {
			*serv = '\0';
			*serv_len = 0;
		}
		break;
	default:
		SOCK_ERROR( sock, "invalid address" );
		return SC_ERROR;
	}
	return SC_OK;
}

int mod_sc_gethostbyaddr(
	sc_t *sock, sc_addr_t *addr, char *host, int *host_len
) {
#ifndef SC_OLDNET
	char serv[NI_MAXSERV];
	int r;
#else
	struct hostent *he;
	struct in_addr ia4;
	struct in6_addr ia6;
	char *s2;
#endif
	if( addr == NULL )
		addr = &sock->r_addr;
#ifndef SC_OLDNET
	r = getnameinfo(
		(struct sockaddr *) addr->a, addr->l,
		host, *host_len,
		serv, sizeof( serv ),
		NI_NUMERICSERV | NI_NAMEREQD
	);
	if( r != 0 ) {
#ifndef _WIN32
		const char *s1 = gai_strerror( r );
		strncpy( sock->last_error, s1, sizeof( sock->last_error ) );
#endif
		sock->last_errno = r;
		return SC_ERROR;
	}
	*host_len = (int) strlen( host );
	return SC_OK;
#else
	GLOBAL_LOCK();
	switch( sock->s_domain ) {
	case AF_INET:
		he = gethostbyaddr(
			(const char *) &((struct sockaddr_in *) addr->a)->sin_addr,
			sizeof( ia4 ), AF_INET
		);
		break;
	case AF_INET6:
		he = gethostbyaddr(
			(const char *) &((struct sockaddr_in6 *) addr->a)->sin6_addr,
			sizeof( ia6 ), AF_INET6
		);
		break;
	default:
		SOCK_ERRNO( sock, 0 );
		*host = '\0';
		*host_len = 0;
		GLOBAL_UNLOCK();
		return SC_OK;
	}
	if( he == NULL ) {
		SOCK_ERRNOLAST( sock );
		GLOBAL_UNLOCK();
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	s2 = my_strncpy( host, he->h_name, *host_len );
	*host_len = (int) (s2 - host);
	GLOBAL_UNLOCK();
	return SC_OK;
#endif
}

int mod_sc_gethostbyname(
	sc_t *sock, const char *name, char *addr, int *addr_len
) {
	int r;
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	void *p1;
#else
	struct hostent *he;
#endif
#ifndef SC_OLDNET
	memset( &aih, 0, sizeof( struct addrinfo ) );
	/*
	aih.ai_family = sock->s_domain;
	aih.ai_socktype = sock->s_type;
	aih.ai_protocol = sock->s_proto;
	*/
	r = getaddrinfo( name, "", &aih, &ail );
	if( r != 0 ) {
#ifndef _WIN32
		const char *s1 = gai_strerror( r );
		strncpy( sock->last_error, s1, sizeof( sock->last_error ) );
#endif
		sock->last_errno = r;
		return SC_ERROR;
	}
	switch( ail->ai_family ) {
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) ail->ai_addr )->sin_addr.s_addr );
		r = snprintf( addr, *addr_len, "%u.%u.%u.%u", IP4( r ) );
		*addr_len = r;
		break;
	case AF_INET6:
		p1 = &((struct sockaddr_in6 *) ail->ai_addr )->sin6_addr;
		r = snprintf( addr, *addr_len,
			"%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) p1 )
		);
		*addr_len = r;
		break;
	default:
		*addr = '\0';
		*addr_len = 0;
	}
	freeaddrinfo( ail );
#else
	GLOBAL_LOCK();
	he = gethostbyname( name );
	if( he == NULL ) {
#ifdef SC_DEBUG
		_debug( "gethostbyname() failed %d\n", Socket_errno() );
#endif
		SOCK_ERRNOLAST( sock );
		GLOBAL_UNLOCK();
		return SC_ERROR;
	}
	switch( he->h_addrtype ) {
	case AF_INET:
		r = ntohl( (*(struct in_addr*) he->h_addr).s_addr );
		r = snprintf( addr, *addr_len, "%u.%u.%u.%u", IP4( r ) );
		*addr_len = r;
		break;
	case AF_INET6:
		r = snprintf( addr, *addr_len,
			"%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) he->h_addr )
		);
		*addr_len = r;
		break;
	default:
		*addr = '\0';
		*addr_len = 0;
	}
	GLOBAL_UNLOCK();
#endif
	SOCK_ERRNO( sock, 0 );
	return SC_OK;
}

#ifndef SC_OLDNET

void my_addrinfo_get( const struct addrinfo *src, sc_addrinfo_t **res ) {
	sc_addrinfo_t *ai, *ai_prv = NULL;
	char *str;
	if( src == NULL ) {
		*res = NULL;
		return;
	}
	for( ; src != NULL; src = src->ai_next ) {
		Newx( ai, 1, sc_addrinfo_t );
		ai->ai_flags = src->ai_flags;
		ai->ai_family = src->ai_family;
		ai->ai_socktype = src->ai_socktype;
		ai->ai_protocol = src->ai_protocol;
		if( src->ai_addrlen ) {
			Newx( str, src->ai_addrlen, char );
			Copy( src->ai_addr, str, src->ai_addrlen, char );
			ai->ai_addr = (struct sockaddr *) str;
			ai->ai_addrlen = src->ai_addrlen;
		}
		else {
			ai->ai_addr = NULL;
			ai->ai_addrlen = 0;
		}
		if( src->ai_canonname != NULL ) {
			ai->ai_cnamelen = strlen( src->ai_canonname );
			Newx( str, ai->ai_cnamelen + 1, char );
			Copy( src->ai_canonname, str, ai->ai_cnamelen + 1, char );
			ai->ai_canonname = str;
		}
		else {
			ai->ai_canonname = NULL;
			ai->ai_cnamelen = 0;
		}
		ai->ai_next = NULL;
		if( ai_prv == NULL ) {
			*res = ai_prv = ai;
		}
		else {
			ai_prv->ai_next = ai;
		}
		ai_prv = ai;
	}
}

void my_addrinfo_set( const sc_addrinfo_t *src, struct addrinfo **res ) {
	struct addrinfo *ai, *ai_prv = NULL;
	char *str;
	if( src == NULL ) {
		*res = NULL;
		return;
	}
	for( ; src != NULL; src = src->ai_next ) {
		Newx( ai, 1, struct addrinfo );
		ai->ai_flags = src->ai_flags;
		ai->ai_family = src->ai_family;
		ai->ai_socktype = src->ai_socktype;
		ai->ai_protocol = src->ai_protocol;
		if( src->ai_addrlen ) {
			Newx( str, src->ai_addrlen, char );
			Copy( src->ai_addr, str, src->ai_addrlen, char );
			ai->ai_addr = (struct sockaddr *) str;
			ai->ai_addrlen = src->ai_addrlen;
		}
		else {
			ai->ai_addr = NULL;
			ai->ai_addrlen = 0;
		}
		if( src->ai_cnamelen ) {
			Newx( str, src->ai_cnamelen + 1, char );
			Copy( src->ai_canonname, str, src->ai_cnamelen + 1, char );
			ai->ai_canonname = str;
		}
		else {
			ai->ai_canonname = NULL;
		}
		ai->ai_next = NULL;
		if( ai_prv == NULL ) {
			*res = ai_prv = ai;
		}
		else {
			ai_prv->ai_next = ai;
		}
		ai_prv = ai;
	}
}

void my_addrinfo_free( struct addrinfo *res ) {
	struct addrinfo *ai;
	if( res == NULL )
		return;
	while( res != NULL ) {
		ai = res->ai_next;
		Safefree( res->ai_canonname );
		Safefree( res->ai_addr );
		Safefree( res );
		res = ai;
	}
}

#endif /* ! SC_OLDNET */

int mod_sc_getaddrinfo(
	sc_t *sock, const char *node, const char *service,
	const sc_addrinfo_t *hints, sc_addrinfo_t **res
) {
#ifndef SC_OLDNET
	int r;
	struct addrinfo *aih, *ail = NULL;
	my_addrinfo_set( hints, &aih );
	if( aih != NULL && (aih->ai_flags & AI_PASSIVE) != 0 ) {
		if( service == NULL || *service == '\0' )
			service = "0";
	}
	r = getaddrinfo( node, service, aih, &ail );
	my_addrinfo_free( aih );
	if( r ) {
#ifdef SC_DEBUG
		_debug( "getaddrinfo failed %d\n", r );
#endif
		if( sock != NULL ) {
#ifndef _WIN32
			const char *s1 = gai_strerror( r );
			strncpy( sock->last_error, s1, sizeof(sock->last_error) );
#endif
			sock->last_errno = r;
		}
		else {
			GLOBAL_LOCK();
#ifndef _WIN32
			GLOBAL_ERROR( r, gai_strerror( r ) );
#else
			GLOBAL_ERRNO( r );
#endif
			GLOBAL_UNLOCK();
		}
		return SC_ERROR;
	}
	my_addrinfo_get( ail, res );
	freeaddrinfo( ail );
	if( sock != NULL ) {
		SOCK_ERRNO( sock, 0 );
	}
	else {
		GLOBAL_LOCK();
		GLOBAL_ERROR( 0, "" );
		GLOBAL_UNLOCK();
	}
	return SC_OK;
#else /* SC_OLDNET */
	if( sock != NULL ) {
		SOCK_ERROR( sock, "getaddrinfo() is not supported" );
	}
	else {
		GLOBAL_LOCK();
		GLOBAL_ERROR( -1, "getaddrinfo() is not supported" );
		GLOBAL_UNLOCK();
	}
	return SC_ERROR;
#endif /* SC_OLDNET */
}

void mod_sc_freeaddrinfo( sc_addrinfo_t *res ) {
	sc_addrinfo_t *ai;
	if( res == NULL )
		return;
	while( res != NULL ) {
		ai = res->ai_next;
		Safefree( res->ai_canonname );
		Safefree( res->ai_addr );
		Safefree( res );
		res = ai;
	}
}

int mod_sc_getnameinfo(
	sc_t *sock, sc_addr_t *addr, char *host, int host_len,
	char *serv, int serv_len, int flags
) {
#ifndef SC_OLDNET
	int r;
	r = getnameinfo(
		(const struct sockaddr *) addr->a, addr->l,
		host, host_len, serv, serv_len, flags
	);
	if( r != 0 ) {
#ifdef SC_DEBUG
		_debug( "getnameinfo failed %d\n", r );
#endif
		if( sock != NULL ) {
#ifndef _WIN32
			const char *s1 = gai_strerror( r );
			strncpy( sock->last_error, s1, sizeof( sock->last_error ) );
#endif
			sock->last_errno = r;
		}
		else {
#ifndef _WIN32
			GLOBAL_ERROR( r, gai_strerror( r ) );
#else
			GLOBAL_ERRNO( r );
#endif
			GLOBAL_UNLOCK();
		}
		return SC_ERROR;
	}
	if( sock != NULL ) {
		SOCK_ERRNO( sock, 0 );
	}
	else {
		GLOBAL_LOCK();
		GLOBAL_ERROR( 0, "" );
		GLOBAL_UNLOCK();
	}
	return SC_OK;
#else /* SC_OLDNET */
	if( sock != NULL ) {
		SOCK_ERROR( sock, "getnameinfo() is not supported" );
	}
	else {
		GLOBAL_LOCK();
		GLOBAL_ERROR( -1, "getnameinfo() is not supported" );
		GLOBAL_UNLOCK();
	}
	return SC_ERROR;
#endif /* SC_OLDNET */
}

int mod_sc_set_blocking( sc_t *sock, int mode ) {
	int r;
	r = Socket_setblocking( sock->sock, mode );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	sock->non_blocking = (BYTE) ! mode;
	return SC_OK;
}

int mod_sc_get_blocking( sc_t *sock, int *mode ) {
	*mode = ! sock->non_blocking;
	return SC_OK;
}

int mod_sc_set_reuseaddr( sc_t *sock, int mode ) {
	return mod_sc_setsockopt(
		sock, SOL_SOCKET, SO_REUSEADDR, (void *) &mode, sizeof( int )
	);
}

int mod_sc_get_reuseaddr( sc_t *sock, int *mode ) {
	socklen_t l = sizeof( int );
	return mod_sc_getsockopt(
		sock, SOL_SOCKET, SO_REUSEADDR, (void *) mode, &l
	);
}

int mod_sc_set_broadcast( sc_t *sock, int mode ) {
	return mod_sc_setsockopt(
		sock, SOL_SOCKET, SO_BROADCAST, (void *) &mode, sizeof( int )
	);
}

int mod_sc_get_broadcast( sc_t *sock, int *mode ) {
	socklen_t l = sizeof( int );
	return mod_sc_getsockopt(
		sock, SOL_SOCKET, SO_BROADCAST, (void *) mode, &l
	);
}

int mod_sc_set_rcvbuf_size( sc_t *sock, int size ) {
	return mod_sc_setsockopt(
		sock, SOL_SOCKET, SO_RCVBUF, (void *) &size, sizeof( int )
	);
}

int mod_sc_get_rcvbuf_size( sc_t *sock, int *size ) {
	socklen_t l = sizeof( int );
	return mod_sc_getsockopt(
		sock, SOL_SOCKET, SO_RCVBUF, (void *) size, &l
	);
}

int mod_sc_set_sndbuf_size( sc_t *sock, int size ) {
	return mod_sc_setsockopt(
		sock, SOL_SOCKET, SO_SNDBUF, (void *) &size, sizeof( int )
	);
}

int mod_sc_get_sndbuf_size( sc_t *sock, int *size ) {
	socklen_t l = sizeof( int );
	return mod_sc_getsockopt(
		sock, SOL_SOCKET, SO_SNDBUF, (void *) size, &l
	);
}

int mod_sc_set_tcp_nodelay( sc_t *sock, int mode ) {
	return mod_sc_setsockopt(
		sock, IPPROTO_TCP, TCP_NODELAY, (void *) &mode, sizeof( int )
	);
}

int mod_sc_get_tcp_nodelay( sc_t *sock, int *mode ) {
	socklen_t l = sizeof( int );
	return mod_sc_getsockopt(
		sock, IPPROTO_TCP, TCP_NODELAY, (void *) mode, &l
	);
}

int mod_sc_setsockopt(
	sc_t *sock, int level, int optname, const void *optval, socklen_t optlen
) {
	int r = setsockopt( sock->sock, level, optname, optval, optlen );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	return SC_OK;
}

int mod_sc_getsockopt(
	sc_t *sock, int level, int optname, void *optval, socklen_t *optlen
) {
	int r = getsockopt( sock->sock, level, optname, optval, optlen );
	if( r == SOCKET_ERROR ) {
		SOCK_ERRNOLAST( sock );
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	return SC_OK;
}

int mod_sc_set_timeout( sc_t *sock, double timeout ) {
	sock->timeout.tv_sec = (long) (timeout / 1000);
	sock->timeout.tv_usec = (long) (timeout * 1000) % 1000000;
	return SC_OK;
}

int mod_sc_get_timeout( sc_t *sock, double *timeout ) {
	*timeout = sock->timeout.tv_sec * 1000 + sock->timeout.tv_usec / 1000;
	return SC_OK;
}

int mod_sc_is_readable( sc_t *sock, double timeout, int *readable ) {
	fd_set fd_socks;
	struct timeval t;
	int r;
	FD_ZERO( &fd_socks );
	FD_SET( sock->sock, &fd_socks );
	if( timeout > 0 ) {
		t.tv_sec = (long) (timeout / 1000);
		t.tv_usec = (long) (timeout * 1000) % 1000000;
		r = select(
			(int) (sock->sock + 1), &fd_socks, NULL, NULL, &t
		);
	}
	else {
		r = select(
			(int) (sock->sock + 1), &fd_socks, NULL, NULL, NULL
		);
	}
	if( r < 0 ) {
		SOCK_ERRNOLAST( sock );
#ifdef SC_DEBUG
		_debug( "is_readable error %u\n", sock->last_errno );
#endif
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	*readable = r;
	return SC_OK;
}

int mod_sc_is_writable( sc_t *sock, double timeout, int *writable ) {
	fd_set fd_socks;
	struct timeval t;
	int r;
	FD_ZERO( &fd_socks );
	FD_SET( sock->sock, &fd_socks );
	if( timeout > 0 ) {
		t.tv_sec = (long) (timeout / 1000);
		t.tv_usec = (long) (timeout * 1000) % 1000000;
		r = select(
			(int) (sock->sock + 1), NULL, &fd_socks, NULL, &t
		);
	}
	else {
		r = select(
			(int) (sock->sock + 1), NULL, &fd_socks, NULL, NULL
		);
	}
	if( r < 0 ) {
		SOCK_ERRNOLAST( sock );
#ifdef SC_DEBUG
		_debug( "is_writable error %u\n", sock->last_errno );
#endif
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	*writable = r;
	return SC_OK;
}

int mod_sc_select(
	sc_t *sock, int *read, int *write, int *except, double timeout
) {
	fd_set fdr, fdw, fde;
	struct timeval t, *pt;
	int r, dr, dw, de;
	if( read == NULL )
		dr = 0;
	else if( (dr = *read) != 0 ) {
		FD_ZERO( &fdr );
		FD_SET( sock->sock, &fdr );
	}
	if( write == NULL )
		dw = 0;
	else if( (dw = *write) != 0 ) {
		FD_ZERO( &fdw );
		FD_SET( sock->sock, &fdw );
	}
	if( except == NULL )
		de = 0;
	else if( (de = *except) != 0 ) {
		FD_ZERO( &fde );
		FD_SET( sock->sock, &fde );
	}
	if( ! timeout )
		pt = NULL;
	else {
		t.tv_sec = (long) (timeout / 1000);
		t.tv_usec = (long) (timeout * 1000) % 1000000;
		pt = &t;
	}
	r = select(
		(int) (sock->sock + 1), (dr ? &fdr : NULL), (dw ? &fdw : NULL),
		(de ? &fde : NULL), pt
	);
	if( r < 0 ) {
		SOCK_ERRNOLAST( sock );
#ifdef SC_DEBUG
		_debug( "select error %u\n", sock->last_errno );
#endif
		sock->state = SC_STATE_ERROR;
		return SC_ERROR;
	}
	SOCK_ERRNO( sock, 0 );
	if( dr  )
		*read = FD_ISSET( sock->sock, &fdr );
	if( dw )
		*write = FD_ISSET( sock->sock, &fdw );
	if( de )
		*except = FD_ISSET( sock->sock, &fde );
	return SC_OK;
}

void mod_sc_sleep( double ms ) {
#ifndef _WIN32
#ifdef SC_HAS_NANOSLEEP
	struct timespec req;
#else
	struct timeval t;
#endif
#endif
#ifdef _WIN32
	Sleep( (u_long) ms );
#else
#ifdef SC_HAS_NANOSLEEP
	req.tv_sec = (long) (ms / 1000);
	req.tv_nsec = (long) ((ms - req.tv_sec) * 1000000);
	nanosleep( &req, NULL );
#else
	t.tv_sec = (long) (ms / 1000);
	t.tv_usec = (long) ((ms - req.tv_sec) * 1000);
	select( 0, NULL, NULL, NULL, &t );
#endif
#endif
}

SOCKET mod_sc_get_handle( sc_t *sock ) {
	return sock->sock;
}

int mod_sc_get_state( sc_t *sock ) {
	return sock->state;
}

int mod_sc_get_family( sc_t *sock ) {
	return sock->s_domain;
}

int mod_sc_get_proto( sc_t *sock ) {
	return sock->s_proto;
}

int mod_sc_get_type( sc_t *sock ) {
	return sock->s_type;
}

int mod_sc_local_addr( sc_t *sock, sc_addr_t *addr ) {
	addr->l = sock->l_addr.l;
	memcpy( addr->a, sock->l_addr.a, sock->l_addr.l );
	return SC_OK;
}

int mod_sc_remote_addr( sc_t *sock, sc_addr_t *addr ) {
	addr->l = sock->r_addr.l;
	memcpy( addr->a, sock->r_addr.a, sock->r_addr.l );
	return SC_OK;
}

int mod_sc_to_string( sc_t *sock, char *str, size_t *size ) {
	char *s1, *se;
	void *p1;
	int r;
	s1 = str;
	se = str + (*size);
	if( s1 + 10 >= se ) {
		*s1 = '\0';
		goto exit;
	}
	s1 = my_strcpy( str, "SOCKET(ID=" );
	if( s1 + 5 >= se )
		goto exit;
	if( sock->sock != INVALID_SOCKET )
		s1 = my_itoa( s1, (long) sock->sock, 10 );
	else
		s1 = my_strcpy( s1, "NONE" );
	if( s1 + 8 >= se )
		goto exit;
	s1 = my_strcpy( s1, ";DOMAIN=" );
	if( s1 + 5 >= se )
		goto exit;
	switch( sock->s_domain ) {
	case AF_INET:
		s1 = my_strcpy( s1, "INET" );
		break;
	case AF_INET6:
		s1 = my_strcpy( s1, "INET6" );
		break;
	case AF_UNIX:
		s1 = my_strcpy( s1, "UNIX" );
		break;
	case AF_BLUETOOTH:
		s1 = my_strcpy( s1, "BTH" );
		break;
	default:
		s1 = my_itoa( s1, sock->s_domain, 10 );
		break;
	}
	if( s1 + 6 >= se )
		goto exit;
	s1 = my_strcpy( s1, ";TYPE=" );
	if( s1 + 6 >= se )
		goto exit;
	switch( sock->s_type ) {
	case SOCK_STREAM:
		s1 = my_strcpy( s1, "STREAM" );
		break;
	case SOCK_DGRAM:
		s1 = my_strcpy( s1, "DGRAM" );
		break;
	case SOCK_RAW:
		s1 = my_strcpy( s1, "RAW" );
		break;
	default:
		s1 = my_itoa( s1, sock->s_type, 10 );
		break;
	}
	if( s1 + 7 >= se )
		goto exit;
	s1 = my_strcpy( s1, ";PROTO=" );
	if( s1 + 6 >= se )
		goto exit;
	switch( sock->s_domain ) {
	case AF_INET:
	case AF_INET6:
		switch( sock->s_proto ) {
		case IPPROTO_TCP:
			s1 = my_strcpy( s1, "TCP" );
			break;
		case IPPROTO_UDP:
			s1 = my_strcpy( s1, "UDP" );
			break;
		case IPPROTO_ICMP:
			s1 = my_strcpy( s1, "ICMP" );
			break;
		default:
			goto unknown_proto;
		}
		break;
	case AF_BLUETOOTH:
		switch( sock->s_proto ) {
		case BTPROTO_RFCOMM:
			s1 = my_strcpy( s1, "RFCOMM" );
			break;
		case BTPROTO_L2CAP:
			s1 = my_strcpy( s1, "L2CAP" );
			break;
		default:
			goto unknown_proto;
		}
		break;
	default:
unknown_proto:
		s1 = my_itoa( s1, sock->s_proto, 10 );
		break;
	}
	if( sock->l_addr.l ) {
		switch( sock->s_domain ) {
		case AF_INET:
			if( s1 + 28 >= se )
				goto exit;
			r = ntohl( ((struct sockaddr_in *) sock->l_addr.a )->sin_addr.s_addr );
			r = sprintf(
				s1,
				";LOCAL=%u.%u.%u.%u:%u",
				IPPORT4( r, ((struct sockaddr_in *) sock->l_addr.a )->sin_port )
			);
			s1 += (size_t ) r;
			break;
		case AF_INET6:
			if( s1 + 54 >= se )
				goto exit;
			p1 = &((struct sockaddr_in6 *) sock->l_addr.a )->sin6_addr;
			r = sprintf(
				s1,
				";LOCAL=[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:%u",
				IPPORT6(
					(uint16_t *) p1,
					((struct sockaddr_in6 *) sock->l_addr.a )->sin6_port
				)
			);
			s1 += (size_t ) r;
			break;
		case AF_UNIX:
			if( s1 + 7 >= se )
				goto exit;
			s1 = my_strcpy( s1, ";LOCAL=" );
			if( s1 + SOCKADDR_SIZE_MAX >= se )
				goto exit;
			s1 = my_strcpy( s1,
				((struct sockaddr_un *) sock->l_addr.a )->sun_path );
			break;
		case AF_BLUETOOTH:
			if( s1 + 7 >= se )
				goto exit;
			s1 = my_strcpy( s1, ";LOCAL=" );
			if( s1 + 17 >= se )
				goto exit;
			s1 += my_ba2str(
				(bdaddr_t *) &sock->l_addr.a[sizeof(sa_family_t)], s1 );
			break;
		}
	}
	if( sock->r_addr.l ) {
		switch( sock->s_domain ) {
		case AF_INET:
			if( s1 + 29 >= se )
				goto exit;
			r = ntohl( ((struct sockaddr_in *) sock->r_addr.a )->sin_addr.s_addr );
			r = sprintf(
				s1,
				";REMOTE=%u.%u.%u.%u:%u",
				IPPORT4( r, ((struct sockaddr_in *) sock->r_addr.a )->sin_port )
			);
			s1 += (size_t ) r;
			break;
		case AF_INET6:
			if( s1 + 55 >= se )
				goto exit;
			p1 = &((struct sockaddr_in6 *) sock->r_addr.a )->sin6_addr;
			r = sprintf(
				s1,
				";REMOTE=[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:%u",
				IPPORT6(
					(uint16_t *) p1,
					((struct sockaddr_in6 *) sock->r_addr.a )->sin6_port
				)
			);
			s1 += (size_t ) r;
			break;
		case AF_UNIX:
			if( s1 + 8 >= se )
				goto exit;
			s1 = my_strcpy( s1, ";REMOTE=" );
			if( s1 + SOCKADDR_SIZE_MAX >= se )
				goto exit;
			s1 = my_strcpy( s1,
				((struct sockaddr_un *) sock->r_addr.a )->sun_path );
			break;
		case AF_BLUETOOTH:
			if( s1 + 8 >= se )
				goto exit;
			s1 = my_strcpy( s1, ";REMOTE=" );
			if( s1 + 17 >= se )
				goto exit;
			s1 += my_ba2str(
				(bdaddr_t *) &sock->r_addr.a[sizeof(sa_family_t)], s1 );
			break;
		}
	}
	if( s1 + 1 < se )
		goto exit;
	*s1 ++ = ')';
	*s1 = '\0';
exit:
	*size = (s1 - str);
	return SC_OK;
}

int mod_sc_get_errno( sc_t *socket ) {
	return socket == NULL ? global.last_errno : socket->last_errno;
}

const char *mod_sc_get_error( sc_t *socket ) {
	if( socket != NULL ) {
		if( socket->last_errno > 0 )
			Socket_error(
				socket->last_error, sizeof( socket->last_error ),
				socket->last_errno
			);
		return socket->last_error;
	}
	GLOBAL_LOCK();
	if( global.last_errno > 0 )
		Socket_error(
			global.last_error, sizeof( global.last_error ), global.last_errno
		);
	GLOBAL_UNLOCK();
	return global.last_error;
}

void mod_sc_set_errno( sc_t *sock, int code ) {
	if( sock != NULL )
		SOCK_ERRNO( sock, code );
	else
		GLOBAL_ERRNO( code );
}

void mod_sc_set_error( sc_t *sock, const char *str ) {
	if( sock != NULL )
		SOCK_ERROR( sock, str );
	else
		GLOBAL_ERROR( -1, str );
}

const mod_sc_t mod_sc = {
	XS_VERSION,
	mod_sc_create,
	mod_sc_create_class,
	mod_sc_destroy,
	mod_sc_destroy_class,
	mod_sc_get_socket,
	mod_sc_connect,
	mod_sc_shutdown,
	mod_sc_close,
	mod_sc_bind,
	mod_sc_listen,
	mod_sc_accept,
	mod_sc_recv,
	mod_sc_send,
	mod_sc_recvfrom,
	mod_sc_sendto,
	mod_sc_read,
	mod_sc_write,
	mod_sc_writeln,
	mod_sc_printf,
	mod_sc_vprintf,
	mod_sc_readline,
	mod_sc_available,
	mod_sc_pack_addr,
	mod_sc_unpack_addr,
	mod_sc_gethostbyaddr,
	mod_sc_gethostbyname,
	mod_sc_getaddrinfo,
	mod_sc_freeaddrinfo,
	mod_sc_getnameinfo,
	mod_sc_set_blocking,
	mod_sc_get_blocking,
	mod_sc_set_reuseaddr,
	mod_sc_get_reuseaddr,
	mod_sc_set_broadcast,
	mod_sc_get_broadcast,
	mod_sc_set_rcvbuf_size,
	mod_sc_get_rcvbuf_size,
	mod_sc_set_sndbuf_size,
	mod_sc_get_sndbuf_size,
	mod_sc_set_tcp_nodelay,
	mod_sc_get_tcp_nodelay,
	mod_sc_setsockopt,
	mod_sc_getsockopt,
	mod_sc_is_readable,
	mod_sc_is_writable,
	mod_sc_select,
	mod_sc_sleep,
	mod_sc_get_handle,
	mod_sc_get_state,
	mod_sc_local_addr,
	mod_sc_remote_addr,
	mod_sc_get_family,
	mod_sc_get_proto,
	mod_sc_get_type,
	mod_sc_to_string,
	mod_sc_get_errno,
	mod_sc_get_error,
	mod_sc_set_errno,
	mod_sc_set_error,
};
