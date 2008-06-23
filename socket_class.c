#include "socket_class.h"

my_global_t global;

INLINE void my_thread_var_add( my_thread_var_t *tv ) {
	size_t cascade;
#ifdef USE_ITHREADS
	MUTEX_INIT( &tv->thread_lock );
#endif
	GLOBAL_LOCK();
	tv->id = ++ global.counter;
	cascade = (size_t) tv->id % SC_TV_CASCADE;
#ifdef SC_DEBUG
	_debug( "add tv %lu cascade %lu\n", tv->id, cascade );
#endif
	if( global.first_thread[cascade] == NULL )
		global.first_thread[cascade] = tv;
	else {
		global.last_thread[cascade]->next = tv;
		tv->prev = global.last_thread[cascade];
	}
	global.last_thread[cascade] = tv;
	GLOBAL_UNLOCK();
}

INLINE void my_thread_var_free( my_thread_var_t *tv ) {
	TV_LOCK( tv );
#ifdef SC_DEBUG
	_debug( "free tv %lu socket %d\n", tv->id, tv->sock );
#endif
	Socket_close( tv->sock );
	if( tv->s_domain == AF_UNIX ) {
		remove( ((struct sockaddr_un *) tv->l_addr.a)->sun_path );
	}
	Safefree( tv->rcvbuf );
	Safefree( tv->classname );
	TV_UNLOCK( tv );
#ifdef USE_ITHREADS
	MUTEX_DESTROY( &tv->thread_lock );
#endif
	Safefree( tv );
}

INLINE void my_thread_var_rem( my_thread_var_t *tv ) {
	size_t cascade = (size_t) tv->id % SC_TV_CASCADE;
	GLOBAL_LOCK();
#ifdef SC_DEBUG
	_debug( "removing thread_var %lu\n", tv->id );
#endif
	if( tv == global.last_thread[cascade] )
		global.last_thread[cascade] = tv->prev;
	if( tv == global.first_thread[cascade] )
		global.first_thread[cascade] = tv->next;
	if( tv->prev )
		tv->prev->next = tv->next;
	if( tv->next )
		tv->next->prev = tv->prev;
	my_thread_var_free( tv );
	GLOBAL_UNLOCK();
}

INLINE my_thread_var_t *my_thread_var_find( SV *sv ) {
	size_t cascade;
	my_thread_var_t *tvf, *tvl;
	unsigned long id;
	if( global.destroyed )
		return NULL;
	if( ! SvROK( sv ) || ! (sv = SvRV( sv )) || ! SvIOK( sv ) )
		return NULL;
	id = (unsigned long) SvIV( sv );
	cascade = (size_t) id % SC_TV_CASCADE;
	GLOBAL_LOCK();
	tvf = global.first_thread[cascade];
	tvl = global.last_thread[cascade];
	while( 1 ) {
		if( tvl == NULL )
			break;
		if( tvl->id == id )
			goto retl;
		if( tvf->id == id )
			goto retf;
		tvl = tvl->prev;
		tvf = tvf->next;
	}
#ifdef SC_DEBUG
	_debug( "tv %lu NOT found\n", id );
#endif
retf:
	GLOBAL_UNLOCK();
	return tvf;
retl:
	GLOBAL_UNLOCK();
	return tvl;
}

#ifdef _WIN32

#define ISEOL(c) ((c) == '\r' || (c) == '\n') 

INLINE void Socket_error( char *str, DWORD len, long num ) {
	char *s1;
	DWORD ret;
#ifdef SC_DEBUG
	int r1;
	r1 = snprintf( str, len, "(%d) ", num );
	len -= r1;
	s1 = &str[r1];
#else
	s1 = str;
#endif
	ret = FormatMessage(
		FORMAT_MESSAGE_FROM_SYSTEM, 
		NULL,
		num,
		LANG_USER_DEFAULT, 
		s1,
		len,
		NULL
	);
	for( ; ret > 0, ISEOL( s1[ret - 1] ); ret -- )
		s1[ret - 1] = '\0';
}

