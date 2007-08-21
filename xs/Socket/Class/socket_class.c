#include "socket_class.h"

my_global_t global;

void my_thread_var_add( my_thread_var_t *tv ) {
	_debug( "add tv %lu\n", tv );
	tv->tid = get_current_thread_id();
#ifdef SC_THREADS
	MUTEX_INIT( &tv->thread_lock );
#endif
	GLOBAL_LOCK();
	if( global.first_thread == NULL )
		global.first_thread = tv;
	else {
		global.last_thread->next = tv;
		tv->prev = global.last_thread;
	}
	global.last_thread = tv;
	GLOBAL_UNLOCK();
}

void my_thread_var_free( my_thread_var_t *tv ) {
	TV_LOCK( tv );
	_debug( "closing socket %d tv %u\n", tv->sock, tv );
	Socket_close( tv->sock );
	if( tv->s_domain == AF_UNIX ) {
		remove( ((struct sockaddr_un *) tv->l_addr.a)->sun_path );
	}
	Safefree( tv->rcvbuf );
	Safefree( tv->classname );
	TV_UNLOCK( tv );
#ifdef SC_THREADS
	MUTEX_DESTROY( &tv->thread_lock );
#endif
	Safefree( tv );
}

void my_thread_var_rem( my_thread_var_t *tv ) {
	GLOBAL_LOCK();
	_debug( "removing thread_var %lu tid 0x%08x\n", tv, get_current_thread_id() );
	if( tv == global.last_thread )
		global.last_thread = tv->prev;
	if( tv == global.first_thread )
		global.first_thread = tv->next;
	if( tv->prev )
		tv->prev->next = tv->next;
	if( tv->next )
		tv->next->prev = tv->prev;
	my_thread_var_free( tv );
	GLOBAL_UNLOCK();
}

my_thread_var_t *my_thread_var_find( SV *sv ) {
	register my_thread_var_t *tvf, *tvl, *tv;
	if( global.destroyed )
		return NULL;
	GLOBAL_LOCK();
	if( ! SvROK( sv ) || ! ( sv = SvRV( sv ) ) || ! SvIOK( sv ) ) return NULL;
	tv = INT2PTR( my_thread_var_t *, SvIV( sv ) );
	//_debug( "looking for tv %u\n", tv );
	tvf = global.first_thread;
	tvl = global.last_thread;
	while( 1 ) {
		if( tvl == NULL )
			break;
		if( tvl == tv )
			goto retl;
		else if( tvf == tv )
			goto retf;
		tvl = tvl->prev;
		tvf = tvf->next;
	}
	_debug( "tv %u not found\n", tv );
retf:
	GLOBAL_UNLOCK();
	return tvf;
retl:
	GLOBAL_UNLOCK();
	return tvl;
}

#ifdef _WIN32

#define ISEOL(c) ((c) == '\r' || (c) == '\n') 

void Socket_error( char *str, DWORD len, long num ) {
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

#else

void Socket_error( char *str, DWORD len, long num ) {
	char *s1, *s2;
	int ret;
#ifdef SC_DEBUG
	ret = snprintf( str, len, "(%d) ", num );
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

void Socket_setaddr_UNIX( my_sockaddr_t *addr, const char *path ) {
	struct sockaddr_un *a = (struct sockaddr_un *) addr->a;
	addr->l = sizeof( struct sockaddr_un );
	a->sun_family = AF_UNIX;
	if( path != NULL )
		my_strncpy( a->sun_path, path, 100 );
}

int Socket_setaddr_INET( tv, host, port, use )
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
		_debug( "getaddrinfo() failed %d\n", r );
		return r;
	}
	addr->l = (int) ail->ai_addrlen;
	memcpy( addr->a, ail->ai_addr, ail->ai_addrlen );
	freeaddrinfo( ail );
#else
	my_sockaddr_t *addr;
	struct hostent *he;
	if( tv->s_domain == AF_BLUETOOTH )
		return Socket_setaddr_BTH( tv, host, port, use );
	GLOBAL_LOCK();
	addr = (use == ADDRUSE_LISTEN) ? &tv->l_addr : &tv->r_addr;
	if( tv->s_domain == AF_INET ) {
		struct sockaddr_in *in;
		addr->l = sizeof(struct sockaddr_in);
		in = (struct sockaddr_in *) addr->a;
		in->sin_family = AF_INET;
		if( host == NULL && use != ADDRUSE_LISTEN )
			host = "127.0.0.0";
		if( host != NULL ) {
			if( host[0] >= '0' && host[0] <= '9' )
				in->sin_addr.s_addr = inet_addr( host );
			else {
				he = gethostbyname( host );
				if( he == NULL )
					return SOCKET_ERROR;
				in->sin_addr.s_addr = inet_addr( he->h_addr );
			}
		}
		if( port != NULL ) {
			if( port[0] >= '0' && port[0] <= '9' )
				in->sin_port = htons( atol( port ) );
			else {
				struct servent *se;
				se = getservbyname( port, NULL );
				if( se == NULL )
					return SOCKET_ERROR;
				in->sin_port = se->s_port;
			}
		}
	}
	else {
		struct sockaddr_in6 *in6;
		addr->l = sizeof(struct sockaddr_in6);
		in6 = (struct sockaddr_in6 *) addr->a;
		in6->sin6_family = AF_INET6;
		if( host != NULL ) {
			if( ( host[0] >= '0' && host[0] <= '9' ) || host[0] == ':' ) {
				if( inet_pton( AF_INET6, host, &in6->sin6_addr ) != 0 ) {
					_debug( "inet_pton failed %d", Socket_errno() );
					return SOCKET_ERROR;
				}
			}
			else {
				he = gethostbyname( host );
				if( he == NULL )
					return SOCKET_ERROR;
				if( he->h_addrtype != AF_INET6 )
					return SOCKET_ERROR;
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
					return SOCKET_ERROR;
				in6->sin6_port = se->s_port;
			}
		}
	}
	GLOBAL_UNLOCK();
#endif
	return 0;
}

