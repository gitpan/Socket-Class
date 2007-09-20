#ifndef __INCLUDE_SOCKET_CLASS_H__
#define __INCLUDE_SOCKET_CLASS_H__ 1

#include <EXTERN.h>
#include <perl.h>
#undef USE_SOCKETS_AS_HANDLES
#include <XSUB.h>

// removing from perl
#undef free
#undef malloc
#undef realloc
#undef memcpy
#undef calloc
// removed from perl

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/timeb.h>
#include <math.h>

#ifdef _WIN32
#include <initguid.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <tchar.h>
#include <io.h>
#else // posix
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif

#ifdef SC_USE_BLUEZ
#include <bluetooth/bluetooth.h>
#include <bluetooth/rfcomm.h>
#include <bluetooth/l2cap.h>
#endif

#ifdef SC_USE_WS2BTH
//#undef NTDDI_VERSION
//#define NTDDI_VERSION NTDDI_WINXPSP2
#include <ws2bth.h>
#endif

#define __PACKAGE__ "Socket::Class"

//#define SC_DEBUG 1
#ifdef SC_DEBUG
int my_debug( const char *fmt, ... );
#if SC_DEBUG > 1
#define _tdebug my_debug
#else
#define _tdebug
#endif
#define _debug my_debug
#else
#define _debug
#define _tdebug
#endif

#ifdef _WIN32
#undef vsnprintf
#define vsnprintf _vsnprintf
#undef snprintf
#define snprintf _snprintf
#endif

#undef BYTE
#define BYTE unsigned char
#undef WORD
#define WORD unsigned short
#undef DWORD
#define DWORD unsigned int

#undef XLONG
#undef UXLONG
#if defined __unix__
#	define XLONG long long
#	define UXLONG unsigned long long
#elif defined _WIN32
#	define XLONG __int64
#	define UXLONG unsigned __int64
#else
#	define XLONG long
#	define UXLONG unsigned long
#endif

#ifdef _WIN32
typedef unsigned short			uint16_t;
typedef unsigned char			uint8_t;
typedef unsigned short			sa_family_t;
#else
typedef unsigned long			u_long;
#endif

// removing from perlio
#undef htonl
#undef htons
#undef ntohl
#undef ntohs
#undef accept
#undef bind
#undef connect
#undef endhostent
#undef endnetent
#undef endprotoent
#undef endservent
#undef gethostbyaddr
#undef gethostbyname
#undef gethostent
#undef gethostname
#undef getnetbyaddr
#undef getnetbyname
#undef getnetent
#undef getpeername
#undef getprotobyname
#undef getprotobynumber
#undef getprotoent
#undef getservbyname
#undef getservbyport
#undef getservent
#undef getsockname
#undef getsockopt
#undef inet_addr
#undef inet_ntoa
#undef listen
#undef recv
#undef recvfrom
#undef select
#undef send
#undef sendto
#undef sethostent
#undef setnetent
#undef setprotoent
#undef setservent
#undef setsockopt
#undef shutdown
#undef socket
#undef socketpair
#undef open
#undef close
// removed from perlio

// removing from perl
#undef Newx
#define Newx(v,c,t) \
	( (v) = ( (t*) malloc( (c) * sizeof(t) ) ) )
#undef Newxz
#define Newxz(v,c,t) \
	( (v) = ( (t*) calloc( (c), sizeof(t) ) ) )
#undef Safefree
#define Safefree(x) \
	if( (x) != NULL ) { free( (x) ); (x) = NULL; }
#undef Renew
#define Renew(v,n,t) \
	( (v) = ( (t*) realloc( (void *) (v), (n) * sizeof(t) ) ) )
#undef Copy
#define Copy(s,d,n,t) \
	( memcpy( (char*)(d), (const char*)(s), (n) * sizeof(t) ) )
// removed from perl

#ifdef _WIN32 // win32

#define EWOULDBLOCK				WSAEWOULDBLOCK
#define ECONNRESET				WSAECONNRESET
#define EINPROGRESS				WSAEINPROGRESS
#define ETIMEDOUT				WSAETIMEDOUT

#ifndef AF_BLUETOOTH
#define AF_BLUETOOTH			32
#endif

struct sockaddr_un {
	sa_family_t					sun_family;				// AF_UNIX
	char						sun_path[108];			// pathname
};

#else // posix

#define SOCKET					int
#define SOCKET_ERROR			-1
#define INVALID_SOCKET			-1
#define ESOCKETBROKEN			1111

#ifndef AF_BLUETOOTH
#define AF_BLUETOOTH			31
#endif

