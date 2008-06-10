#include "socket_class.h"

MODULE = Socket::Class		PACKAGE = Socket::Class

#/*****************************************************************************
# * BOOT()
# *****************************************************************************/

BOOT:
{
#ifdef _WIN32
	WSADATA wsaData;
	int iResult = WSAStartup( MAKEWORD(2,2), &wsaData );
	if( iResult != NO_ERROR )
		Perl_croak( aTHX_ "Error at WSAStartup()" );
#endif
	memset( global.first_thread, 0, sizeof( global.first_thread ) );
	memset( global.last_thread, 0, sizeof( global.last_thread ) );
	global.destroyed = 0;
#ifdef USE_ITHREADS
	MUTEX_INIT( &global.thread_lock );
#endif
#ifdef SC_OLDNET
	sv_setiv( get_sv( __PACKAGE__ "::OLDNET", TRUE ), 1 );
#endif
#ifdef SC_HAS_BLUETOOTH
	sv_setiv( get_sv( __PACKAGE__ "::BLUETOOTH", TRUE ), 1 );
	boot_Socket__Class__BT();
#endif
}


#/*****************************************************************************
# * END()
# *****************************************************************************/

void
END( ... )
PREINIT:
	my_thread_var_t *tv1, *tv2;
	u_long cascade;
CODE:
	if( items ) {} /* avoid compiler warning */
	if( global.destroyed )
		return;
	global.destroyed = 1;
#ifdef SC_DEBUG
	_debug( "END called\n" );
#endif
	GLOBAL_LOCK();
	for( cascade = 0; cascade < SC_TV_CASCADE; cascade ++ ) {
		tv1 = global.first_thread[cascade];
		while( tv1 != NULL ) {
			tv2 = tv1->next;
#ifdef SC_DEBUG
			_debug( "freeing tv 0x%08x\n", tv1 );
#endif
			my_thread_var_free( tv1 );
			tv1 = tv2;
		}
		global.first_thread[cascade] = global.last_thread[cascade] = NULL;
	}
	GLOBAL_UNLOCK();
#ifdef USE_ITHREADS
	MUTEX_DESTROY( &global.thread_lock );
#endif
#ifdef _WIN32
	WSACleanup();
#endif


#/*****************************************************************************
# * CLONE()
# *****************************************************************************/

#ifdef USE_ITHREADS

void
CLONE( ... )
PREINIT:
	my_thread_var_t *tv;
	int i;
PPCODE:
	GLOBAL_LOCK();
	for( i = 0; i < SC_TV_CASCADE; i ++ ) {
		for( tv = global.first_thread[i]; tv != NULL; tv = tv->next ) {
#ifdef SC_DEBUG
			_debug( "CLONE called for tv 0x%08X ref: %d\n", tv, tv->refcnt );
#endif
			tv->refcnt ++;
		}
	}
	GLOBAL_UNLOCK();

#endif


#/*****************************************************************************
# * DESTROY( this )
# *****************************************************************************/

void
DESTROY( this, ... )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
#ifdef SC_DEBUG
	_debug( "DESTROY called for tv 0x%08x ref: %d\n", tv, tv->refcnt );
#endif
	tv->refcnt --;
	if( tv->refcnt < 0 ) {
		if( tv->state == SOCK_STATE_CONNECTED )
			shutdown( tv->sock, 2 );
		my_thread_var_rem( tv );
	}


#/*****************************************************************************
# * new( class )
# *****************************************************************************/

void
new( class, ... )
	SV *class;
PREINIT:
	my_thread_var_t *tv;
	SV *sv;
	HV *hv;
	int i, ln = 0, bc = 0, bl = 1, rua = 0;
	STRLEN lkey, lval;
	char *key, *val;
	char *la = NULL, *ra = NULL, *lp = NULL, *rp = NULL;
	double tmo = -1;
	fd_set fds;
	socklen_t sl;
PPCODE:
	Newxz( tv, 1, my_thread_var_t );
	tv->s_domain = AF_INET;
	tv->s_type = SOCK_STREAM;
	tv->s_proto = IPPROTO_TCP;
	tv->timeout.tv_sec = 15;
	/* read options */
	for( i = 1; i < items - 1; i += 2 ) {
		if( ! SvPOK( ST(i) ) )
			continue;
		key = SvPVx( ST(i), lkey );
		if( strcmp( key, "domain" ) == 0 ) {
			if( SvIOK( ST(i + 1) ) ) {
				tv->s_domain = (int) SvIV( ST(i + 1) );
			}
			else {
				val = SvPVx( ST(i + 1), lval );
				tv->s_domain = Socket_domainbyname( val );
			}
			if( tv->s_domain == AF_UNIX ) {
				tv->s_proto = 0;
			}
			else if( tv->s_domain == AF_BLUETOOTH ) {
				tv->s_proto = BTPROTO_RFCOMM;
			}
		}
		else if( strcmp( key, "type" ) == 0 ) {
			if( SvIOK( ST(i + 1) ) ) {
				tv->s_type = (int) SvIV( ST(i + 1) );
			}
			else {
				val = SvPVx( ST(i + 1), lval );
				tv->s_type = Socket_typebyname( val );
			}
		}
		else if( strcmp( key, "proto" ) == 0 ) {
			if( SvIOK( ST(i + 1) ) ) {
				tv->s_proto = (int) SvIV( ST(i + 1) );
			}
			else {
				val = SvPVx( ST(i + 1), lval );
				tv->s_proto = Socket_protobyname( val );
			}
			if( tv->s_proto == IPPROTO_UDP ) {
				tv->s_type = SOCK_DGRAM;
			}
		}
		else if( strcmp( key, "local_addr" ) == 0 ) {
			la = SvPV( ST(i + 1), lval );
		}
		else if( strcmp( key, "local_path" ) == 0 ) {
			la = SvPV( ST(i + 1), lval );
			tv->s_domain = AF_UNIX;
			tv->s_proto = 0;
		}
		else if( strcmp( key, "local_port" ) == 0 ) {
			lp = SvPV( ST(i + 1), lval );
		}
		else if( strcmp( key, "remote_addr" ) == 0 ) {
			ra = SvPV( ST(i + 1), lval );
		}
		else if( strcmp( key, "remote_path" ) == 0 ) {
			ra = SvPV( ST(i + 1), lval );
			tv->s_domain = AF_UNIX;
			tv->s_proto = 0;
		}
		else if( strcmp( key, "remote_port" ) == 0 ) {
			rp = SvPV( ST(i + 1), lval );
		}
		else if( strcmp( key, "listen" ) == 0 ) {
			ln = (int) SvIV( ST(i + 1) );
		}
		else if( strcmp( key, "blocking" ) == 0 ) {
			bl = (int) SvIV( ST(i + 1) );
		}
		else if( strcmp( key, "broadcast" ) == 0 ) {
			bc = (int) SvIV( ST(i + 1) );
		}
		else if( strcmp( key, "reuseaddr" ) == 0 ) {
			rua = (int) SvIV( ST(i + 1) );
		}
		else if( strcmp( key, "timeout" ) == 0 ) {
			tmo = SvNV( ST(i + 1) );
		}
	}
	/* create the socket */
	tv->sock = socket( tv->s_domain, tv->s_type, tv->s_proto );
	if( tv->sock == INVALID_SOCKET ) {
#ifdef SC_DEBUG
		_debug( "socket(%d,%d,%d) create error %d\n",
			tv->s_domain, tv->s_type, tv->s_proto, tv->sock );
#endif
		goto error;
	}
	/* set socket options */
	if( bc &&
		setsockopt(
			tv->sock, SOL_SOCKET, SO_BROADCAST, (void *) &bc, sizeof( int )
		) == SOCKET_ERROR
	) goto error;
	if( rua &&
		setsockopt(
			tv->sock, SOL_SOCKET, SO_REUSEADDR, (void *) &rua, sizeof( int )
		) == SOCKET_ERROR
	) goto error;
	/* set timeout */
	if( tmo >= 0 ) {
		tv->timeout.tv_sec = (long) (tmo / 1000.0);
		tv->timeout.tv_usec = (long) (tv->timeout.tv_sec * 1000 - tmo) * 1000;
	}
	/* bind and listen */
	if( la != NULL || lp != NULL || ln != 0 ) {
		switch( tv->s_domain ) {
		case AF_INET:
		case AF_INET6:
		default:
			i = Socket_setaddr_INET( tv, la, lp, ADDRUSE_LISTEN );
			if( i != 0 ) {
				global.last_errno = i;
				goto error2;
			}
			break;
		case AF_UNIX:
			remove( la );
			Socket_setaddr_UNIX( &tv->l_addr, la );
			break;
		}
#ifdef SC_DEBUG
		_debug( "bind socket %d\n", tv->sock );
#endif
		if( bind(
				tv->sock, (struct sockaddr *) tv->l_addr.a, tv->l_addr.l
			) == SOCKET_ERROR
		) goto error;
		tv->state = SOCK_STATE_BOUND;
		tv->l_addr.l = SOCKADDR_SIZE_MAX;
		getsockname( tv->sock, (struct sockaddr *) tv->l_addr.a, &tv->l_addr.l );
		if( ln != 0 ) {
#ifdef SC_DEBUG
			_debug( "listen on %s %s\n", la, lp );
#endif
			if( listen( tv->sock, ln ) == SOCKET_ERROR )
				goto error;
			tv->state = SOCK_STATE_LISTEN;
		}
	}
	/* connect */
	if( ra != NULL || rp != NULL ) {
		switch( tv->s_domain ) {
		case AF_INET:
		case AF_INET6:
		default:
			i = Socket_setaddr_INET( tv, ra, rp, ADDRUSE_CONNECT );
			if( i != 0 ) {
				global.last_errno = i;
				goto error2;
			}
			break;
		case AF_UNIX:
			Socket_setaddr_UNIX( &tv->r_addr, ra );
			break;
		}
		if( Socket_setblocking( tv->sock, 0 ) == SOCKET_ERROR )
			goto error;
#ifdef SC_DEBUG
		_debug( "connect to %s %s\n", ra, rp );
#endif
		if( connect(
				tv->sock, (struct sockaddr *) tv->r_addr.a, tv->r_addr.l
			) == SOCKET_ERROR
		) {
			i = Socket_errno();
			if( i == EINPROGRESS || i == EWOULDBLOCK ) {
				FD_ZERO( &fds ); 
				FD_SET( tv->sock, &fds );
				if( select(
						(int) (tv->sock + 1), NULL, &fds, NULL, &tv->timeout
					) > 0
				) {
					sl = sizeof( int );
					if( getsockopt(
							tv->sock, SOL_SOCKET, SO_ERROR, (void *) (&i), &sl
						) == SOCKET_ERROR
					) {
						goto error;
					}
					if( i ) {
#ifdef SC_DEBUG
						_debug( "getsockopt SO_ERROR %d\n", i );
#endif
						global.last_errno = i;
						goto error2;
					}
				}
				else {
#ifdef SC_DEBUG
					_debug( "connect timed out %u\n", ETIMEDOUT );
#endif
					global.last_errno = ETIMEDOUT;
					goto error2;
				}	
			}
			else {
#ifdef SC_DEBUG
				_debug( "connect failed %d\n", i );
#endif
				global.last_errno = i;
				goto error2;
			}
		}
		if( bl ) {
			if( Socket_setblocking( tv->sock, 1 ) == SOCKET_ERROR )
				goto error;
		}
		else
			tv->non_blocking = 1;
		tv->l_addr.l = SOCKADDR_SIZE_MAX;
		getsockname( tv->sock, (struct sockaddr *) tv->l_addr.a, &tv->l_addr.l );
		tv->state = SOCK_STATE_CONNECTED;
	}
	if( ! bl && ! tv->non_blocking ) {
		if( Socket_setblocking( tv->sock, 0 ) == SOCKET_ERROR )
			goto error;
		tv->non_blocking = 1;
	}
	/* create the class */
	sv = sv_2mortal( newSViv( PTR2IV( tv ) ) );
	key = SvPV( class, lkey );
	Newx( tv->classname, lkey + 1, char );
	Copy( key, tv->classname, lkey + 1, char );