INLINE int inet_aton( const char *cp, struct in_addr *inp ) {
	inp->s_addr = inet_addr( cp );
	return inp->s_addr == INADDR_NONE ? 0 : 1;
}

#else

INLINE void Socket_error( char *str, DWORD len, long num ) {
	char *s1, *s2;
#ifdef SC_DEBUG
	int ret;
	ret = snprintf( str, len, "(%ld) ", num );
	len -= ret;
	s1 = &str[ret];
#else
	s1 = str;
#endif
	s2 = strerror( num );
	if( s2 != NULL )
		my_strncpy( s1, s2, len );
}

#endif

INLINE void Socket_setaddr_UNIX( my_sockaddr_t *addr, const char *path ) {
	struct sockaddr_un *a = (struct sockaddr_un *) addr->a;
	addr->l = sizeof( struct sockaddr_un );
	a->sun_family = AF_UNIX;
	if( path != NULL )
		my_strncpy( a->sun_path, path, 100 );
}

INLINE int Socket_setaddr_INET( tv, host, port, use )
	my_thread_var_t *tv;
	const char *host;
	const char *port;
	int use;
{
#ifndef SC_OLDNET
	struct addrinfo aih;
	struct addrinfo *ail = NULL;
	my_sockaddr_t *addr;
	int r;
	if( tv->s_domain == AF_BLUETOOTH )
		return Socket_setaddr_BTH( tv, host, port, use );
	memset( &aih, 0, sizeof( struct addrinfo ) );
	aih.ai_family = tv->s_domain;
	aih.ai_socktype = tv->s_type;
	aih.ai_protocol = tv->s_proto;
	if( use == ADDRUSE_LISTEN ) {
		aih.ai_flags = AI_PASSIVE;
		addr = &tv->l_addr;
	}
	else {
		addr = &tv->r_addr;
	}
	r = getaddrinfo( host, port != NULL ? port : "", &aih, &ail );
	if( r != 0 ) {
#ifdef SC_DEBUG
		_debug( "Socket_setaddr_INET getaddrinfo() failed %d\n", r );
#endif
#ifndef _WIN32
		{
			const char *s1 = gai_strerror( r );
			strncpy( tv->last_error, s1, sizeof( tv->last_error ) );
		}
#endif
		return r;
	}
	addr->l = (socklen_t) ail->ai_addrlen;
	memcpy( addr->a, ail->ai_addr, ail->ai_addrlen );
	freeaddrinfo( ail );
#else
	my_sockaddr_t *addr;
	if( tv->s_domain == AF_BLUETOOTH )
		return Socket_setaddr_BTH( tv, host, port, use );
	GLOBAL_LOCK();
	addr = (use == ADDRUSE_LISTEN) ? &tv->l_addr : &tv->r_addr;
	if( tv->s_domain == AF_INET ) {
		struct sockaddr_in *in = (struct sockaddr_in *) addr->a;
		addr->l = sizeof(struct sockaddr_in);
		in->sin_family = AF_INET;
		if( host == NULL && use != ADDRUSE_LISTEN )
			host = "127.0.0.0";
		if( host != NULL ) {
			if( host[0] >= '0' && host[0] <= '9' )
				in->sin_addr.s_addr = inet_addr( host );
			else {
				struct hostent *he;
				if( (he = gethostbyname( host )) == NULL )
					goto error;
				in->sin_addr = *(struct in_addr*) he->h_addr;
			}
		}
		if( port != NULL ) {
			if( port[0] >= '0' && port[0] <= '9' )
				in->sin_port = htons( atoi( port ) );
			else {
				struct servent *se;
				if( (se = getservbyname( port, NULL )) == NULL )
					goto error;
				in->sin_port = se->s_port;
			}
		}
	}
	else {
		struct sockaddr_in6 *in6;
		addr->l = sizeof(struct sockaddr_in6);
		in6 = (struct sockaddr_in6 *) addr->a;
		in6->sin6_family = AF_INET6;
#ifndef _WIN32
		if( host != NULL ) {
			if( ( host[0] >= '0' && host[0] <= '9' ) || host[0] == ':' ) {
				if( inet_pton( AF_INET6, host, &in6->sin6_addr ) != 0 ) {
#ifdef SC_DEBUG
					_debug( "inet_pton failed %d\n", Socket_errno() );
#endif
					goto error;
				}
			}
			else {
				struct hostent *he;
				if( (he = gethostbyname( host )) == NULL )
					goto error;
				if( he->h_addrtype != AF_INET6 )
					goto error;
				Copy( he->h_addr, &in6->sin6_addr, he->h_length, char );
			}
		}
		if( port != NULL ) {
			if( port[0] >= '0' && port[0] <= '9' )
				in6->sin6_port = htons( atol( port ) );
			else {
				struct servent *se;
				se = getservbyname( port, NULL );
				if( se == NULL )
					goto error;
				in6->sin6_port = se->s_port;
			}
		}
#endif
	}
	goto exit;
error:
	GLOBAL_UNLOCK();
	return Socket_errno();
exit:
	GLOBAL_UNLOCK();
#endif
	return 0;
}

