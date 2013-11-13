/*
 * "$Id: auth.h 10996 2013-05-29 11:51:34Z msweet $"
 *
 *   Authorization definitions for the CUPS scheduler.
 *
 *   Copyright 2007-2011 by Apple Inc.
 *   Copyright 1997-2006 by Easy Software Products, all rights reserved.
 *
 *   These coded instructions, statements, and computer programs are the
 *   property of Apple Inc. and are protected by Federal copyright
 *   law.  Distribution and use rights are outlined in the file "LICENSE.txt"
 *   which should have been included with this file.  If this file is
 *   file is missing or damaged, see the license at "http://www.cups.org/".
 */

/*
 * Include necessary headers...
 */

#include <pwd.h>


/*
 * HTTP authorization types and levels...
 */

#define CUPSD_AUTH_DEFAULT	-1	/* Use DefaultAuthType */
#define CUPSD_AUTH_NONE		0	/* No authentication */
#define CUPSD_AUTH_BASIC	1	/* Basic authentication */
#define CUPSD_AUTH_DIGEST	2	/* Digest authentication */
#define CUPSD_AUTH_BASICDIGEST	3	/* Basic authentication w/passwd.md5 */
#define CUPSD_AUTH_NEGOTIATE	4	/* Kerberos authentication */
#define CUPSD_AUTH_AUTO		5	/* Kerberos or Basic, depending on configuration of server */

#define CUPSD_AUTH_ANON		0	/* Anonymous access */
#define CUPSD_AUTH_USER		1	/* Must have a valid username/password */
#define CUPSD_AUTH_GROUP	2	/* Must also be in a named group */

#define CUPSD_AUTH_ALLOW	0	/* Allow access */
#define CUPSD_AUTH_DENY		1	/* Deny access */

#define CUPSD_AUTH_NAME		0	/* Authorize host by name */
#define CUPSD_AUTH_IP		1	/* Authorize host by IP */
#define CUPSD_AUTH_INTERFACE	2	/* Authorize host by interface */

#define CUPSD_AUTH_SATISFY_ALL	0	/* Satisfy both address and auth */
#define CUPSD_AUTH_SATISFY_ANY	1	/* Satisfy either address or auth */

#define CUPSD_AUTH_LIMIT_DELETE	1	/* Limit DELETE requests */
#define CUPSD_AUTH_LIMIT_GET	2	/* Limit GET requests */
#define CUPSD_AUTH_LIMIT_HEAD	4	/* Limit HEAD requests */
#define CUPSD_AUTH_LIMIT_OPTIONS 8	/* Limit OPTIONS requests */
#define CUPSD_AUTH_LIMIT_POST	16	/* Limit POST requests */
#define CUPSD_AUTH_LIMIT_PUT	32	/* Limit PUT requests */
#define CUPSD_AUTH_LIMIT_TRACE	64	/* Limit TRACE requests */
#define CUPSD_AUTH_LIMIT_ALL	127	/* Limit all requests */
#define CUPSD_AUTH_LIMIT_IPP	128	/* Limit IPP requests */

#define IPP_ANY_OPERATION	(ipp_op_t)0
					/* Any IPP operation */
#define IPP_BAD_OPERATION	(ipp_op_t)-1
					/* No IPP operation */


/*
 * HTTP access control structures...
 */

typedef struct
{
  unsigned	address[4],		/* IP address */
		netmask[4];		/* IP netmask */
} cupsd_ipmask_t;

typedef struct
{
  int		length;			/* Length of name */
  char		*name;			/* Name string */
} cupsd_namemask_t;

typedef struct
{
  int		type;			/* Mask type */
  union
  {
    cupsd_namemask_t	name;		/* Host/Domain name */
    cupsd_ipmask_t	ip;		/* IP address/network */
  }		mask;			/* Mask data */
} cupsd_authmask_t;

typedef struct
{
  char			*location;	/* Location of resource */
  ipp_op_t		op;		/* IPP operation */
  int			limit,		/* Limit for these types of requests */
			length,		/* Length of location string */
			order_type,	/* Allow or Deny */
			type,		/* Type of authentication */
			level,		/* Access level required */
			satisfy;	/* Satisfy any or all limits? */
  cups_array_t		*names,		/* User or group names */
			*allow,		/* Allow lines */
			*deny;		/* Deny lines */
  http_encryption_t	encryption;	/* To encrypt or not to encrypt... */
} cupsd_location_t;

typedef struct cupsd_client_s cupsd_client_t;


/*
 * Globals...
 */

VAR cups_array_t	*Locations	VALUE(NULL);
					/* Authorization locations */
#ifdef HAVE_SSL
VAR http_encryption_t	DefaultEncryption VALUE(HTTP_ENCRYPT_REQUIRED);
					/* Default encryption for authentication */
#endif /* HAVE_SSL */


/*
 * Prototypes...
 */

extern int		cupsdAddIPMask(cups_array_t **masks,
				       const unsigned address[4],
				       const unsigned netmask[4]);
extern void		cupsdAddLocation(cupsd_location_t *loc);
extern void		cupsdAddName(cupsd_location_t *loc, char *name);
extern int		cupsdAddNameMask(cups_array_t **masks, char *name);
extern void		cupsdAuthorize(cupsd_client_t *con);
extern int		cupsdCheckAccess(unsigned ip[4], char *name,
			                 int namelen, cupsd_location_t *loc);
extern int		cupsdCheckAuth(unsigned ip[4], char *name, int namelen,
				       cups_array_t *masks);
extern int		cupsdCheckGroup(const char *username,
			                struct passwd *user,
			                const char *groupname);
extern cupsd_location_t	*cupsdCopyLocation(cupsd_location_t *loc);
extern void		cupsdDeleteAllLocations(void);
extern cupsd_location_t	*cupsdFindBest(const char *path, http_state_t state);
extern cupsd_location_t	*cupsdFindLocation(const char *location);
extern void		cupsdFreeLocation(cupsd_location_t *loc);
extern http_status_t	cupsdIsAuthorized(cupsd_client_t *con, const char *owner);
extern cupsd_location_t	*cupsdNewLocation(const char *location);


/*
 * End of "$Id: auth.h 10996 2013-05-29 11:51:34Z msweet $".
 */