#ifdef SC_DEBUG
	_debug( "bless socket %d to %s\n", tv->sock, key );
#endif
	hv = gv_stashpv( key, 0 );
	ST(0) = sv_2mortal( sv_bless( newRV( sv ), hv ) );
	my_thread_var_add( tv );
	global.last_errno = 0;
	global.last_error[0] = '\0';
	XSRETURN( 1 );
error:
	GLOBAL_ERRNOLAST();
error2:
	XSRETURN_EMPTY;


#/*****************************************************************************
# * connect( this )
# *****************************************************************************/

void
connect( this, ... )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	STRLEN l1, l2;
	const char *s1, *s2;
	fd_set fds;
	int r;
	socklen_t sl;
	double ms;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	tv->last_error[0] = '\0';
	switch( tv->s_domain ) {
	case AF_INET:
	case AF_INET6:
	default:
		switch( items ) {
		case 4:
		default:
			if( SvNOK( ST(3) ) || SvIOK( ST(3) ) ) {
				ms = SvNV( ST(3) );
				tv->timeout.tv_sec = (long) (ms / 1000);
				tv->timeout.tv_usec = (long) (ms * 1000) % 1000000;
			}
		case 3:
			s1 = SvPV( ST(1), l1 );
			s2 = SvPV( ST(2), l2 );
			tv->last_errno =
				Socket_setaddr_INET( tv, s1, s2, ADDRUSE_CONNECT );
			if( tv->last_errno != 0 )
				goto error;
			break;
		case 2:
			s1 = SvPV( ST(1), l1 );
			tv->last_errno =
				Socket_setaddr_INET( tv, s1, NULL, ADDRUSE_CONNECT );
			if( tv->last_errno != 0 )
				goto error;
			break;
		case 1:
			if( tv->state != SOCK_STATE_CLOSED ) {
				tv->last_errno =
					Socket_setaddr_INET( tv, NULL, NULL, ADDRUSE_CONNECT );
				if( tv->last_errno != 0 )
					goto error;
			}
			break;
		}
		break;
	case AF_UNIX:
		switch( items ) {
		case 3:
		default:
			if( SvNOK( ST(2) ) || SvIOK( ST(2) ) ) {
				ms = SvNV( ST(2) );
				tv->timeout.tv_sec = (long) (ms / 1000);
				tv->timeout.tv_usec = (long) (ms * 1000) % 1000000;
			}
		case 2:
			s1 = SvPV( ST(1), l1 );
			Socket_setaddr_UNIX( &tv->r_addr, s1 );
			break;
		case 1:
			if( tv->state != SOCK_STATE_CLOSED ) {
				Socket_setaddr_UNIX( &tv->r_addr, NULL );
			}
			break;
		}
		break;
	}
	if( tv->state == SOCK_STATE_CONNECTED ) {
		Socket_close( tv->sock );
		tv->state = SOCK_STATE_CLOSED;
	}
	if( tv->sock == INVALID_SOCKET ) {
		tv->sock = socket( tv->s_domain, tv->s_type, tv->s_proto );
		if( tv->sock == INVALID_SOCKET ) {
			tv->last_errno = Socket_errno();
			goto error;
		}
	}
#ifdef SC_DEBUG
	_debug( "connecting socket %d state %d addrlen %d\n",
		tv->sock, tv->state, tv->r_addr.l );
#endif
	if( ! tv->non_blocking ) {
		if( Socket_setblocking( tv->sock, 0 ) == SOCKET_ERROR ) {
			tv->last_errno = Socket_errno();
			goto error;
		}
	}
	if( connect( tv->sock, (struct sockaddr *) tv->r_addr.a, tv->r_addr.l )
		== SOCKET_ERROR
	) {
		r = Socket_errno();
		if( r == EINPROGRESS || r == EWOULDBLOCK ) {
			FD_ZERO( &fds ); 
			FD_SET( tv->sock, &fds );
			if( select(
					(int) (tv->sock + 1), NULL, &fds, NULL, &tv->timeout
				) > 0
			) {
				sl = sizeof( int );
				if( getsockopt(
						tv->sock, SOL_SOCKET, SO_ERROR, (void*) (&r), &sl
					) == SOCKET_ERROR
				) {
					tv->last_errno = Socket_errno();
					goto error;
				}
				if( r ) {
#ifdef SC_DEBUG
					_debug( "getsockopt SO_ERROR %d\n", r );
#endif
					tv->last_errno = r;
					goto error;
				}
			}
			else {
#ifdef SC_DEBUG
				_debug( "connect timed out %u\n", ETIMEDOUT );
#endif
				tv->last_errno = ETIMEDOUT;
				goto error;
			}	
		}
		else {
#ifdef SC_DEBUG
			_debug( "connect failed %d\n", r );
#endif
			tv->last_errno = r;
			goto error;
		}
	}
	if( ! tv->non_blocking ) {
		if( Socket_setblocking( tv->sock, 1 ) == SOCKET_ERROR ) {
			tv->last_errno = Socket_errno();
			goto error;
		}
	}
	tv->l_addr.l = SOCKADDR_SIZE_MAX;
	getsockname( tv->sock, (struct sockaddr *) tv->l_addr.a, &tv->l_addr.l );
	tv->state = SOCK_STATE_CONNECTED;
	tv->last_errno = 0;
	TV_UNLOCK( tv );
	XSRETURN_YES;
error:
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * free( this )
# *****************************************************************************/