#ifndef AF_INET6
#define SC_OLDNET 1
#define AF_INET6				23
struct in6_addr {
	uint8_t 	  s6_addr[16];
};
struct sockaddr_in6 {
	sa_family_t	  sin6_family;		/* AF_INET6 */
	in_port_t	  sin6_port;		/* Port number. */
	uint32_t	  sin6_flowinfo;	/* Traffic class and flow inf. */
	struct in6_addr sin6_addr;		/* IPv6 address. */
	uint32_t	  sin6_scope_id;	/* Set of interfaces for a scope. */
};
#endif

#endif // posix

#ifndef NI_MAXHOST
#define NI_MAXHOST				1025
#endif
#ifndef NI_MAXSERV
#define NI_MAXSERV				32
#endif

#undef MAX
#define MAX(x,y) ( (x) < (y) ? (y) : (x) )
#undef MIN
#define MIN(x,y) ( (x) < (y) ? (x) : (y) )

#ifdef _WIN32
#define BTPROTO_RFCOMM			0x0003
#define BTPROTO_L2CAP			0x0100
#else
#ifndef SC_HAS_BLUETOOTH
#define BTPROTO_RFCOMM			3
#define BTPROTO_L2CAP			0
#endif
#endif

#define SOCK_STATE_INIT			0
#define SOCK_STATE_BOUND		1
#define SOCK_STATE_LISTEN		2
#define SOCK_STATE_CONNECTED	3
#define SOCK_STATE_CLOSED		4
#define SOCK_STATE_ERROR		99

#define ADDRUSE_CONNECT			0
#define ADDRUSE_LISTEN			1

#ifndef SC_USE_BLUEZ
typedef struct st_bdaddr {
#ifdef _WIN32
	union {
		ULONGLONG				ull;
		uint8_t					b[6];
	};
#else
	uint8_t						b[6];
#endif
} bdaddr_t;
#endif

#ifdef _WIN32

#include <pshpack1.h>
typedef struct st_sockaddr_bt {
    sa_family_t		bt_family;
    bdaddr_t		bt_bdaddr;		// Bluetooth device address
    GUID			bt_classid; 	// [OPTIONAL] system will query SDP for port
    ULONG			bt_port;		// RFCOMM channel or L2CAP PSM
} sockaddr_bt_t;
typedef sockaddr_bt_t			SOCKADDR_RFCOMM;
typedef sockaddr_bt_t			SOCKADDR_L2CAP;
#include <poppack.h>

#else // posix

struct st_sockaddr_rc {
	sa_family_t			bt_family;
	bdaddr_t			bt_bdaddr;
	uint8_t				bt_port;
};
struct st_sockaddr_l2 {
	sa_family_t			bt_family;
	unsigned short		bt_port;
	bdaddr_t			bt_bdaddr;
};
typedef struct st_sockaddr_rc	SOCKADDR_RFCOMM;
typedef struct st_sockaddr_l2	SOCKADDR_L2CAP;

#endif // posix

#define SOCKADDR_SIZE_MAX		128

typedef struct st_my_sockaddr {
	socklen_t					l;
	char						a[SOCKADDR_SIZE_MAX];
} my_sockaddr_t;

#define MYSASIZE(sa)			(sa).l + sizeof( socklen_t )

typedef struct st_my_thread_var {
	struct st_my_thread_var		*prev, *next;
	SOCKET						sock;
	int							s_domain;
	int							s_type;
	int							s_proto;
	my_sockaddr_t				l_addr, r_addr;
	char						*rcvbuf;
	size_t						rcvbuf_len;
	int							state;
	BYTE						non_blocking;
	struct timeval				timeout;
	char						*classname;
	DWORD						tid;
	long						last_errno;
	char						last_error[256];
#ifdef SC_THREADS
	perl_mutex					thread_lock;
#endif
} my_thread_var_t;

#define SC_TV_CASCADE			9

typedef struct st_my_global {
	my_thread_var_t				*first_thread[SC_TV_CASCADE];
	my_thread_var_t				*last_thread[SC_TV_CASCADE];
	long						last_errno;
	char						last_error[256];
	int							destroyed;
#ifdef SC_THREADS
	perl_mutex					thread_lock;
#endif
} my_global_t;

extern my_global_t global;

#ifdef SC_THREADS
#define GLOBAL_LOCK() \
	_tdebug( "global lock called at %s line %d\n", __FILE__, __LINE__ ); \
	MUTEX_LOCK( &global.thread_lock )
#define GLOBAL_UNLOCK() \
	_tdebug( "global unlock called at %s line %d\n", __FILE__, __LINE__ ); \
	MUTEX_UNLOCK( &global.thread_lock )
