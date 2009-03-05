#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include <c_module.h>

enum export_item_type {
	ITEM_LONG,
	ITEM_CODE,
};

typedef struct st_export_item {
	const char						*name;
	enum export_item_type			type;
	union {
		const char					*function;
		long				value;
	};
} export_item_t;

const export_item_t export_items[] = {
	{ "AF_BLUETOOTH", ITEM_LONG, (const char *) AF_BLUETOOTH },
	{ "AF_INET", ITEM_LONG, (const char *) AF_INET },
	{ "AF_INET6", ITEM_LONG, (const char *) 23 },
	{ "AF_UNIX", ITEM_LONG, (const char *) AF_UNIX },
	{ "AF_UNSPEC", ITEM_LONG, (const char *) AF_UNSPEC },
	{ "AI_PASSIVE", ITEM_LONG, (const char *) 0x0001 },
	{ "AI_CANONNAME", ITEM_LONG, (const char *) 0x0002 },
	{ "AI_NUMERICHOST", ITEM_LONG, (const char *) 0x0004 },
	{ "AI_ADDRCONFIG", ITEM_LONG, (const char *) 0x0400 },
	{ "AI_NUMERICSERV", ITEM_LONG, (const char *) 0x0400 },
	{ "BTPROTO_L2CAP", ITEM_LONG, (const char *) BTPROTO_L2CAP },
	{ "BTPROTO_RFCOMM", ITEM_LONG, (const char *) BTPROTO_RFCOMM },
	{ "IP_TOS", ITEM_LONG, (const char *) IP_TOS },
	{ "IP_TTL", ITEM_LONG, (const char *) IP_TTL },
	{ "IP_HDRINCL", ITEM_LONG, (const char *) IP_HDRINCL },
	{ "IP_OPTIONS", ITEM_LONG, (const char *) IP_OPTIONS },
	{ "IPPROTO_ICMP", ITEM_LONG, (const char *) IPPROTO_ICMP },
	{ "IPPROTO_IP", ITEM_LONG, (const char *) IPPROTO_IP },
	{ "IPPROTO_TCP", ITEM_LONG, (const char *) IPPROTO_TCP },
	{ "IPPROTO_UDP", ITEM_LONG, (const char *) IPPROTO_UDP },
	{ "MSG_OOB", ITEM_LONG, (const char *) MSG_OOB },
	{ "MSG_PEEK", ITEM_LONG, (const char *) MSG_PEEK },
	{ "MSG_DONTROUTE", ITEM_LONG, (const char *) MSG_DONTROUTE },
	{ "MSG_CTRUNC", ITEM_LONG, (const char *) MSG_CTRUNC },
	{ "MSG_TRUNC", ITEM_LONG, (const char *) MSG_TRUNC },
#if defined _WIN32 || defined __CYGWIN__
	{ "MSG_DONTWAIT", ITEM_LONG, (const char *) 0 },
	{ "MSG_WAITALL", ITEM_LONG, (const char *) 0x08 },
#else
	{ "MSG_DONTWAIT", ITEM_LONG, (const char *) MSG_DONTWAIT },
	{ "MSG_WAITALL", ITEM_LONG, (const char *) MSG_WAITALL },
#endif
	{ "NI_DGRAM", ITEM_LONG, (const char *) 16 },
#if defined _WIN32 || defined __CYGWIN__
	{ "NI_NAMEREQD", ITEM_LONG, (const char *) 4 },
	{ "NI_NOFQDN", ITEM_LONG, (const char *) 1 },
	{ "NI_NUMERICHOST", ITEM_LONG, (const char *) 2 },
	{ "NI_NUMERICSERV", ITEM_LONG, (const char *) 8 },
#else
	{ "NI_NAMEREQD", ITEM_LONG, (const char *) 8 },
	{ "NI_NOFQDN", ITEM_LONG, (const char *) 4 },
	{ "NI_NUMERICHOST", ITEM_LONG, (const char *) 1 },
	{ "NI_NUMERICSERV", ITEM_LONG, (const char *) 2 },
#endif
	{ "PF_BLUETOOTH", ITEM_LONG, (const char *) AF_BLUETOOTH },
	{ "PF_INET6", ITEM_LONG, (const char *) 23 },
	{ "PF_INET", ITEM_LONG, (const char *) AF_INET },
	{ "PF_UNIX", ITEM_LONG, (const char *) AF_UNIX },
	{ "PF_UNSPEC", ITEM_LONG, (const char *) AF_UNSPEC },
	{ "SC_STATE_INIT", ITEM_LONG, (const char *) SC_STATE_INIT },
	{ "SC_STATE_BOUND", ITEM_LONG, (const char *) SC_STATE_BOUND },
	{ "SC_STATE_LISTEN", ITEM_LONG, (const char *) SC_STATE_LISTEN },
	{ "SC_STATE_CONNECTED", ITEM_LONG, (const char *) SC_STATE_CONNECTED },
	{ "SC_STATE_SHUTDOWN", ITEM_LONG, (const char *) SC_STATE_SHUTDOWN },
	{ "SC_STATE_CLOSED", ITEM_LONG, (const char *) SC_STATE_CLOSED },
	{ "SC_STATE_ERROR", ITEM_LONG, (const char *) SC_STATE_ERROR },
	{ "SD_RECEIVE", ITEM_LONG, (const char *) 0 },
	{ "SD_SEND", ITEM_LONG, (const char *) 1 },
	{ "SD_BOTH", ITEM_LONG, (const char *) 2 },
	{ "SO_DEBUG", ITEM_LONG, (const char *) SO_DEBUG },
	{ "SO_REUSEADDR", ITEM_LONG, (const char *) SO_REUSEADDR },
	{ "SO_TYPE", ITEM_LONG, (const char *) SO_TYPE },
	{ "SO_ERROR", ITEM_LONG, (const char *) SO_ERROR },
	{ "SO_DONTROUTE", ITEM_LONG, (const char *) SO_DONTROUTE },
	{ "SO_SNDBUF", ITEM_LONG, (const char *) SO_SNDBUF },
	{ "SO_RCVBUF", ITEM_LONG, (const char *) SO_RCVBUF },
	{ "SO_KEEPALIVE", ITEM_LONG, (const char *) SO_KEEPALIVE },
	{ "SO_OOBINLINE", ITEM_LONG, (const char *) SO_OOBINLINE },
	{ "SO_LINGER", ITEM_LONG, (const char *) SO_LINGER },
	{ "SO_RCVLOWAT", ITEM_LONG, (const char *) SO_RCVLOWAT },
	{ "SO_SNDLOWAT", ITEM_LONG, (const char *) SO_SNDLOWAT },
	{ "SO_RCVTIMEO", ITEM_LONG, (const char *) SO_RCVTIMEO },
	{ "SO_SNDTIMEO", ITEM_LONG, (const char *) SO_SNDTIMEO },
#if defined _WIN32 || defined __CYGWIN__
	{ "SO_ACCEPTCON", ITEM_LONG, (const char *) 0x0002 },
#else
	{ "SO_ACCEPTCON", ITEM_LONG, (const char *) 80 },
#endif
	{ "SOCK_DGRAM", ITEM_LONG, (const char *) SOCK_DGRAM },
	{ "SOCK_STREAM", ITEM_LONG, (const char *) SOCK_STREAM },
	{ "SOL_SOCKET", ITEM_LONG, (const char *) SOL_SOCKET },
	{ "SOL_IP", ITEM_LONG, (const char *) 0 },
	{ "SOL_TCP", ITEM_LONG, (const char *) 6 },
	{ "SOL_UDP", ITEM_LONG, (const char *) 17 },
	{ "SOMAXCONN", ITEM_LONG, (const char *) SOMAXCONN },
	{ "TCP_NODELAY", ITEM_LONG, (const char *) TCP_NODELAY },
	{ "getaddrinfo", ITEM_CODE, "Socket::Class::getaddrinfo" },
	{ "getnameinfo", ITEM_CODE, "Socket::Class::getnameinfo" },
};