void
free( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	my_thread_var_rem( tv );
	XSRETURN_YES;


#/*****************************************************************************
# * close( this )
# *****************************************************************************/

void
close( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
#ifdef SC_DEBUG
	_debug( "closing socket %d tv %u\n", tv->sock, tv );
#endif
	Socket_close( tv->sock );
	if( tv->s_domain == AF_UNIX ) {
		remove( ((struct sockaddr_un *) tv->l_addr.a)->sun_path );
	}
	tv->state = SOCK_STATE_CLOSED;
	memset( &tv->l_addr, 0, sizeof( tv->l_addr ) );
	memset( &tv->r_addr, 0, sizeof( tv->r_addr ) );
	TV_UNLOCK( tv );
	XSRETURN_YES;


#/*****************************************************************************
# * shutdown( this )
# *****************************************************************************/

void
shutdown( this, how = 0 )
	SV *this;
	int how
PREINIT:
	my_thread_var_t *tv;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	r = shutdown( tv->sock, how );
	if( r == SOCKET_ERROR ) {
		tv->last_errno = Socket_errno();
		tv->state = SOCK_STATE_ERROR;
		TV_UNLOCK( tv );
		XSRETURN_EMPTY;
	}
	else {
		tv->last_errno = 0;
		tv->state = SOCK_STATE_SHUTDOWN;
		TV_UNLOCK( tv );
		XSRETURN_YES;
	}


#/*****************************************************************************
# * bind( this )
# *****************************************************************************/

void
bind( this, ... )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	STRLEN l1;
	const char *s1, *s2;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	tv->last_error[0] = '\0';
	switch( tv->s_domain ) {
	case AF_INET:
	case AF_INET6:
	default:
		switch( items ) {
		case 3:
			s1 = SvPV( ST(1), l1 );
			s2 = SvPV( ST(2), l1 );
			tv->last_errno = Socket_setaddr_INET( tv, s1, s2, ADDRUSE_LISTEN );
			if( tv->last_errno != 0 )
				goto error;
			break;
		case 2:
			s1 = SvPV( ST(1), l1 );
			tv->last_errno = Socket_setaddr_INET( tv, s1, NULL, ADDRUSE_LISTEN );
			if( tv->last_errno != 0 )
				goto error;
			break;
		case 1:
			if( tv->state != SOCK_STATE_CLOSED ) {
				tv->last_errno = Socket_setaddr_INET( tv, NULL, NULL, ADDRUSE_LISTEN );
				if( tv->last_errno != 0 )
					goto error;
			}
			break;
		}
		break;
	case AF_UNIX:
		switch( items ) {
		case 2:
			s1 = SvPV( ST(1), l1 );
			Socket_setaddr_UNIX( &tv->l_addr, s1 );
			break;
		case 1:
			if( tv->state != SOCK_STATE_CLOSED ) {
				Socket_setaddr_UNIX( &tv->l_addr, NULL );
			}
			break;
		}
		remove( ((struct sockaddr_un *) tv->l_addr.a)->sun_path );
		break;
	}
	if( tv->sock == INVALID_SOCKET ) {
		tv->sock = socket( tv->s_domain, tv->s_type, tv->s_proto );
		if( tv->sock == INVALID_SOCKET ) {
			tv->last_errno = Socket_errno();
			goto error;
		}
	}
	if( bind( tv->sock, (struct sockaddr *) tv->l_addr.a, tv->l_addr.l )
		== SOCKET_ERROR
	) {
		tv->last_errno = Socket_errno();
		goto error;
	}
	getsockname( tv->sock, (struct sockaddr *) tv->l_addr.a, &tv->l_addr.l );
	tv->state = SOCK_STATE_BOUND;
	tv->last_errno = 0;
	TV_UNLOCK( tv );
	XSRETURN_YES;
error:
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * listen( this )
# *****************************************************************************/

void
listen( this, queue = SOMAXCONN )
	SV *this;
	int queue;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( listen( tv->sock, queue ) == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		TV_UNLOCK( tv );
		XSRETURN_EMPTY;
	}
	TV_ERRNO( tv, 0 );
	tv->state = SOCK_STATE_LISTEN;
	TV_UNLOCK( tv );
	XSRETURN_YES;


#/*****************************************************************************
# * accept( this )
# *****************************************************************************/

void
accept( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv, *tv2;
	SOCKET s;
	my_sockaddr_t addr;
	SV *sv;
	HV *hv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	addr.l = SOCKADDR_SIZE_MAX;
	s = accept( tv->sock, (struct sockaddr *) addr.a, &addr.l );
	if( s == INVALID_SOCKET ) {			
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "accept error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	Newxz( tv2, 1, my_thread_var_t );
#ifdef SC_DEBUG
	_debug( "accepting socket %d tv 0x%08x %u:%u\n", s, tv2, tv->l_addr.l, addr.l );
#endif
	tv2->s_domain = tv->s_domain;
	tv2->s_type = tv->s_type;
	tv2->s_proto = tv->s_proto;
	tv2->sock = s;
	tv2->state = SOCK_STATE_CONNECTED;
	Copy( &addr, &tv2->r_addr, MYSASIZE( addr ), BYTE );
	tv2->l_addr.l = SOCKADDR_SIZE_MAX;
	getsockname( s, (struct sockaddr *) tv2->l_addr.a, &tv2->l_addr.l );
	sv = sv_2mortal( newSViv( PTR2IV( tv2 ) ) );
	hv = gv_stashpv( tv->classname, 0 );
	ST(0) = sv_2mortal( sv_bless( newRV( sv ), hv ) );
	my_thread_var_add( tv2 );
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * recv( this, buf, len [, flags] )
# *****************************************************************************/

void
recv( this, buf, len, flags = 0 )
	SV *this;
	SV *buf;
	size_t len;
	unsigned long flags;
PREINIT:
	my_thread_var_t *tv;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( tv->rcvbuf_len < len ) {
		tv->rcvbuf_len = len;
		Renew( tv->rcvbuf, len, char );
	}
	r = recv( tv->sock, tv->rcvbuf, (int) len, flags );
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "recv error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	else if( r != 0 ) {
		tv->last_errno = 0;
		sv_setpvn( buf, tv->rcvbuf, r );
		TV_UNLOCK( tv );
		XSRETURN_IV( r );
	}
	tv->last_errno = ECONNRESET;
	tv->state = SOCK_STATE_ERROR;
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * send( this, buf [, flags] )
# *****************************************************************************/

void
send( this, buf, flags = 0 )
	SV *this;
	SV *buf;
	unsigned long flags;
PREINIT:
	my_thread_var_t *tv;
	const char *msg;
	STRLEN len;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	msg = SvPV( buf, len );
	r = send( tv->sock, msg, (int) len, flags );
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "send error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	else if( r != 0 ) {
		tv->last_errno = 0;
		TV_UNLOCK( tv );
		XSRETURN_IV( r );
	}
	tv->last_errno = ECONNRESET;
#ifdef SC_DEBUG
	_debug( "send error %u\n", tv->last_errno );
#endif
	tv->state = SOCK_STATE_ERROR;
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * recvfrom( this, buf, len [, flags] )
# *****************************************************************************/

void
recvfrom( this, buf, len, flags = 0 )
	SV *this;
	SV *buf;
	size_t len;
	unsigned long flags;
PREINIT:
	my_thread_var_t *tv;
	int r;
	my_sockaddr_t peer;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( tv->rcvbuf_len < len ) {
		tv->rcvbuf_len = len;
		Renew( tv->rcvbuf, len, char );
	}
	peer.l = SOCKADDR_SIZE_MAX;
	r = recvfrom(
		tv->sock, tv->rcvbuf, (int) len, flags,
		(struct sockaddr *) peer.a, &peer.l
	);
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "recvfrom error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	else if( r != 0 ) {
		tv->last_errno = 0;
		sv_setpvn( buf, tv->rcvbuf, r );
		/* remember who we received from */
		Copy( &peer, &tv->r_addr, peer.l + sizeof( int ), BYTE );
		TV_UNLOCK( tv );
		ST(0) = sv_2mortal( newSVpvn( (char *) &peer, MYSASIZE( peer ) ) );
		XSRETURN( 1 );
	}
	tv->last_errno = ECONNRESET;
	tv->state = SOCK_STATE_ERROR;
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * sendto( this, buf [, to [, flags]] )
# *****************************************************************************/

void
sendto( this, buf, to = NULL, flags = 0 )
	SV *this;
	SV *buf;
	SV *to;
	unsigned long flags;
PREINIT:
	my_thread_var_t *tv;
	const char *msg;
	STRLEN len;
	my_sockaddr_t *peer;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( to != NULL && SvPOK( to ) ) {
		peer = (my_sockaddr_t *) SvPVbyte( to, len );
		if( len < sizeof( int ) || len != MYSASIZE(*peer) ) {
			snprintf(
				global.last_error, sizeof( global.last_error ),
				"Invalid address"
			);
		}
		/* remember who we send to */
		Copy( peer, &tv->r_addr, len, BYTE );
	}
	else {
		peer = &tv->r_addr;
	}
	msg = SvPV( buf, len );
	r = sendto(
		tv->sock, msg, (int) len, flags,
		(struct sockaddr *) peer->a, peer->l
	);
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "sendto error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	else if( r != 0 ) {
		tv->last_errno = 0;
		TV_UNLOCK( tv );
		XSRETURN_IV( r );
	}
	tv->last_errno = ECONNRESET;
	tv->state = SOCK_STATE_ERROR;
	TV_UNLOCK( tv );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * read( this, buf, len )
# *****************************************************************************/

void
read( this, buf, len )
	SV *this;
	SV *buf;
	size_t len;
PREINIT:
	my_thread_var_t *tv;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( tv->rcvbuf_len < len ) {
		tv->rcvbuf_len = len;
		Renew( tv->rcvbuf, len, char );
	}
	r = recv( tv->sock, tv->rcvbuf, (int) len, 0 );
	if( r == SOCKET_ERROR ) {
		sv_setpvn( buf, "", 0 );
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			TV_UNLOCK( tv );
			XSRETURN_NO;
		default:
#ifdef SC_DEBUG
			_debug( "read error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			TV_UNLOCK( tv );
			XSRETURN_EMPTY;
		}
	}
	else if( r == 0 ) {
		tv->last_errno = ECONNRESET;
#ifdef SC_DEBUG
		_debug( "read error %u\n", tv->last_errno );
#endif
		tv->state = SOCK_STATE_ERROR;
		TV_UNLOCK( tv );
		XSRETURN_EMPTY;
	}
	tv->last_errno = 0;
	sv_setpvn( buf, tv->rcvbuf, r );
	TV_UNLOCK( tv );
	XSRETURN_IV( r );


#/*****************************************************************************
# * write( this, buf [, start [, length]] )
# *****************************************************************************/

void
write( this, buf, ... )
	SV *this;
	SV *buf;
PREINIT:
	const char *msg;
	STRLEN l1;
	int r, start = 0, len, max, l2;
PPCODE:
	msg = SvPV( buf, l1 );
	max = len = (int) l1;
	if( items > 2 ) {
		start = (int) SvIV( ST(2) );
		if( start < 0 ) {
			start += max;
			if( start < 0 )
				start = 0;
		}
		else if( start >= max )
			XSRETURN_IV( 0 );
	}
	if( items > 3 ) {
		l2 = (int) SvIV( ST(3) );
		if( l2 < 0 )
			len += l2;
		else if( l2 < len )
			len = l2;
	}
	if( start + len > max )
		len = max - start;
	if( len <= 0 )
		XSRETURN_IV( 0 );
	r = Socket_write( this, msg + (size_t) start, (size_t) len );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( r );
	else
		XSRETURN_EMPTY;


#/*****************************************************************************
# * writeline( this, buf )
# *****************************************************************************/

void
writeline( this, buf )
	SV *this;
	SV *buf;
PREINIT:
	const char *msg;
	char *tmp;
	STRLEN len;
	int r;
PPCODE:
	msg = SvPVx( buf, len );
	Newx( tmp, len + 1, char );
	Copy( msg, tmp, len, char );
	tmp[len] = '\n';
	r = Socket_write( this, tmp, len + 1 );
	Safefree( tmp );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( r );
	else
		XSRETURN_EMPTY;


#/*****************************************************************************
# * print( this )
# *****************************************************************************/

void
print( this, ... )
	SV *this;
PREINIT:
	const char *s1;
	char *tmp = NULL;
	STRLEN l1, len = 0, pos = 0;
	int r;
PPCODE:
	for( r = 1; r < items; r ++ ) {
		if( ! SvOK( ST(r) ) )
			continue;
		s1 = SvPV( ST(r), l1 );
		if( pos + l1 > len ) {
			len = pos + l1 + 64;
			Renew( tmp, len, char );
		}
		Copy( s1, tmp + pos, l1, char );
		pos += l1;
	}
	if( tmp != NULL ) {
		r = Socket_write( this, tmp, pos );
		Safefree( tmp );
		if( r != SOCKET_ERROR )
			XSRETURN_IV( r );
		else
			XSRETURN_EMPTY;
	}


#/*****************************************************************************
# * readline( this )
# *****************************************************************************/