INLINE int Socket_setaddr_BTH(
	my_thread_var_t *tv, const char *host, const char *port, int use
) {
	my_sockaddr_t *addr;
	SOCKADDR_RFCOMM *rca;
	SOCKADDR_L2CAP *l2a;

	if( use == ADDRUSE_LISTEN ) {
		addr = &tv->l_addr;
	}
	else {
		addr = &tv->r_addr;
	}
	switch( tv->s_proto ) {
	case BTPROTO_RFCOMM:
#ifdef SC_DEBUG
		_debug( "using BLUETOOTH RFCOMM host %s channel %s\n", host, port );
#endif
		addr->l = sizeof( SOCKADDR_RFCOMM );
		rca = (SOCKADDR_RFCOMM *) addr->a;
		rca->bt_family = AF_BLUETOOTH;
		if( host != NULL )
			my_str2ba( host, &rca->bt_bdaddr );
		if( port != NULL )
			rca->bt_port = (uint8_t) atol( port );
		if( ! rca->bt_port )
			rca->bt_port = 1;
		break;
	case BTPROTO_L2CAP:
#ifdef SC_DEBUG
		_debug( "using BLUETOOTH L2CAP host %s psm %s\n", host, port );
#endif
		addr->l = sizeof( SOCKADDR_L2CAP );
		l2a = (SOCKADDR_L2CAP *) addr->a;
		l2a->bt_family = AF_BLUETOOTH;
		if( host != NULL )
			my_str2ba( host, &l2a->bt_bdaddr );
		if( port != NULL )
			l2a->bt_port = (uint8_t) atol( port );
		break;
#ifdef SC_HAS_BLUETOOTH
	default:
		return bt_setaddr( tv, host, port, use );
#endif
	}
	return 0;
}

INLINE int Socket_domainbyname( const char *name ) {
	char tmp[20];
	my_strncpyu( tmp, name, sizeof( tmp ) );
	if( strcmp( tmp, "INET" ) == 0 ) {
		return AF_INET;
	}
	else if( strcmp( tmp, "INET6" ) == 0 ) {
		return AF_INET6;
	}
	else if( strcmp( tmp, "UNIX" ) == 0 ) {
		return AF_UNIX;
	}
	else if( strcmp( tmp, "BTH" ) == 0 ) {
		return AF_BLUETOOTH;
	}
	else if( strcmp( tmp, "BLUETOOTH" ) == 0 ) {
		return AF_BLUETOOTH;
	}
	else if( name[0] >= '0' && name[0] <= '9' ) {
		return atoi( name );
	}
	return AF_UNSPEC;
}

INLINE int Socket_typebyname( const char *name ) {
	char tmp[20];
	my_strncpyu( tmp, name, sizeof( tmp ) );
	if( strcmp( tmp, "STREAM" ) == 0 ) {
		return SOCK_STREAM;
	}
	else if( strcmp( tmp, "DGRAM" ) == 0 ) {
		return SOCK_DGRAM;
	}
	else if( strcmp( tmp, "RAW" ) == 0 ) {
		return SOCK_RAW;
	}
	else if( name[0] >= '0' && name[0] <= '9' ) {
		return atoi( name );
	}
	return 0;
}