const export_item_t *export_items_end =
	export_items + (sizeof(export_items) / sizeof(export_item_t));


MODULE = Socket::Class::Const		PACKAGE = Socket::Class::Const

void
export( package, ... )
	SV *package;
PREINIT:
	int i, make_var;
	char *str, *pkg, *tmp = NULL;
	const char *s2;
	STRLEN len, pkg_len;
	HV *stash;
	SV *sv;
	const export_item_t *item;
PPCODE:
	pkg = SvPV( package, pkg_len );
	stash = gv_stashpvn( pkg, (I32) pkg_len, TRUE );
	Newx( tmp, pkg_len + 3, char );
	Copy( pkg, tmp, pkg_len, char );
	tmp[pkg_len ++] = ':';
	tmp[pkg_len ++] = ':';
	for( i = 1; i < items; i ++ ) {
		s2 = str = SvPV( ST(i), len );
		switch( *str ) {
		case ':':
			if( strcmp( str, ":all" ) == 0 ) {
				for( item = export_items; item < export_items_end; item ++ ) {
					switch( item->type ) {
					case ITEM_LONG:
						newCONSTSUB( stash,
							item->name, newSViv( (IV) item->value ) );
						break;
					case ITEM_CODE:
						sv = (SV *) get_cv( item->function, 0 );
						if( sv == NULL ) {
							s2 = item->function;
							goto not_found;
						}
						len = (STRLEN) strlen( item->name );
						(void) hv_store( stash, item->name, (I32) len, sv, 0 );
						break;
					}
				}
			}
			else {
				Perl_croak( aTHX_ "Invalid export tag \"%s\"", str );
			}
			continue;
		case '$':
			str ++, len --;
			make_var = 1;
			break;
		case '&':
			str ++, len --;
		default:
			make_var = 0;
			break;
		}
		for( item = export_items; item < export_items_end; item ++ ) {
			if( item->name[0] < str[0] )
				continue;
			if( item->name[0] > str[0] )
				goto not_found;
			if( strcmp( item->name, str ) != 0 )
				continue;
			switch( item->type ) {
			case ITEM_LONG:
				if( make_var ) {
					Renew( tmp, pkg_len + len + 1, char );
					Copy( str, tmp + pkg_len, len + 1, char );
					sv_setiv( get_sv( tmp, TRUE ), (IV) item->value );
				}
				else {
					newCONSTSUB( stash, str, newSViv( (IV) item->value ) );
				}
				break;
			case ITEM_CODE:
				if( make_var )
					goto not_found;
				sv = (SV *) get_cv( item->function, 0 );
				if( sv == NULL ) {
					s2 = item->function;
					goto not_found;
				}
				(void) hv_store( stash, str, (I32) len, sv, 0 );
				break;
			}
			break;
		}
	}
	if( FALSE ) {
not_found:
		Safefree( tmp );
		Perl_croak( aTHX_ "\"%s\" does not exist", s2, pkg );
	}
	Safefree( tmp );
	XSRETURN_EMPTY;