void
readline( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	int r;
	size_t i, pos = 0, len = 256;
	char *p;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	p = tv->rcvbuf;
	while( 1 ) {
		if( tv->rcvbuf_len < pos + len ) {
			tv->rcvbuf_len = pos + len;
			Renew( tv->rcvbuf, tv->rcvbuf_len, char );
			p = tv->rcvbuf + pos;
		}
		r = recv( tv->sock, p, (int) len, MSG_PEEK );
		if( r == SOCKET_ERROR ) {
			if( pos > 0 )
				break;
			tv->last_errno = Socket_errno();
			switch( tv->last_errno ) {
			case EWOULDBLOCK:
				/* threat not as an error */
				tv->last_errno = 0;
				ST(0) = sv_2mortal( newSVpvn( "", 0 ) );
				break;
			default:
#ifdef SC_DEBUG
				_debug( "readline error %u\n", tv->last_errno );
#endif
				tv->state = SOCK_STATE_ERROR;
				ST(0) = &PL_sv_undef;
				break;
			}
			goto exit;
		}
		else if( r == 0 ) {
			if( pos > 0 )
				break;
			tv->last_errno = ECONNRESET;
#ifdef SC_DEBUG
			_debug( "readline error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			ST(0) = &PL_sv_undef;
			goto exit;
		}
		for( i = 0; i < (size_t) r; i ++, p ++ ) {
			if( *p != '\n' && *p != '\r' && *p != '\0' )
				continue;
			/* found newline */
#ifdef SC_DEBUG
			_debug( "found newline at %d + %d of %d\n", pos, i, r );
#endif
			ST(0) = sv_2mortal( newSVpvn( tv->rcvbuf, pos + i ) );
			if( *p == '\r' ) {
				if( i < (size_t) r ) {
					if( p[1] == '\n' )
						i ++;
				}
				else if( r == (int) len ) {
					r = recv( tv->sock, p, 1, MSG_PEEK );
					if( r == 1 && *p == '\n' )
						recv( tv->sock, p, 1, 0 );
				}
			}
			recv( tv->sock, tv->rcvbuf + pos, (int) i + 1, 0 );
			goto exit;
		}
		recv( tv->sock, tv->rcvbuf + pos, (int) i, 0 );
		pos += i;
		if( r < (int) len )
			break;
	}
	ST(0) = sv_2mortal( newSVpvn( tv->rcvbuf, pos ) );
exit:
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * available( this )
# *****************************************************************************/

void
available( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	socklen_t ol = sizeof(int);
	int r, len;
	char *tmp = NULL;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	r = getsockopt( tv->sock, SOL_SOCKET, SO_RCVBUF, (char *) &len, &ol );
	if( r != 0 ) {
		tv->last_errno = Socket_errno();
		tv->state = SOCK_STATE_ERROR;
		ST(0) = &PL_sv_undef;
		goto exit;
	}
	Newx( tmp, len, char );
	r = recv( tv->sock, tmp, len, MSG_PEEK );
	switch( r ) {
	case SOCKET_ERROR:
		tv->last_errno = Socket_errno();
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			ST(0) = sv_2mortal( newSViv( 0 ) );
			break;
		default:
			tv->state = SOCK_STATE_ERROR;
			ST(0) = &PL_sv_undef;
			break;
		}
		goto exit;
	case 0:
		tv->last_errno = ECONNRESET;
		tv->state = SOCK_STATE_ERROR;
		ST(0) = &PL_sv_undef;
		goto exit;
	}
	ST(0) = sv_2mortal( newSViv( r ) );
exit:
	Safefree( tmp );
	TV_UNLOCK( tv );
	XSRETURN(1);


#/*****************************************************************************
# * pack_addr( this, addr [, port] )
# *****************************************************************************/

void
pack_addr( this, addr, ... )
	SV *this;
	SV *addr;
PREINIT:
	my_thread_var_t *tv;
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	const char *s2;
	int r;
#else
	struct hostent *he;
#endif
	const char *s1;
	my_sockaddr_t saddr;
	STRLEN len;
	SOCKADDR_L2CAP *l2a;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_UNIX:
		s1 = SvPV( addr, len );
		Socket_setaddr_UNIX( &saddr, s1 );
		ST(0) = sv_2mortal( newSVpvn( (char *) &saddr, MYSASIZE(saddr) ) );
		break;
	case AF_BLUETOOTH:
		if( tv->s_proto == BTPROTO_L2CAP ) {
			saddr.l = sizeof( SOCKADDR_L2CAP );
			l2a = (SOCKADDR_L2CAP *) saddr.a;
			l2a->bt_family = AF_BLUETOOTH;
			my_str2ba( SvPV( addr, len ), &l2a->bt_bdaddr );
			l2a->bt_port = items > 2 ? (uint8_t) SvIV( ST(2) ) : 0;
			ST(0) = sv_2mortal( newSVpvn( (char *) &saddr, MYSASIZE(saddr) ) );
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
		aih.ai_family = tv->s_domain;
		aih.ai_socktype = tv->s_type;
		aih.ai_protocol = tv->s_proto;
		s1 = SvPV( addr, len );
		s2 = items > 2 ? SvPV( ST(2), len ) : NULL;
		r = getaddrinfo( s1, s2, &aih, &ail );
		if( r != 0 ) {
#ifdef SC_DEBUG
			_debug( "getaddrinfo('%s', '%s') failed %d\n", s1, s2, r );
#endif
			TV_ERRNO( tv, r );
#ifndef _WIN32
			{
				const char *s1 = gai_strerror( r );
				strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
			}
#endif
			ST(0) = &PL_sv_undef;
			goto exit;
		}
		saddr.l = (socklen_t) ail->ai_addrlen;
		memcpy( saddr.a, ail->ai_addr, ail->ai_addrlen );
		freeaddrinfo( ail );
		ST(0) = sv_2mortal( newSVpvn( (char *) &saddr, MYSASIZE(saddr) ) );
		break;
#else
	case AF_INET:
		GLOBAL_LOCK();
		s1 = SvPV( addr, len );
		saddr.l = sizeof( struct sockaddr_in );
		memset( saddr.a, 0, saddr.l );
		((struct sockaddr_in *) saddr.a)->sin_family = AF_INET;
		if( s1[0] >= '0' && s1[0] <= '9' ) {
			((struct sockaddr_in *) saddr.a)->sin_addr.s_addr = inet_addr( s1 );
		}
		else {
			he = gethostbyname( s1 );
			if( he == NULL ) {
				TV_ERRNOLAST( tv );
				ST(0) = &PL_sv_undef;
				goto _inet4e;
			}
			((struct sockaddr_in *) saddr.a)->sin_addr =
				*(struct in_addr*) he->h_addr;
		}
		if( items > 2 ) {
			s1 = SvPV( ST(2), len );
			if( s1[0] >= '0' && s1[0] <= '9' )
				((struct sockaddr_in *) saddr.a)->sin_port
					= htons( atoi( s1 ) );
			else {
				struct servent *se;
				se = getservbyname( s1, NULL );
				if( se == NULL ) {
					TV_ERRNOLAST( tv );
					ST(0) = &PL_sv_undef;
					goto _inet4e;
				}
				((struct sockaddr_in *) saddr.a)->sin_port = se->s_port;
			}
		}
		ST(0) = sv_2mortal( newSVpvn( (char *) &saddr, MYSASIZE(saddr) ) );
_inet4e:
		GLOBAL_UNLOCK();
		break;
	case AF_INET6:
		GLOBAL_LOCK();
		s1 = SvPV( addr, len );
		saddr.l = sizeof( struct sockaddr_in6 );
		memset( saddr.a, 0, saddr.l );
		((struct sockaddr_in6 *) saddr.a)->sin6_family = AF_INET6;
#ifndef _WIN32
		if( ( s1[0] >= '0' && s1[0] <= '9' ) || s1[0] == ':' ) {
			if( inet_pton(
					AF_INET6, s1, &((struct sockaddr_in6 *) saddr.a)->sin6_addr
				) != 0 )
			{
#ifdef SC_DEBUG
				_debug( "inet_pton failed %d\n", Socket_errno() );
#endif
				TV_ERRNOLAST( tv );
				ST(0) = &PL_sv_undef;
				goto _inet6e;
			}
		}
		else {
			he = gethostbyname( s1 );
			if( he == NULL ) {
				TV_ERRNOLAST( tv );
				ST(0) = &PL_sv_undef;
				goto _inet6e;
			}
			if( he->h_addrtype != AF_INET6 ) {
				TV_ERROR( tv, "invalid address family type" );
				ST(0) = &PL_sv_undef;
				goto _inet6e;
			}
			Copy(
				he->h_addr, &((struct sockaddr_in6 *) saddr.a)->sin6_addr,
				he->h_length, char
			);
		}
		if( items > 2 ) {
			s1 = SvPV( ST(2), len );
			if( s1[0] >= '0' && s1[0] <= '9' )
				((struct sockaddr_in6 *) saddr.a)->sin6_port
					= htons( atol( s1 ) );
			else {
				struct servent *se;
				se = getservbyname( s1, NULL );
				if( se == NULL ) {
					TV_ERRNOLAST( tv );
					ST(0) = &PL_sv_undef;
					goto _inet6e;
				}
				((struct sockaddr_in6 *) saddr.a)->sin6_port = se->s_port;
			}
		}
#endif
		ST(0) = sv_2mortal( newSVpvn( (char *) &saddr, MYSASIZE(saddr) ) );
_inet6e:
		GLOBAL_UNLOCK();
		break;
	default:
_default:
		goto exit;
#endif
	}
exit:
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * unpack_addr( this, addr )
# *****************************************************************************/

void
unpack_addr( this, addr )
	SV *this;
	SV *addr;
PREINIT:
	my_thread_var_t *tv;
	STRLEN len;
	my_sockaddr_t *saddr;
	SOCKADDR_L2CAP *l2a;
	char tmp[40], *s1;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	saddr = (my_sockaddr_t *) SvPVbyte( addr, len );
	if( len < sizeof( int ) || len != MYSASIZE(*saddr) ) {
		snprintf(
			tv->last_error, sizeof( tv->last_error ),
			"Invalid address"
		);
	}
	switch( tv->s_domain ) {
	case AF_UNIX:
		s1 = ((struct sockaddr_un *) saddr->a )->sun_path;
		XPUSHs( sv_2mortal( newSVpvn( s1, strlen( s1 ) ) ) );
		break;
	case AF_BLUETOOTH:
		if( tv->s_proto == BTPROTO_L2CAP ) {
			l2a = (SOCKADDR_L2CAP *) saddr->a;
			r = my_ba2str( &l2a->bt_bdaddr, tmp );
			XPUSHs( sv_2mortal( newSVpv( tmp, r ) ) );
			XPUSHs( sv_2mortal( newSViv( l2a->bt_port ) ) );
		}
		break;
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) saddr->a )->sin_addr.s_addr );
		r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
		XPUSHs( sv_2mortal( newSVpv( tmp, r ) ) );
		XPUSHs( sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in *) saddr->a )->sin_port ) ) ) );
		break;
	case AF_INET6:
		s1 = (char *) &((struct sockaddr_in6 *) saddr->a )->sin6_addr;
		r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) s1 )
		);
		XPUSHs( sv_2mortal( newSVpv( tmp, r ) ) );
		XPUSHs( sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in6 *) saddr->a )->sin6_port ) ) ) );
		break;
	}
	TV_UNLOCK( tv );
	

#/*****************************************************************************
# * get_hostname( this, addr )
# *****************************************************************************/

void
get_hostname( this, addr = NULL )
	SV *this;
	SV *addr;
PREINIT:
	my_thread_var_t *tv;
	my_sockaddr_t *saddr;
	const char *s1 = NULL;
	STRLEN l1;
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	char host[NI_MAXHOST], serv[NI_MAXSERV];
	my_sockaddr_t sa2;
	int r;
#else
	struct hostent *he;
	struct in_addr ia4;
	struct in6_addr ia6;
#endif
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( addr != NULL ) {
		s1 = SvPV( addr, l1 );
		saddr = (my_sockaddr_t *) s1;
	}
	else {
		saddr = &tv->r_addr;
		l1 = MYSASIZE(tv->r_addr);
	}