int Socket_setaddr_BTH( tv, host, port, use )
	my_thread_var_t *tv;
	const char *host;
	const char *port;
	int use;
{
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
		_debug( "using BLUETOOTH RFCOMM host %s channel %s\n", host, port );
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
		_debug( "using BLUETOOTH L2CAP host %s psm %s\n", host, port );
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

int Socket_domainbyname( const char *name ) {
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
	else if( is_numeric( name ) ) {
		return atoi( name );
	}
	return 0;
}

int Socket_typebyname( const char *name ) {
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
	else if( is_numeric( name ) ) {
		return atoi( name );
	}
	return 0;
}

int Socket_protobyname( const char *name ) {
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
	else if( is_numeric( name ) ) {
		return atoi( name );
	}
	else {
		struct protoent *pe;
		pe = getprotobyname( name );
		return pe != NULL ? pe->p_proto : 0;
	}
}

int Socket_setopt( SV *this, int level, int optname, const void *optval, socklen_t optlen ) {
	my_thread_var_t *tv;
	int r;
	tv = my_thread_var_find( this );
	if( tv != NULL ) {
		TV_LOCK( tv );
		r = setsockopt( tv->sock, level, optname, optval, optlen );
		tv->last_errno = r == SOCKET_ERROR ? Socket_errno() : 0;
		TV_UNLOCK( tv );
		return r;
	}
	else {
		return SOCKET_ERROR;
	}
}

int Socket_getopt( SV *this, int level, int optname, void *optval, socklen_t *optlen ) {
	my_thread_var_t *tv;
	int r;
	tv = my_thread_var_find( this );
	if( tv != NULL ) {
		TV_LOCK( tv );
		r = getsockopt( tv->sock, level, optname, optval, optlen );
		tv->last_errno = r == SOCKET_ERROR ? Socket_errno() : 0;
		TV_UNLOCK( tv );
		return r;
	}
	else {
		return SOCKET_ERROR;
	}
}

int Socket_setblocking( SOCKET s, int value ) {
#ifdef _WIN32
	int r;
	value = ! value;
	r = ioctlsocket( s, FIONBIO, &value );
	_debug( "ioctlsocket socket %u %d %d\n", s, r, Socket_errno() );
#else
	DWORD flags;
	int r;
	flags = fcntl( s, F_GETFL );
	if( ! value )
		r = fcntl( s, F_SETFL, flags | O_NONBLOCK );
	else
		r = fcntl( s, F_SETFL, flags & (~O_NONBLOCK) );
	_debug( "set blocking %u from %d to %d\n", s, ! (flags & O_NONBLOCK), value );
#endif
	return r;
}

int Socket_write( SV *this, const char *buf, size_t len ) {
	my_thread_var_t *tv;
	STRLEN pos;
	int r;
	tv = my_thread_var_find( this );
	if( tv == NULL )
		return SOCKET_ERROR;
	TV_LOCK( tv );
	pos = 0;
	while( len > 0 ) {
		r = send( tv->sock, &buf[pos], (int) len, 0 );
		if( r == SOCKET_ERROR ) {
			if( pos > 0 )
				break;
			tv->last_errno = Socket_errno();
			switch( tv->last_errno ) {
			case EWOULDBLOCK:
				// threat not as an error
				tv->last_errno = 0;
				r = 0;
				break;
			default:
				_debug( "write error %u\n", tv->last_errno );
				tv->state = SOCK_STATE_ERROR;
				r = SOCKET_ERROR;
				break;
			}
			goto exit;
		}
		else if( r == 0 ) {
			if( pos > 0 )
				break;
			tv->last_errno = ECONNRESET;
			_debug( "write error %u\n", tv->last_errno );
			tv->state = SOCK_STATE_ERROR;
			r = SOCKET_ERROR;
			goto exit;
		}
		else {
			pos += r;
			len -= r;
		}
	}
	tv->last_errno = 0;
	r = (int) pos;
exit:
	TV_UNLOCK( tv );
	return r;
}

int my_ba2str( const bdaddr_t *ba, char *str ) {
	register const unsigned char *b = (const unsigned char *) ba;
	return sprintf( str,
		"%2.2X:%2.2X:%2.2X:%2.2X:%2.2X:%2.2X",
		b[5], b[4], b[3], b[2], b[1], b[0]
	);
}

int my_str2ba( const char *str, bdaddr_t *ba ) {
	register unsigned char *b = (unsigned char *) ba;
	const char *ptr = ( str != NULL ? str : "00:00:00:00:00:00" );
	int i;
	for( i = 0; i < 6; i ++ ) {
		//_debug( "converting %d %s\n", i, ptr );
		b[5 - i] = (uint8_t) strtol( ptr, NULL, 16 );
		if( i != 5 && ! ( ptr = strchr( ptr, ':' ) ) )
			ptr = ":00:00:00:00:00";
		ptr ++;
	}
	return 0;
}

DWORD get_current_thread_id() {
#ifdef USE_ITHREADS
#ifdef _WIN32
	return GetCurrentThreadId();
#else
	return (DWORD) pthread_self();
#endif
#else
	return 0;
#endif
}

#ifdef _WIN32
int snprintf( char *str, int n, char *fmt, ... ) {
	int r;
	va_list a;
	va_start( a, fmt );
	r = vsnprintf( str, n, fmt, a );
	va_end( a );
	return r;
}
#endif

int is_numeric( const char *str ) {
	for( ; *str != '\0'; str ++ ) {
		if( *str < '0' || *str > '9' )
			return 0;
	}
	return 1;
}

char *my_strrev( char *str, size_t len ) {
	register char *p1, *p2;
	if( ! str || ! *str ) return str;
	for( p1 = str, p2 = str + len - 1; p2 > p1; ++ p1, -- p2 ) {
		*p1 ^= *p2;
		*p2 ^= *p1;
		*p1 ^= *p2;
	}
	return str;
}

char *my_itoa( char *str, long value, int radix ) {
	register int rem;
	register char *ret = str;
	switch( radix ) {
	case 16:
		do {
			rem = value % 16;
			value /= 16;
			switch( rem ) {
			case 10:
				*ret ++ = 'A';
				break;
			case 11:
				*ret ++ = 'B';
				break;
			case 12:
				*ret ++ = 'C';
				break;
			case 13:
				*ret ++ = 'D';
				break;
			case 14:
				*ret ++ = 'E';
				break;
			case 15:
				*ret ++ = 'F';
				break;
			default:
				*ret ++ = (char) ( rem + 0x30 );
				break;
			}
		} while( value != 0 );
		break;
	default:
		do {
			rem = value % radix;
			value /= radix;
			*ret ++ = (char) ( rem + 0x30 );
		} while( value != 0 );
	}
	*ret = '\0' ;
	my_strrev( str, ret - str );
	return ret;
}

char *my_strncpy( char *dst, const char *src, size_t len ) {
	register char ch;
	for( ; len > 0; len -- ) {
		if( ( ch = *src ++ ) == '\0' ) {
			*dst = '\0';
			return dst;
		}
		*dst ++ = ch;
	}
	*dst = '\0';
	return dst;
}

char *my_strcpy( char *dst, const char *src ) {
	register char ch;
	while( 1 ) {
		if( ( ch = *src ++ ) == '\0' ) {
			break;
		}
		*dst ++ = ch;
	}
	*dst = '\0';
	return dst;
}

char *my_strncpyu( char *dst, const char *src, size_t len ) {
	register char ch;
	for( ; len > 0; len -- ) {
		if( ( ch = *src ++ ) == '\0' ) {
			*dst = '\0';
			return dst;
		}
		*dst ++ = toupper( ch );
	}
	*dst = '\0';
	return dst;
}

int my_stricmp( const char *cs, const char *ct ) {
	register signed char res;
	while( 1 ) {
		if( ( res = toupper( *cs ) - toupper( *ct ++ ) ) != 0 || ! *cs ++ )
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
	tmp = malloc( 10 + l );
	s1 = my_strcpy( tmp, "<DEBUG> " );
	s1 = my_strcpy( s1, fmt );
	va_start( a, fmt );
	r = vprintf( tmp, a );
	va_end( a );
	free( tmp );
	return r;
}

#endif