#define TV_LOCK(tv) \
	_tdebug( "tv lock 0x%08X called at %s line %d\n", tv, __FILE__, __LINE__ ); \
	MUTEX_LOCK( &tv->thread_lock )
#define TV_UNLOCK(tv) \
	_tdebug( "tv unlock 0x%08X called at %s line %d\n", tv, __FILE__, __LINE__ ); \
	MUTEX_UNLOCK( &tv->thread_lock )
#define TV_UNLOCK_SAFE(tv) \
	if( tv != NULL ) { \
		_tdebug( "tv unlock 0x%08X called at %s line %d\n", tv, __FILE__, __LINE__ ); \
		MUTEX_UNLOCK( &tv->thread_lock ); \
	}
#else // no threads
#define GLOBAL_LOCK()
#define GLOBAL_UNLOCK()
#define TV_LOCK(tv)
#define TV_UNLOCK(tv)
#define TV_UNLOCK_SAFE(tv)		{}
#endif // threads

#define TV_ERRNOLAST(tv) \
	(tv)->last_error[0] = '\0'; \
	(tv)->last_errno = Socket_errno()

#define TV_ERRNO(tv,code) \
	(tv)->last_error[0] = '\0'; \
	(tv)->last_errno = code

#define TV_ERROR(tv,str) \
	my_strncpy( (tv)->last_error, str, sizeof( (tv)->last_error ) ); \
	(tv)->last_errno = -1

void my_thread_var_add( my_thread_var_t *tv );
void my_thread_var_rem( my_thread_var_t *tv );
void my_thread_var_free( my_thread_var_t *tv );
my_thread_var_t *my_thread_var_find( SV *sv );

DWORD get_current_thread_id();

char *my_itoa( char *str, long value, int radix );
char *my_strncpy( char *dst, const char *src, size_t len );
char *my_strcpy( char *dst, const char *src );
char *my_strncpyu( char *dst, const char *src, size_t len );
int my_stricmp( const char *cs, const char *ct );

#ifdef _WIN32 // win32
#define Socket_close(s) \
	if( (s) != INVALID_SOCKET ) { \
		closesocket( (s) ); (s) = (SOCKET) INVALID_SOCKET; \
	}
#define Socket_errno()            WSAGetLastError()
#else // posix
#define Socket_close(s) \
	if( (s) != INVALID_SOCKET ) { \
		close( (s) ); (s) = (SOCKET) INVALID_SOCKET; \
	}
#define Socket_errno()            errno
#endif // posix

void Socket_setaddr_UNIX( my_sockaddr_t *addr, const char *path );
int Socket_setaddr_INET(
	my_thread_var_t *tv, const char *host, const char *port, int use );
int Socket_setaddr_BTH(
	my_thread_var_t *tv, const char *host, const char *port, int use );
int Socket_setblocking( SOCKET s, int value );
int Socket_setopt(
	SV *this, int level, int optname, const void *optval, socklen_t optlen );
int Socket_getopt(
	SV *this, int level, int optname, void *optval, socklen_t *optlen );
int Socket_domainbyname( const char *name );
int Socket_typebyname( const char *name );
int Socket_protobyname( const char *name );
int Socket_write( SV *this, const char *buf, size_t len );
void Socket_error( char *str, DWORD len, long num );

#define IPPORT4(ip,port) \
	( (ip) >> 0 ) & 0xFF, ( (ip) >> 8 ) & 0xFF, ( (ip) >> 16 ) & 0xFF \
		, ( (ip) >> 24 ) & 0xFF, ntohs( (port) )

#define IP4(ip) \
	( (ip) >> 0 ) & 0xFF, ( (ip) >> 8 ) & 0xFF, ( (ip) >> 16 ) & 0xFF \
		, ( (ip) >> 24 ) & 0xFF

#define IPPORT6(in6,port) \
	(in6)[0], (in6)[1], (in6)[2], (in6)[3], (in6)[4], (in6)[5], \
	(in6)[6], (in6)[7], ntohs( (port) )

#define IP6(in6) \
	(in6)[0], (in6)[1], (in6)[2], (in6)[3], (in6)[4], (in6)[5], \
	(in6)[6], (in6)[7]


int my_ba2str( const bdaddr_t *ba, char *str );
int my_str2ba( const char *str, bdaddr_t *ba );

#ifdef SC_HAS_BLUETOOTH
extern void boot_Socket__Class__BT();
#endif

#ifdef SC_USE_BLUEZ
#include "sc_bluez.h"
#endif

#ifdef SC_USE_WS2BTH
#include "sc_ws2bth.h"
#endif

#endif