#ifndef SC_OLDNET
	if( l1 <= sizeof( int ) || l1 != MYSASIZE(*saddr) ) {
		memset( &aih, 0, sizeof( struct addrinfo ) );
		/*
		aih.ai_family = tv->s_domain;
		aih.ai_socktype = tv->s_type;
		aih.ai_protocol = tv->s_proto;
		*/
		r = getaddrinfo( s1, "", &aih, &ail );
		if( r != 0 ) {
#ifdef SC_DEBUG
			_debug( "getaddrinfo() failed %d\n", r );
#endif
			TV_ERRNO( tv, r );
#ifndef _WIN32
			{
				const char *s1 = gai_strerror( r );
				strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
			}
#endif
			ST(0) = &PL_sv_undef;
			goto exit;
		}
		sa2.l = (int) ail->ai_addrlen;
		memcpy( sa2.a, ail->ai_addr, ail->ai_addrlen );
		freeaddrinfo( ail );
		saddr = &sa2;
	}
	r = getnameinfo(
		(struct sockaddr *) saddr->a, saddr->l,
		host, sizeof( host ),
		serv, sizeof( serv ),
		NI_NUMERICSERV | NI_NAMEREQD
	);
	if( r != 0 ) {
#ifdef SC_DEBUG
		_debug( "getnameinfo failed %d\n", r );
#endif
#ifndef _WIN32
		{
			const char *s1 = gai_strerror( r );
			strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
		}
#endif
		tv->last_errno = r;
		ST(0) = &PL_sv_undef;
		goto exit;
	}
	ST(0) = sv_2mortal( newSVpvn( host, strlen( host ) ) );
#else
	GLOBAL_LOCK();
	if( l1 <= sizeof( int ) || l1 != MYSASIZE(*saddr) ) {
		if( tv->s_domain == AF_INET ) {
			if( inet_aton( s1, &ia4 ) == 0 ) {
				TV_ERROR( tv, "invalid address" );
				ST(0) = &PL_sv_undef;
				goto unlock;
			}
			he = gethostbyaddr( (const char *) &ia4, sizeof( ia4 ), AF_INET );
			if( he == NULL ) {
				TV_ERRNOLAST( tv );
				ST(0) = &PL_sv_undef;
				goto unlock;
			}
			TV_ERRNO( tv, 0 );
			ST(0) = sv_2mortal( newSVpvn( he->h_name, strlen( he->h_name ) ) );
		}
		else if( tv->s_domain == AF_INET6 ) {
#ifndef _WIN32
			if( inet_pton( AF_INET6, s1, &ia6 ) <= 0 ) {
				TV_ERROR( tv, "invalid address" );
				goto unlock;
			}
			he = gethostbyaddr( (const char *) &ia6, sizeof( ia6 ), AF_INET6 );
			if( he == NULL ) {
				TV_ERRNOLAST( tv );
				ST(0) = &PL_sv_undef;
				goto unlock;
			}
			TV_ERRNO( tv, 0 );
			ST(0) = sv_2mortal( newSVpvn( he->h_name, strlen( he->h_name ) ) );
#else
			TV_ERROR( tv, "not supported on this platform" );
			ST(0) = &PL_sv_undef;
#endif
		}
	}
	else {
		if( tv->s_domain == AF_INET ) {
			he = gethostbyaddr(
				(const char *) &((struct sockaddr_in *) saddr->a)->sin_addr,
				sizeof( ia4 ), AF_INET
			);
		}
		else if( tv->s_domain == AF_INET6 ) {
			he = gethostbyaddr(
				(const char *) &((struct sockaddr_in6 *) saddr->a)->sin6_addr,
				sizeof( ia6 ), AF_INET6
			);
		}
		else {
			TV_ERRNO( tv, 0 );
			ST(0) = &PL_sv_undef;
			goto unlock;
		}
		if( he == NULL ) {
			TV_ERRNOLAST( tv );
			ST(0) = &PL_sv_undef;
			goto unlock;
		}
		TV_ERRNO( tv, 0 );
		ST(0) = sv_2mortal( newSVpvn( he->h_name, strlen( he->h_name ) ) );
	}
unlock:
	GLOBAL_UNLOCK();
	goto exit;
#endif
exit:
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * get_hostaddr( this, name )
# *****************************************************************************/

void
get_hostaddr( this, name )
	SV *this;
	SV *name;
PREINIT:
	my_thread_var_t *tv;
	char *sname, tmp[40];
	STRLEN lname;
	int r;
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	void *p1;
#else
	struct hostent *he;