INLINE int Socket_protobyname( const char *name ) {
	char tmp[20];
	my_strncpyu( tmp, name, sizeof( tmp ) );
	if( strcmp( tmp, "TCP" ) == 0 ) {
		return IPPROTO_TCP;
	}
	else if( strcmp( tmp, "UDP" ) == 0 ) {
		return IPPROTO_UDP;
	}
	else if( strcmp( tmp, "ICMP" ) == 0 ) {
		return IPPROTO_ICMP;
	}
	else if( strcmp( tmp, "RFCOMM" ) == 0 ) {
		return BTPROTO_RFCOMM;
	}
	else if( strcmp( tmp, "L2CAP" ) == 0 ) {
		return BTPROTO_L2CAP;
	}
	else if( name[0] >= '0' && name[0] <= '9' ) {
		return atoi( name );
	}
	else {
		struct protoent *pe;
		pe = getprotobyname( (char *) name );
		return pe != NULL ? pe->p_proto : 0;
	}
}

INLINE int Socket_setopt(
	SV *this, int level, int optname, const void *optval, socklen_t optlen
) {
	my_thread_var_t *tv;
	int r;
	tv = my_thread_var_find( this );
	if( tv != NULL ) {
		TV_LOCK( tv );
		r = setsockopt( tv->sock, level, optname, optval, optlen );
		TV_ERRNO( tv, r == SOCKET_ERROR ? Socket_errno() : 0 );
		TV_UNLOCK( tv );
		return r;
	}
	else {
		return SOCKET_ERROR;
	}
}

INLINE int Socket_getopt(
	SV *this, int level, int optname, void *optval, socklen_t *optlen
) {
	my_thread_var_t *tv;
	int r;
	tv = my_thread_var_find( this );
	if( tv != NULL ) {
		TV_LOCK( tv );
		r = getsockopt( tv->sock, level, optname, optval, optlen );
		TV_ERRNO( tv, r == SOCKET_ERROR ? Socket_errno() : 0 );
		TV_UNLOCK( tv );
		return r;
	}
	else {
		return SOCKET_ERROR;
	}
}

INLINE int Socket_setblocking( SOCKET s, int value ) {
#ifdef _WIN32
	int r;
	u_long val = (u_long) ! value;
	r = ioctlsocket( s, FIONBIO, &val );
#ifdef SC_DEBUG
	_debug( "ioctlsocket socket %u %d %d\n", s, r, Socket_errno() );
#endif
#else
	DWORD flags;
	int r;
	flags = fcntl( s, F_GETFL );
	if( ! value )
		r = fcntl( s, F_SETFL, flags | O_NONBLOCK );
	else
		r = fcntl( s, F_SETFL, flags & (~O_NONBLOCK) );
#ifdef SC_DEBUG
	_debug( "set blocking %u from %d to %d\n", s, ! (flags & O_NONBLOCK), value );
#endif
#endif
	return r;
}

INLINE int Socket_write( SV *this, const char *buf, size_t len ) {
	my_thread_var_t *tv;
	int r;
	tv = my_thread_var_find( this );
	if( tv == NULL )
		return SOCKET_ERROR;
	TV_LOCK( tv );
	r = send( tv->sock, buf, (int) len, 0 );
	if( r == SOCKET_ERROR ) {
		TV_ERRNOLAST( tv );
		switch( tv->last_errno ) {
		case EWOULDBLOCK:
			/* threat not as an error */
			tv->last_errno = 0;
			r = 0;
			break;
		default:
#ifdef SC_DEBUG
			_debug( "write error %u\n", tv->last_errno );
#endif
			tv->state = SOCK_STATE_ERROR;
			r = SOCKET_ERROR;
			break;
		}
		goto exit;
	}
	else if( r == 0 ) {
		TV_ERRNO( tv, ECONNRESET );
#ifdef SC_DEBUG
		_debug( "write error %u\n", tv->last_errno );
#endif
		tv->state = SOCK_STATE_ERROR;
		r = SOCKET_ERROR;
		goto exit;
	}
	TV_ERRNO( tv, 0 );
exit:
	TV_UNLOCK( tv );
	return r;
}