#endif
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	sname = SvPVx( name, lname );
#ifndef SC_OLDNET
	memset( &aih, 0, sizeof( struct addrinfo ) );
	/*
	aih.ai_family = tv->s_domain;
	aih.ai_socktype = tv->s_type;
	aih.ai_protocol = tv->s_proto;
	*/
	r = getaddrinfo( sname, "", &aih, &ail );
	if( r != 0 ) {
#ifdef SC_DEBUG
		_debug( "getaddrinfo() failed %d\n", r );
#endif
		TV_ERRNO( tv, r );
		ST(0) = &PL_sv_undef;
		goto _exit;		
	}
	switch( ail->ai_family ) {
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) ail->ai_addr )->sin_addr.s_addr );
		r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
		ST(0) = sv_2mortal( newSVpvn( tmp, r ) );
		break;
	case AF_INET6:
		p1 = &((struct sockaddr_in6 *) ail->ai_addr )->sin6_addr;
		r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) p1 )
		);
		ST(0) = sv_2mortal( newSVpvn( tmp, r ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	freeaddrinfo( ail );
	TV_ERRNO( tv, 0 );
#else
	GLOBAL_LOCK();
	he = gethostbyname( sname );
	if( he == NULL ) {
#ifdef SC_DEBUG
		_debug( "gethostbyname() failed %d\n", Socket_errno() );
#endif
		TV_ERRNOLAST( tv );
		GLOBAL_UNLOCK();
		ST(0) = &PL_sv_undef;
		goto _exit;
	}
	switch( he->h_addrtype ) {
	case AF_INET:
		r = ntohl( (*(struct in_addr*) he->h_addr).s_addr );
		r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
		ST(0) = sv_2mortal( newSVpvn( tmp, r ) );
		break;
	case AF_INET6:
		r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) he->h_addr )
		);
		ST(0) = sv_2mortal( newSVpvn( tmp, r ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	GLOBAL_UNLOCK();
	TV_ERRNO( tv, 0 );
#endif
_exit:
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#ifndef SC_OLDNET

#/*****************************************************************************
# * getaddrinfo( this, node, service [, family [, proto [, type [, flags ]]]] )
# *****************************************************************************/

void
getaddrinfo( ... )
PREINIT:
	my_thread_var_t *tv = NULL;
	int ipos = 0, r;
	struct addrinfo aih;
	struct addrinfo *ail = NULL, *ai;
	const char *host, *service;
	HV *hv;
	int use_aih = 0;
	char tmp[40];
	my_sockaddr_t saddr;
PPCODE:
	if( items > 0 ) {
		if( (tv = my_thread_var_find( ST(0) )) != NULL ) {
			ipos ++;
		}
		else if(
			SvPOK( ST(0) ) &&
			strcmp( SvPV_nolen( ST(0) ), __PACKAGE__ ) == 0
		) {
			ipos ++;
		}
	}
	if( items - ipos < 1 )
		Perl_croak( aTHX_ "Usage: Socket::Class::getaddrinfo(node, ...)" );
	if( tv != NULL ) {
		TV_LOCK( tv );
	}
	else {
		GLOBAL_LOCK();
	}
	if( SvOK( ST(ipos) ) )
		host = SvPV_nolen( ST(ipos) );
	else
		host = NULL;
	ipos ++;
	if( ipos < items && SvOK( ST(ipos) ) )
		service = SvPV_nolen( ST(ipos) );
	else
		service = NULL;
	ipos ++;
	if( ipos < items ) {
		use_aih = 1;
		memset( &aih, 0, sizeof(struct addrinfo) );
		if( SvIOK( ST(ipos) ) )
			aih.ai_family = (int) SvIV( ST(ipos) );
		else
			aih.ai_family = Socket_domainbyname( SvPV_nolen( ST(ipos) ) );
#ifdef SC_DEBUG
		_debug( "using family %d\n", aih.ai_family );
#endif
		ipos ++;
	}
	if( ipos < items ) {
		if( SvIOK( ST(ipos) ) )
			aih.ai_protocol = (int) SvIV( ST(ipos) );
		else
			aih.ai_protocol = Socket_protobyname( SvPV_nolen( ST(ipos) ) );
#ifdef SC_DEBUG
		_debug( "using protocol %d\n", aih.ai_protocol );
#endif
		ipos ++;
	}
	if( ipos < items ) {
		if( SvIOK( ST(ipos) ) )
			aih.ai_socktype = (int) SvIV( ST(ipos) );
		else
			aih.ai_socktype = Socket_typebyname( SvPV_nolen( ST(ipos) ) );
#ifdef SC_DEBUG
		_debug( "using socktype %d\n", aih.ai_socktype );
#endif
		ipos ++;
	}
	if( ipos < items ) {
		aih.ai_flags = (int) SvIV( ST(ipos) );
		ipos ++;
	}
	r = getaddrinfo( host, service, use_aih ? &aih : NULL, &ail );
	if( r ) {
#ifdef SC_DEBUG
		_debug( "getaddrinfo failed %d\n", r );
#endif
		if( tv != NULL ) {
#ifndef _WIN32
			const char *s1 = gai_strerror( r );
			strncpy( tv->last_error, s1, sizeof(tv->last_error) );
#endif
			tv->last_errno = r;
			TV_UNLOCK( tv );
		}
		else {
#ifndef _WIN32
			GLOBAL_ERROR( r, gai_strerror( r ) );
#else
			GLOBAL_ERRNO( r );
#endif
			GLOBAL_UNLOCK();
		}
		XSRETURN_EMPTY;
	}
	for( ai = ail; ai != NULL; ai = ai->ai_next ) {
		hv = (HV *) sv_2mortal( (SV *) newHV() );
		hv_store( hv, "family", 6, newSViv( ai->ai_family ), 0 );
		hv_store( hv, "protocol", 8, newSViv( ai->ai_protocol ), 0 );
		hv_store( hv, "socktype", 8, newSViv( ai->ai_socktype ), 0 );
		saddr.l = (socklen_t) ai->ai_addrlen;
		memcpy( saddr.a, ai->ai_addr, ai->ai_addrlen );
		hv_store( hv, "paddr", 5, newSVpvn( (char *) &saddr, MYSASIZE(saddr) ), 0 );
		if( ai->ai_canonname != NULL )
			hv_store( hv, "canonname", 9, newSVpv( ai->ai_canonname, 0 ), 0 );
		/* familyname */
		switch( ai->ai_family ) {
		case AF_INET:
			hv_store( hv, "familyname", 10, newSVpvn( "INET", 4 ), 0 );
			r = ntohl( ((struct sockaddr_in *) ai->ai_addr )->sin_addr.s_addr );
			r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
			hv_store( hv, "addr", 4, newSVpvn( tmp, r ), 0 );
			hv_store( hv, "port", 4, newSViv(
				ntohs( ((struct sockaddr_in *) ai->ai_addr )->sin_port ) ), 0 );
			break;
		case AF_INET6:
			hv_store( hv, "familyname", 10, newSVpvn( "INET6", 5 ), 0 );
			r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
				IP6( (uint16_t *) &((struct sockaddr_in6 *) ai->ai_addr)->sin6_addr )
			);
			hv_store( hv, "addr", 4, newSVpv( tmp, r ), 0 );
			hv_store( hv, "port", 4, newSViv(
				ntohs( ((struct sockaddr_in6 *) ai->ai_addr)->sin6_port ) ), 0 );
			break;
		case AF_UNIX:
			hv_store( hv, "familyname", 10, newSVpvn( "UNIX", 4 ), 0 );
			hv_store( hv, "path", 4, newSVpv(
				((struct sockaddr_un *) ai->ai_addr)->sun_path, 0 ), 0 );
			break;
		case AF_BLUETOOTH:
			hv_store( hv, "familyname", 10, newSVpvn( "BTH", 3 ), 0 );
			if( ai->ai_protocol == BTPROTO_L2CAP ) {
				r = my_ba2str(
					&((SOCKADDR_L2CAP *) ai->ai_addr)->bt_bdaddr, tmp );
				hv_store( hv, "addr", 4, newSVpv( tmp, r ), 0 );
				hv_store( hv, "port", 4,
					newSViv( ((SOCKADDR_L2CAP *) ai->ai_addr)->bt_port ), 0 );
			}
			break;
		}
		/* sockname */
		switch( ai->ai_socktype ) {
		case SOCK_STREAM:
			hv_store( hv, "sockname", 8, newSVpvn( "STREAM", 6 ), 0 );
			break;
		case SOCK_DGRAM:
			hv_store( hv, "sockname", 8, newSVpvn( "DGRAM", 5 ), 0 );
			break;
		case SOCK_RAW:
			hv_store( hv, "sockname", 8, newSVpvn( "RAW", 3 ), 0 );
			break;
		case SOCK_RDM:
			hv_store( hv, "sockname", 8, newSVpvn( "RDM", 3 ), 0 );
			break;
		case SOCK_SEQPACKET:
			hv_store( hv, "sockname", 8, newSVpvn( "SEQPACKET", 9 ), 0 );
			break;
		}
		/* protoname */
		switch( ai->ai_family ) {
		case AF_INET:
		case AF_INET6:
			switch( ai->ai_protocol ) {
			case IPPROTO_TCP:
				hv_store( hv, "protoname", 9, newSVpvn( "TCP", 3 ), 0 );
				break;
			case IPPROTO_UDP:
				hv_store( hv, "protoname", 9, newSVpvn( "UDP", 3 ), 0 );
				break;
			case IPPROTO_ICMP:
				hv_store( hv, "protoname", 9, newSVpvn( "ICMP", 4 ), 0 );
				break;
			}
			break;
		case AF_BLUETOOTH:
			switch( ai->ai_protocol ) {
			case BTPROTO_RFCOMM:
				hv_store( hv, "protoname", 9, newSVpvn( "RFCOMM", 6 ), 0 );
				break;
			case BTPROTO_L2CAP:
				hv_store( hv, "protoname", 9, newSVpvn( "L2CAP", 5 ), 0 );
				break;
			}
			break;
		}
		XPUSHs( sv_2mortal( newRV( (SV *) hv ) ) );
	}
	freeaddrinfo( ail );
	if( tv != NULL ) {
		TV_ERRNO( tv, 0 );
		TV_UNLOCK( tv );
	}
	else {
		global.last_errno = 0;
		global.last_error[0] = '\0';
		GLOBAL_UNLOCK();
	}


#/*****************************************************************************
# * getnameinfo( this, addr, port, family, flags )
# *****************************************************************************/

void
getnameinfo( ... )
PREINIT:
	my_thread_var_t *tv = NULL;
	int ipos = 0, r;
	STRLEN len;
	char host[NI_MAXHOST];
	char serv[NI_MAXSERV];
	int family = AF_UNSPEC;
	char *addr;
	char *port = NULL;
	int flags = 0;
	my_sockaddr_t saddr, *psaddr;
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
PPCODE:
	if( items > 0 ) {
		if( (tv = my_thread_var_find( ST(0) )) != NULL ) {
			ipos ++;
		}
		else if(
			SvPOK( ST(0) ) &&
			strcmp( SvPV_nolen( ST(0) ), __PACKAGE__ ) == 0
		) {
			ipos ++;
		}
	}
	if( items - ipos < 1 )
		Perl_croak( aTHX_ "Usage: Socket::Class::getnameinfo(addr, ...)" );
	if( tv != NULL ) {
		TV_LOCK( tv );
	}
	else {
		GLOBAL_LOCK();
	}
	psaddr = (my_sockaddr_t *) SvPVbyte( ST(ipos), len );
	if( len > sizeof( int ) && len == MYSASIZE(*psaddr) ) {
		/* packed address */
		ipos ++;
		if( ipos < items ) {
			flags = (int) SvIV( ST(ipos) );
			ipos ++;
		}
	}
	else {
		addr = SvPV_nolen( ST(ipos) );
		ipos ++;
		if( ipos < items ) {
			port = SvPV_nolen( ST(ipos) );
			ipos ++;
		}
		if( ipos < items ) {
			if( SvIOK( ST(ipos) ) )
				family = (int) SvIV( ST(ipos) );
			else
				family = Socket_domainbyname( SvPV_nolen( ST(ipos) ) );
			ipos ++;
		}
		if( ipos < items ) {
			flags = (int) SvIV( ST(ipos) );
			ipos ++;
		}
		memset( &aih, 0, sizeof( struct addrinfo ) );
		aih.ai_family = family;
		/*aih.ai_flags = AI_NUMERICHOST;*/
		r = getaddrinfo( addr, port, &aih, &ail );
		if( r != 0 ) {
#ifdef SC_DEBUG
			_debug( "getaddrinfo failed %d\n", r );
#endif
			if( tv != NULL ) {
#ifndef _WIN32
				const char *s1 = gai_strerror( r );
				strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
#endif
				tv->last_errno = r;
				TV_UNLOCK( tv );
			}
			else {
#ifndef _WIN32
				GLOBAL_ERROR( r, gai_strerror( r ) );
#else
				GLOBAL_ERRNO( r );
#endif
				GLOBAL_UNLOCK();
			}
			XSRETURN_EMPTY;
		}
		saddr.l = (socklen_t) ail->ai_addrlen;
		memcpy( saddr.a, ail->ai_addr, ail->ai_addrlen );
		freeaddrinfo( ail );
		psaddr = &saddr;
	}
	r = getnameinfo(
		(struct sockaddr *) psaddr->a, psaddr->l,
		host, sizeof( host ),
		serv, sizeof( serv ),
		flags
	);
	if( r != 0 ) {
#ifdef SC_DEBUG
		_debug( "getnameinfo failed %d\n", r );
#endif
		if( tv != NULL ) {
#ifndef _WIN32
			const char *s1 = gai_strerror( r );
			strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
#endif
			tv->last_errno = r;
			TV_UNLOCK( tv );
		}
		else {
#ifndef _WIN32
			GLOBAL_ERROR( r, gai_strerror( r ) );
#else
			GLOBAL_ERRNO( r );
#endif
			GLOBAL_UNLOCK();
		}
		XSRETURN_EMPTY;
	}
	if( tv != NULL ) {
		TV_ERRNO( tv, 0 );
		TV_UNLOCK( tv );
	}
	else {
		global.last_errno = 0;
		global.last_error[0] = '\0';
		GLOBAL_UNLOCK();
	}
	ST(0) = sv_2mortal( newSVpvn( host, strlen( host ) ) );
	if( GIMME_V != G_ARRAY )
		XSRETURN(1);
	ST(1) = sv_2mortal( newSVpvn( serv, strlen( serv ) ) );
	XSRETURN(2);


#else

void
getaddrinfo( ... )
PPCODE:
	Perl_croak( aTHX_ "getaddrinfo is not supported by your system" );

void
getnameinfo( ... )
PPCODE:
	Perl_croak( aTHX_ "getnameinfo is not supported by your system" );

#endif

#/*****************************************************************************
# * set_blocking( this [, bool] )
# *****************************************************************************/

void
set_blocking( this, value = 1 )
	SV *this;
	int value;
PREINIT:
	my_thread_var_t *tv;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	r = Socket_setblocking( tv->sock, value );
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		TV_UNLOCK( tv );
		XSRETURN_EMPTY;
	}
	TV_ERRNO( tv, 0 );
	tv->non_blocking = (BYTE) ! value;
	TV_UNLOCK( tv );
	XSRETURN_YES;


#/*****************************************************************************
# * get_blocking( this )
# *****************************************************************************/

void
get_blocking( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( tv->non_blocking )
		ST(0) = &PL_sv_no;
	else
		ST(0) = &PL_sv_yes;
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * set_reuseaddr( this [, bool] )
# *****************************************************************************/

void
set_reuseaddr( this, value = 1 )
	SV *this;
	int value;
PREINIT:
	int r;
PPCODE:
	r = Socket_setopt(
		this, SOL_SOCKET, SO_REUSEADDR, (void *) &value, sizeof( int )
	);
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_reuseaddr( this )
# *****************************************************************************/

void
get_reuseaddr( this )
	SV *this;
PREINIT:
	int r;
	socklen_t l = sizeof( int );
	char val[sizeof( int )];
PPCODE:
	r = Socket_getopt( this, SOL_SOCKET, SO_REUSEADDR, val, &l );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( *((int *) val) );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * set_broadcast( this [, bool] )
# *****************************************************************************/

void
set_broadcast( this, value = 1 )
	SV *this;
	int value;
PREINIT:
	int r;
PPCODE:
	r = Socket_setopt(
		this, SOL_SOCKET, SO_BROADCAST, (void *) &value, sizeof( int )
	);
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_broadcast( this )
# *****************************************************************************/

void
get_broadcast( this )
	SV *this;
PREINIT:
	int r;
	socklen_t l = sizeof( int );
	char val[sizeof( int )];
PPCODE:
	r = Socket_getopt( this, SOL_SOCKET, SO_BROADCAST, val, &l );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( *((int *) val) );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * set_rcvbuf_size( this, size )
# *****************************************************************************/

void
set_rcvbuf_size( this, size )
	SV *this;
	int size;
PREINIT:
	int r;
PPCODE:
	r = Socket_setopt(
		this, SOL_SOCKET, SO_RCVBUF, (void *) &size, sizeof( int )
	);
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_rcvbuf_size( this )
# *****************************************************************************/

void
get_rcvbuf_size( this )
	SV *this;
PREINIT:
	int r;
	socklen_t l = sizeof( int );
	char val[sizeof( int )];
PPCODE:
	r = Socket_getopt( this, SOL_SOCKET, SO_RCVBUF, val, &l );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( *((int *) val) );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * set_sndbuf_size( this, size )
# *****************************************************************************/

void
set_sndbuf_size( this, size )
	SV *this;
	int size;
PREINIT:
	int r;
PPCODE:
	r = Socket_setopt(
		this, SOL_SOCKET, SO_SNDBUF, (void *) &size, sizeof( int )
	);
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_sndbuf_size( this )
# *****************************************************************************/

void
get_sndbuf_size( this )
	SV *this;
PREINIT:
	int r;
	socklen_t l = sizeof( int );
	char val[sizeof( int )];
PPCODE:
	r = Socket_getopt( this, SOL_SOCKET, SO_SNDBUF, val, &l );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( *((int *) val) );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * set_tcp_nodelay( this [, value] )
# *****************************************************************************/

void
set_tcp_nodelay( this, value = 1 )
	SV *this;
	int value;
PREINIT:
	int r;
PPCODE:
	r = Socket_setopt(
		this, IPPROTO_TCP, TCP_NODELAY, (void *) &value, sizeof( int )
	);
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_tcp_nodelay( this )
# *****************************************************************************/

void
get_tcp_nodelay( this )
	SV *this;
PREINIT:
	int r;
	socklen_t l = sizeof( int );
	char val[sizeof( int )];
PPCODE:
	r = Socket_getopt( this, IPPROTO_TCP, TCP_NODELAY, val, &l );
	if( r != SOCKET_ERROR )
		XSRETURN_IV( *((int *) val) );
	XSRETURN_EMPTY;


#/*****************************************************************************
# * set_option( this, level, optname, value, ... )
# *****************************************************************************/

void
set_option( this, level, optname, value, ... )
	SV *this;
	int level;
	int optname;
	SV *value;
PREINIT:
	int r;
	STRLEN len;
	const void *val;
	char tmp[20];
PPCODE:
	if( SvIOK( value ) && level == SOL_SOCKET ) {
		switch( optname ) {
		case SO_LINGER:
			if( items > 4 ) {
				((struct linger *) tmp)->l_onoff = (uint16_t) SvUV( value );
				((struct linger *) tmp)->l_linger = (uint16_t) SvUV( ST(4) );
			}
			else {
				((struct linger *) tmp)->l_onoff = (uint16_t) SvUV( value );
				((struct linger *) tmp)->l_linger = 1;
			}
			val = tmp;
			len = sizeof( struct linger );
			break;
		case SO_RCVTIMEO:
		case SO_SNDTIMEO:
#ifdef _WIN32
			if( items > 4 ) {
				*((DWORD *) tmp) = (DWORD) SvUV( value ) * 1000;
				*((DWORD *) tmp) += (DWORD) (SvUV( ST(4) ) / 1000);
			}
			else {
				*((DWORD *) tmp) = (DWORD) SvUV( value );
			}
			val = tmp;
			len = sizeof( DWORD );
#else
			if( items > 4 ) {
				((struct timeval *) tmp)->tv_sec = (long) SvIV( value );
				((struct timeval *) tmp)->tv_usec = (long) SvIV( ST(4) );
			}
			else {
				r = SvIV( value );
				((struct timeval *) tmp)->tv_sec = (long) (r / 1000);
				((struct timeval *) tmp)->tv_usec = (long) (r * 1000) % 1000000;
			}
			val = tmp;
			len = sizeof( struct timeval );
#endif
			break;
		default:
			goto _chk;
		}
		goto _set;
	}
_chk:
	if( SvIOK( value ) ) {
		r = (int) SvIV( value );
		val = &r;
		len = sizeof( int );
	}
	else {
		val = SvPVbyte( value, len );
	}
_set:
	r = Socket_setopt( this, level, optname, val, (socklen_t) len );
	if( r != SOCKET_ERROR )
		XSRETURN_YES;
	XSRETURN_EMPTY;


#/*****************************************************************************
# * get_option( this, level, optname )
# *****************************************************************************/

void
get_option( this, level, optname )
	SV *this;
	int level;
	int optname;
PREINIT:
	my_thread_var_t *tv;
	char tmp[20];
	int r;
	socklen_t l = sizeof( tmp );
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	l = sizeof( tmp );
	r = getsockopt( tv->sock, level, optname, tmp, &l );
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		goto _set;
	}
	TV_ERRNO( tv, 0 );
	if( level == SOL_SOCKET ) {
		switch( optname ) {
		case SO_LINGER:
			XPUSHs( sv_2mortal(
				newSVuv( ((struct linger *) tmp)->l_onoff ) ) );
			XPUSHs( sv_2mortal(
				newSVuv( ((struct linger *) tmp)->l_linger ) ) );
			break;
		case SO_RCVTIMEO:
		case SO_SNDTIMEO:
#ifdef _WIN32
#ifdef SC_DEBUG
			_debug( "optlen %d\n", l );
#endif
			if( GIMME_V == G_ARRAY ) {
				XPUSHs( sv_2mortal(
					newSVuv( *((DWORD *) tmp) / 1000 ) ) );
				XPUSHs( sv_2mortal(
					newSVuv( (*((DWORD *) tmp) * 1000) % 1000000 ) ) );
			}
			else {
				XPUSHs( sv_2mortal( newSVuv( *((DWORD *) tmp) ) ) );
			}
#else
			if( GIMME_V == G_ARRAY ) {
				XPUSHs( sv_2mortal(
					newSViv( ((struct timeval *) tmp)->tv_sec ) ) );
				XPUSHs( sv_2mortal(
					newSViv( ((struct timeval *) tmp)->tv_usec ) ) );
			}
			else {
				XPUSHs( sv_2mortal( newSVuv(
					((struct timeval *) tmp)->tv_sec * 1000 +
					((struct timeval *) tmp)->tv_usec / 1000
				) ) );
			}
#endif
			break;
		default:
			goto _chk;
		}
		goto _set;
	}
_chk:
#ifdef _WIN32
	if( l == sizeof( DWORD ) ) {
		/* just a try */
		XPUSHs( sv_2mortal( newSVuv( *((DWORD *) tmp) ) ) );
#else
	if( l == sizeof( int ) ) {
		/* just a try */
		XPUSHs( sv_2mortal( newSViv( *((int *) tmp) ) ) );
#endif
	}
	else {
		XPUSHs( sv_2mortal( newSVpvn( tmp, l ) ) );
	}
_set:
	TV_UNLOCK( tv );


#/*****************************************************************************
# * set_timeout( this, ms )
# *****************************************************************************/

void
set_timeout( this, ms )
	SV *this;
	double ms;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	tv->timeout.tv_sec = (long) (ms / 1000);
	tv->timeout.tv_usec = (long) (ms * 1000) % 1000000;
	TV_UNLOCK( tv );
	XSRETURN_YES;


#/*****************************************************************************
# * get_timeout( this )
# *****************************************************************************/

void
get_timeout( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	XSRETURN_NV( tv->timeout.tv_sec * 1000 + tv->timeout.tv_usec / 1000 );


#/*****************************************************************************
# * is_readable( this [, timeout] )
# *****************************************************************************/

void
is_readable( this, timeout = NULL )
	SV *this;
	SV *timeout;
PREINIT:
	my_thread_var_t *tv;
	fd_set fd_socks;
	struct timeval t;
	int ret;
	double ms;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	FD_ZERO( &fd_socks );
	FD_SET( tv->sock, &fd_socks );
	if( timeout != NULL ) {
		ms = SvNV( timeout );
		t.tv_sec = (long) (ms / 1000);
		t.tv_usec = (long) (ms * 1000) % 1000000;
		ret = select(
			(int) (tv->sock + 1), &fd_socks, NULL, NULL, &t
		);
	}
	else {
		ret = select(
			(int) (tv->sock + 1), &fd_socks, NULL, NULL, NULL
		);
	}
	if( ret < 0 ) {
		TV_ERRNOLAST( tv );
#ifdef SC_DEBUG
		_debug( "is_readable error %u\n", tv->last_errno );
#endif
		tv->state = SOCK_STATE_ERROR;
		ST(0) = &PL_sv_undef;
	}
	else {
		TV_ERRNO( tv, 0 );
		ST(0) = ret ? &PL_sv_yes : &PL_sv_no;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * is_writable( this [, timeout] )
# *****************************************************************************/

void
is_writable( this, timeout = NULL )
	SV *this;
	SV *timeout;
PREINIT:
	my_thread_var_t *tv;
	fd_set fd_socks;
	struct timeval t;
	int ret;
	double ms;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	FD_ZERO( &fd_socks );
	FD_SET( tv->sock, &fd_socks );
	if( timeout != NULL ) {
		ms = SvNV( timeout );
		t.tv_sec = (long) (ms / 1000);
		t.tv_usec = (long) (ms * 1000) % 1000000;
		ret = select(
			(int) ( tv->sock + 1 ), NULL, &fd_socks, NULL, &t
		);
	}
	else {
		ret = select(
			(int) ( tv->sock + 1 ), NULL, &fd_socks, NULL, NULL
		);
	}
	if( ret < 0 ) {
		TV_ERRNOLAST( tv );
#ifdef SC_DEBUG
		_debug( "is_writable error %u\n", tv->last_errno );
#endif
		tv->state = SOCK_STATE_ERROR;
		ST(0) = &PL_sv_undef;
	}
	else {
		TV_ERRNO( tv, 0 );
		ST(0) = ret ? &PL_sv_yes : &PL_sv_no;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * select( this [, read [, write [, error [, timeout]]]] )
# *****************************************************************************/

void
select( this, read = NULL, write = NULL, except = NULL, timeout = NULL )
	SV *this;
	SV *read;
	SV *write;
	SV *except;
	SV *timeout;
PREINIT:
	my_thread_var_t *tv;
	fd_set fdr, fdw, fde;
	struct timeval t, *pt;
	int ret, dr, dw, de;
	double ms;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	if( read == NULL )
		dr = 0;
	else if( (dr = SvTRUE( read )) ) {
		FD_ZERO( &fdr );
		FD_SET( tv->sock, &fdr );
	}
	if( write == NULL )
		dw = 0;
	else if( (dw = SvTRUE( write )) ) {
		FD_ZERO( &fdw );
		FD_SET( tv->sock, &fdw );
	}
	if( except == NULL )
		de = 0;
	else if( (de = SvTRUE( except )) ) {
		FD_ZERO( &fde );
		FD_SET( tv->sock, &fde );
	}
	if( timeout == NULL )
		pt = NULL;
	else {
		ms = SvNV( timeout );
		t.tv_sec = (long) (ms / 1000);
		t.tv_usec = (long) (ms * 1000) % 1000000;
		pt = &t;
	}
	ret = select(
		(int) (tv->sock + 1), (dr ? &fdr : NULL), (dw ? &fdw : NULL),
		(de ? &fde : NULL), pt
	);
	if( ret < 0 ) {
		TV_ERRNOLAST( tv );
#ifdef SC_DEBUG
		_debug( "select error %u\n", tv->last_errno );
#endif
		tv->state = SOCK_STATE_ERROR;
		ST(0) = &PL_sv_undef;
	}
	else {
		TV_ERRNO( tv, 0 );
		ST(0) = sv_2mortal( newSViv( ret ) );
		if( dr && ! SvREADONLY( read ) )
			sv_setiv( read, FD_ISSET( tv->sock, &fdr ) ? 1 : 0 );
		if( dw && ! SvREADONLY( write ) )
			sv_setiv( write, FD_ISSET( tv->sock, &fdw ) ? 1 : 0 );
		if( de && ! SvREADONLY( except ) )
			sv_setiv( except, FD_ISSET( tv->sock, &fde ) ? 1 : 0 );
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * wait( this, timeout )
# *****************************************************************************/

void
wait( this, timeout )
	SV *this;
	unsigned long timeout;
PREINIT:
#ifndef _WIN32
	struct timeval t;
#endif
PPCODE:
	if( this != NULL ) {} /* avoid compiler warning */
#ifdef _WIN32
	Sleep( timeout );
#else
	t.tv_sec = (long) (timeout / 1000);
	t.tv_usec = (long) (timeout * 1000) % 1000000;
	select( 0, NULL, NULL, NULL, &t );
#endif


#/*****************************************************************************
# * handle( this )
# *****************************************************************************/

void
handle( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	ST(0) = sv_2mortal( newSViv( tv->sock ) );
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * state( this )
# *****************************************************************************/

void
state( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	ST(0) = sv_2mortal( newSViv( tv->state ) );
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * local_addr( this )
# *****************************************************************************/

void
local_addr( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	char tmp[40];
	int r;
	void *p1;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) tv->l_addr.a )->sin_addr.s_addr );
		r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	case AF_INET6:
		p1 = &((struct sockaddr_in6 *) tv->l_addr.a )->sin6_addr;
		r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) p1 )
		);
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	case AF_BLUETOOTH:
		r = my_ba2str(
			(bdaddr_t *) &tv->l_addr.a[sizeof(sa_family_t)], tmp );
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * local_path( this )
# *****************************************************************************/

void
local_path( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	char *s1;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_UNIX:
		s1 = ((struct sockaddr_un *) tv->l_addr.a )->sun_path;
		ST(0) = sv_2mortal( newSVpv( s1, strlen( s1 ) ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * local_port( this )
# *****************************************************************************/

void
local_port( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_INET:
		ST(0) = sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in *) tv->l_addr.a )->sin_port ) ) );
		break;
	case AF_INET6:
		ST(0) = sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in6 *) tv->l_addr.a )->sin6_port ) ) );
		break;
	case AF_BLUETOOTH:
		switch( tv->s_proto ) {
		case BTPROTO_RFCOMM:
			ST(0) = sv_2mortal(
				newSViv( ((SOCKADDR_RFCOMM *) tv->l_addr.a)->bt_port ) );
			break;
		case BTPROTO_L2CAP:
			ST(0) = sv_2mortal(
				newSViv( ((SOCKADDR_L2CAP *) tv->l_addr.a)->bt_port ) );
			break;
		default:
			ST(0) = &PL_sv_undef;
		}
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * remote_addr( this )
# *****************************************************************************/