/*
INLINE unsigned short my_ntohs( unsigned short a ) {
#if BYTEORDER == 0x4321 || BYTEORDER == 0x87654321
	return a;
#else
	return ((a >> 8) & 0xff) | (a & 0xff) << 8;
#endif
}

INLINE unsigned short my_htons( unsigned short a ) {
#if BYTEORDER == 0x4321 || BYTEORDER == 0x87654321
	return a;
#else
	return ((a >> 8) & 0xff) | (a & 0xff) << 8;
#endif
}
*/

INLINE int my_ba2str( const bdaddr_t *ba, char *str ) {
	register const unsigned char *b = (const unsigned char *) ba;
	return sprintf( str,
		"%2.2X:%2.2X:%2.2X:%2.2X:%2.2X:%2.2X",
		b[5], b[4], b[3], b[2], b[1], b[0]
	);
}

INLINE int my_str2ba( const char *str, bdaddr_t *ba ) {
	register unsigned char *b = (unsigned char *) ba;
	const char *ptr = (str != NULL ? str : "00:00:00:00:00:00");
	int i;
	for( i = 0; i < 6; i ++ ) {
		b[5 - i] = (uint8_t) strtol( ptr, NULL, 16 );
		if( i != 5 && ! (ptr = strchr( ptr, ':' )) )
			ptr = ":00:00:00:00:00";
		ptr ++;
	}
	return 0;
}

INLINE char *my_itoa( char *str, long value, int radix ) {
	static const char HEXTAB[] = {
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
		'A', 'B', 'C', 'D', 'E', 'F'
	};
	int rem;
    char tmp[21], *ret = tmp, neg = 0;
	if( value < 0 ) {
		value = -value;
		neg = 1;
	}
	switch( radix ) {
	case 16:
		do {
			rem = (int) (value % 16);
			value /= 16;
			*ret ++ = HEXTAB[rem];
		} while( value > 0 );
		break;
	default:
		do {
			*ret ++ = (char) ((value % radix) + '0');
			value /= radix;
		} while( value > 0 );
		if( neg )
			*ret ++ = '-';
	}
	for( ret --; ret >= tmp; *str ++ = *ret, ret -- );
	*str = '\0';
	return str;
}

INLINE char *my_strncpy( char *dst, const char *src, size_t len ) {
	register char ch;
	for( ; len > 0; len -- ) {
		if( (ch = *src ++) == '\0' ) {
			*dst = '\0';
			return dst;
		}
		*dst ++ = ch;
	}
	*dst = '\0';
	return dst;
}

INLINE char *my_strcpy( char *dst, const char *src ) {
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

INLINE char *my_strncpyu( char *dst, const char *src, size_t len ) {
	register char ch;
	for( ; len > 0; len -- ) {
		if( (ch = *src ++) == '\0' ) {
			*dst = '\0';
			return dst;
		}
		*dst ++ = toupper( ch );
	}
	*dst = '\0';
	return dst;
}

INLINE int my_stricmp( const char *cs, const char *ct ) {
	register signed char res;
	while( 1 ) {
		if( (res = toupper( *cs ) - toupper( *ct ++ )) != 0 || ! *cs ++ )
			break;
	}
	return res;
}

#ifdef SC_DEBUG

INLINE int my_debug( const char *fmt, ... ) {
	va_list a;
	int r;
	size_t l;
	char *tmp, *s1;
	l = strlen( fmt );
	tmp = malloc( 512 + l );
	s1 = my_strcpy( tmp, "<SC_DEBUG> " );
	s1 = my_strcpy( s1, fmt );
	va_start( a, fmt );
	r = vfprintf( stderr, tmp, a );
	va_end( a );
	free( tmp );
	return r;
}

#endif