void
remote_addr( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	char tmp[40];
	void *p1;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_INET:
		r = ntohl( ((struct sockaddr_in *) tv->r_addr.a )->sin_addr.s_addr );
		r = sprintf( tmp, "%u.%u.%u.%u", IP4( r ) );
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	case AF_INET6:
		p1 = &((struct sockaddr_in6 *) tv->r_addr.a )->sin6_addr;
		r = sprintf( tmp, "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x",
			IP6( (uint16_t *) p1 )
		);
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	case AF_BLUETOOTH:
		r = my_ba2str(
			(bdaddr_t *) &tv->r_addr.a[sizeof(sa_family_t)], tmp );
		ST(0) = sv_2mortal( newSVpv( tmp, r ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * remote_path( this )
# *****************************************************************************/

void
remote_path( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	char *s1;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_UNIX:
		s1 = ((struct sockaddr_un *) tv->r_addr.a )->sun_path;
		ST(0) = sv_2mortal( newSVpv( s1, strlen( s1 ) ) );
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * remote_port( this )
# *****************************************************************************/

void
remote_port( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	switch( tv->s_domain ) {
	case AF_INET:
		ST(0) = sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in *) tv->r_addr.a )->sin_port ) ) );
		break;
	case AF_INET6:
		ST(0) = sv_2mortal( newSViv(
			ntohs( ((struct sockaddr_in6 *) tv->r_addr.a )->sin6_port ) ) );
		break;
	case AF_BLUETOOTH:
		switch( tv->s_proto ) {
		case BTPROTO_RFCOMM:
			ST(0) = sv_2mortal(
				newSViv( ((SOCKADDR_RFCOMM *) tv->r_addr.a)->bt_port ) );
			break;
		case BTPROTO_L2CAP:
			ST(0) = sv_2mortal(
				newSViv( ((SOCKADDR_L2CAP *) tv->r_addr.a)->bt_port ) );
			break;
		default:
			ST(0) = &PL_sv_undef;
		}
		break;
	default:
		ST(0) = &PL_sv_undef;
	}
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * to_string( this )
# *****************************************************************************/

void
to_string( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
	char tmp[1024], *s1;
	void *p1;
	int r;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	s1 = my_strcpy( tmp, "SOCKET(ID=" );
	if( tv->sock != INVALID_SOCKET )
		s1 = my_itoa( s1, (long) tv->sock, 10 );
	else
		s1 = my_strcpy( s1, "NONE" );
	s1 = my_strcpy( s1, ";DOMAIN=" );
	switch( tv->s_domain ) {
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
		s1 = my_itoa( s1, tv->s_domain, 10 );
		break;
	}
	s1 = my_strcpy( s1, ";TYPE=" );
	switch( tv->s_type ) {
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
		s1 = my_itoa( s1, tv->s_type, 10 );
		break;
	}
	s1 = my_strcpy( s1, ";PROTO=" );
	switch( tv->s_domain ) {
	case AF_INET:
	case AF_INET6:
		switch( tv->s_proto ) {
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
		switch( tv->s_proto ) {
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
		s1 = my_itoa( s1, tv->s_proto, 10 );
		break;
	}
	if( tv->l_addr.l ) {
		switch( tv->s_domain ) {
		case AF_INET:
			r = ntohl( ((struct sockaddr_in *) tv->l_addr.a )->sin_addr.s_addr );
			r = sprintf(
				s1,
				";LOCAL=%u.%u.%u.%u:%u",
				IPPORT4( r, ((struct sockaddr_in *) tv->l_addr.a )->sin_port )
			);
			s1 += (size_t ) r;
			break;
		case AF_INET6:
			p1 = &((struct sockaddr_in6 *) tv->l_addr.a )->sin6_addr;
			r = sprintf(
				s1,
				";LOCAL=[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:%u",
				IPPORT6(
					(uint16_t *) p1,
					((struct sockaddr_in6 *) tv->l_addr.a )->sin6_port
				)
			);
			s1 += (size_t ) r;
			break;
		case AF_UNIX:
			s1 = my_strcpy( s1, ";LOCAL=" );
			s1 = my_strcpy( s1,
				((struct sockaddr_un *) tv->l_addr.a )->sun_path );
			break;
		case AF_BLUETOOTH:
			s1 = my_strcpy( s1, ";LOCAL=" );
			s1 += my_ba2str(
				(bdaddr_t *) &tv->l_addr.a[sizeof(sa_family_t)], s1 );
			break;
		}
	}
	if( tv->r_addr.l ) {
		switch( tv->s_domain ) {
		case AF_INET:
			r = ntohl( ((struct sockaddr_in *) tv->r_addr.a )->sin_addr.s_addr );
			r = sprintf(
				s1,
				";REMOTE=%u.%u.%u.%u:%u",
				IPPORT4( r, ((struct sockaddr_in *) tv->r_addr.a )->sin_port )
			);
			s1 += (size_t ) r;
			break;
		case AF_INET6:
			p1 = &((struct sockaddr_in6 *) tv->r_addr.a )->sin6_addr;
			r = sprintf(
				s1,
				";REMOTE=[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:%u",
				IPPORT6(
					(uint16_t *) p1,
					((struct sockaddr_in6 *) tv->r_addr.a )->sin6_port
				)
			);
			s1 += (size_t ) r;
			break;
		case AF_UNIX:
			s1 = my_strcpy( s1, ";REMOTE=" );
			s1 = my_strcpy( s1,
				((struct sockaddr_un *) tv->r_addr.a )->sun_path );
			break;
		case AF_BLUETOOTH:
			s1 = my_strcpy( s1, ";REMOTE=" );
			s1 += my_ba2str(
				(bdaddr_t *) &tv->r_addr.a[sizeof(sa_family_t)], s1 );
			break;
		}
	}
	*s1 ++ = ')';
	TV_UNLOCK( tv );
	ST(0) = sv_2mortal( newSVpv( tmp, (size_t) (s1 - tmp) ) );
	XSRETURN( 1 );


#/*****************************************************************************
# * is_error( this )
# *****************************************************************************/

void
is_error( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) == NULL )
		XSRETURN_EMPTY;
	TV_LOCK( tv );
	ST(0) = (tv->state == SOCK_STATE_ERROR) ? &PL_sv_yes : &PL_sv_no;
	TV_UNLOCK( tv );
	XSRETURN( 1 );


#/*****************************************************************************
# * errno( this )
# *****************************************************************************/

void
errno( this )
	SV *this;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) != NULL ) {
		TV_LOCK( tv );
		ST(0) = sv_2mortal( newSViv( tv->last_errno ) );
		TV_UNLOCK( tv );
		XSRETURN( 1 );
	}
	GLOBAL_LOCK();
	ST(0) = sv_2mortal( newSViv( global.last_errno ) );
	GLOBAL_UNLOCK();
	XSRETURN( 1 );


#/*****************************************************************************
# * error( this [, code] )
# *****************************************************************************/

void
error( this, code = 0 )
	SV *this;
	int code;
PREINIT:
	my_thread_var_t *tv;
PPCODE:
	if( (tv = my_thread_var_find( this )) != NULL ) {
		TV_LOCK( tv );
		if( ! code )
			code = tv->last_errno;
		if( code > 0 )
			Socket_error(
				tv->last_error, sizeof( tv->last_error ), code
			);
		ST(0) = sv_2mortal( newSVpv( tv->last_error, 0 ) );
		TV_UNLOCK( tv );
		XSRETURN( 1 );
	}
	GLOBAL_LOCK();
	if( ! code )
		code = global.last_errno;
	if( code > 0 )
		Socket_error(
			global.last_error, sizeof( global.last_error ), code
		);
	ST(0) = sv_2mortal( newSVpv( global.last_error, 0 ) );
	GLOBAL_UNLOCK();
	XSRETURN( 1 );
