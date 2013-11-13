/*
 * "$Id: lppasswd.c 10996 2013-05-29 11:51:34Z msweet $"
 *
 *   MD5 password program for CUPS.
 *
 *   Copyright 2007-2011 by Apple Inc.
 *   Copyright 1997-2006 by Easy Software Products.
 *
 *   These coded instructions, statements, and computer programs are the
 *   property of Apple Inc. and are protected by Federal copyright
 *   law.  Distribution and use rights are outlined in the file "LICENSE.txt"
 *   which should have been included with this file.  If this file is
 *   file is missing or damaged, see the license at "http://www.cups.org/".
 *
 * Contents:
 *
 *   main()  - Add, change, or delete passwords from the MD5 password file.
 *   usage() - Show program usage.
 */

/*
 * Include necessary headers...
 */

#include <cups/cups-private.h>
#include <cups/md5-private.h>
#include <fcntl.h>
#include <grp.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifndef WIN32
#  include <unistd.h>
#  include <signal.h>
#endif /* !WIN32 */


/*
 * Operations...
 */

#define ADD	0
#define CHANGE	1
#define DELETE	2


/*
 * Local functions...
 */

static void	usage(FILE *fp) __attribute__((noreturn));


/*
 * 'main()' - Add, change, or delete passwords from the MD5 password file.
 */

int					/* O - Exit status */
main(int  argc,				/* I - Number of command-line arguments */
     char *argv[])			/* I - Command-line arguments */
{
  int		i;			/* Looping var */
  char		*opt;			/* Option pointer */
  const char	*username;		/* Pointer to username */
  const char	*groupname;		/* Pointer to group name */
  int		op;			/* Operation (add, change, delete) */
  const char	*passwd;		/* Password string */
  FILE		*infile,		/* Input file */
		*outfile;		/* Output file */
  char		line[256],		/* Line from file */
		userline[17],		/* User from line */
		groupline[17],		/* Group from line */
		md5line[33],		/* MD5-sum from line */
		md5new[33];		/* New MD5 sum */
  char		passwdmd5[1024],	/* passwd.md5 file */
		passwdold[1024],	/* passwd.old file */
		passwdnew[1024];	/* passwd.tmp file */
  char		*newpass,		/* new password */
  		*oldpass;		/* old password */
  int		flag;			/* Password check flags... */
  int		fd;			/* Password file descriptor */
  int		error;			/* Write error */
  _cups_globals_t *cg = _cupsGlobals();	/* Global data */
  cups_lang_t	*lang;			/* Language info */
#if defined(HAVE_SIGACTION) && !defined(HAVE_SIGSET)
  struct sigaction action;		/* Signal action */
#endif /* HAVE_SIGACTION && !HAVE_SIGSET*/


  _cupsSetLocale(argv);
  lang = cupsLangDefault();

 /*
  * Check to see if stdin, stdout, and stderr are still open...
  */

  if (fcntl(0, F_GETFD, &i) ||
      fcntl(1, F_GETFD, &i) ||
      fcntl(2, F_GETFD, &i))
  {
   /*
    * No, return exit status 2 and don't try to send any output since
    * someone is trying to bypass the security on the server.
    */

    return (2);
  }

 /*
  * Find the server directory...
  */

  snprintf(passwdmd5, sizeof(passwdmd5), "%s/passwd.md5", cg->cups_serverroot);
  snprintf(passwdold, sizeof(passwdold), "%s/passwd.old", cg->cups_serverroot);
  snprintf(passwdnew, sizeof(passwdnew), "%s/passwd.new", cg->cups_serverroot);

 /*
  * Find the default system group...
  */

  if (getgrnam(CUPS_DEFAULT_GROUP))
    groupname = CUPS_DEFAULT_GROUP;
  else
    groupname = "unknown";

  endgrent();

  username = NULL;
  op       = CHANGE;

 /*
  * Parse command-line options...
  */

  for (i = 1; i < argc; i ++)
    if (argv[i][0] == '-')
      for (opt = argv[i] + 1; *opt; opt ++)
        switch (*opt)
	{
	  case 'a' : /* Add */
	      op = ADD;
	      break;
	  case 'x' : /* Delete */
	      op = DELETE;
	      break;
	  case 'g' : /* Group */
	      i ++;
	      if (i >= argc)
	        usage(stderr);

              groupname = argv[i];
	      break;
	  case 'h' : /* Help */
	      usage(stdout);
	      break;
	  default : /* Bad option */
	      usage(stderr);
	      break;
	}
    else if (!username)
      username = argv[i];
    else
      usage(stderr);

 /*
  * See if we are trying to add or delete a password when we aren't logged in
  * as root...
  */

  if (getuid() && getuid() != geteuid() && (op != CHANGE || username))
  {
    _cupsLangPuts(stderr,
                  _("lppasswd: Only root can add or delete passwords."));
    return (1);
  }

 /*
  * Fill in missing info...
  */

  if (!username)
    username = cupsUser();

  oldpass = newpass = NULL;

 /*
  * Obtain old and new password _before_ locking the database
  * to keep users from locking the file indefinitely.
  */

  if (op == CHANGE && getuid())
  {
    if ((passwd = cupsGetPassword(_("Enter old password:"))) == NULL)
      return (1);

    if ((oldpass = strdup(passwd)) == NULL)
    {
      _cupsLangPrintf(stderr,
                      _("lppasswd: Unable to copy password string: %s"),
		      strerror(errno));
      return (1);
    }
  }

 /*
  * Now get the new password, if necessary...
  */

  if (op != DELETE)
  {
    if ((passwd = cupsGetPassword(
            _cupsLangString(lang, _("Enter password:")))) == NULL)
      return (1);

    if ((newpass = strdup(passwd)) == NULL)
    {
      _cupsLangPrintf(stderr,
                      _("lppasswd: Unable to copy password string: %s"),
		      strerror(errno));
      return (1);
    }

    if ((passwd = cupsGetPassword(
            _cupsLangString(lang, _("Enter password again:")))) == NULL)
      return (1);

    if (strcmp(passwd, newpass) != 0)
    {
      _cupsLangPuts(stderr,
                    _("lppasswd: Sorry, passwords don't match."));
      return (1);
    }

   /*
    * Check that the password contains at least one letter and number.
    */

    flag = 0;

    for (passwd = newpass; *passwd; passwd ++)
      if (isdigit(*passwd & 255))
	flag |= 1;
      else if (isalpha(*passwd & 255))
	flag |= 2;

   /*
    * Only allow passwords that are at least 6 chars, have a letter and
    * a number, and don't contain the username.
    */

    if (strlen(newpass) < 6 || strstr(newpass, username) != NULL || flag != 3)
    {
      _cupsLangPuts(stderr, _("lppasswd: Sorry, password rejected."));
      _cupsLangPuts(stderr, _("Your password must be at least 6 characters "
                              "long, cannot contain your username, and must "
			      "contain at least one letter and number."));
      return (1);
    }
  }

 /*
  * Ignore SIGHUP, SIGINT, SIGTERM, and SIGXFSZ (if defined) for the
  * remainder of the time so that we won't end up with bogus password
  * files...
  */

#ifndef WIN32
#  if defined(HAVE_SIGSET)
  sigset(SIGHUP, SIG_IGN);
  sigset(SIGINT, SIG_IGN);
  sigset(SIGTERM, SIG_IGN);
#    ifdef SIGXFSZ
  sigset(SIGXFSZ, SIG_IGN);
#    endif /* SIGXFSZ */
#  elif defined(HAVE_SIGACTION)
  memset(&action, 0, sizeof(action));
  action.sa_handler = SIG_IGN;

  sigaction(SIGHUP, &action, NULL);
  sigaction(SIGINT, &action, NULL);
  sigaction(SIGTERM, &action, NULL);
#    ifdef SIGXFSZ
  sigaction(SIGXFSZ, &action, NULL);
#    endif /* SIGXFSZ */
#  else
  signal(SIGHUP, SIG_IGN);
  signal(SIGINT, SIG_IGN);
  signal(SIGTERM, SIG_IGN);
#    ifdef SIGXFSZ
  signal(SIGXFSZ, SIG_IGN);
#    endif /* SIGXFSZ */
#  endif
#endif /* !WIN32 */

 /*
  * Open the output file.
  */

  if ((fd = open(passwdnew, O_WRONLY | O_CREAT | O_EXCL, 0400)) < 0)
  {
    if (errno == EEXIST)
      _cupsLangPuts(stderr, _("lppasswd: Password file busy."));
    else
      _cupsLangPrintf(stderr, _("lppasswd: Unable to open password file: %s"),
		      strerror(errno));

    return (1);
  }

  if ((outfile = fdopen(fd, "w")) == NULL)
  {
    _cupsLangPrintf(stderr, _("lppasswd: Unable to open password file: %s"),
		    strerror(errno));

    unlink(passwdnew);

    return (1);
  }

  setbuf(outfile, NULL);

 /*
  * Open the existing password file and create a new one...
  */

  infile = fopen(passwdmd5, "r");
  if (infile == NULL && errno != ENOENT && op != ADD)
  {
    _cupsLangPrintf(stderr, _("lppasswd: Unable to open password file: %s"),
		    strerror(errno));

    fclose(outfile);

    unlink(passwdnew);

    return (1);
  }

 /*
  * Read lines from the password file; the format is:
  *
  *   username:group:MD5-sum
  */

  error        = 0;
  userline[0]  = '\0';
  groupline[0] = '\0';
  md5line[0]   = '\0';

  if (infile)
  {
    while (fgets(line, sizeof(line), infile) != NULL)
    {
      if (sscanf(line, "%16[^:]:%16[^:]:%32s", userline, groupline, md5line) != 3)
        continue;

      if (strcmp(username, userline) == 0 &&
          strcmp(groupname, groupline) == 0)
	break;

      if (fputs(line, outfile) == EOF)
      {
	_cupsLangPrintf(stderr,
	                _("lppasswd: Unable to write to password file: %s"),
			strerror(errno));
        error = 1;
	break;
      }
    }

    if (!error)
    {
      while (fgets(line, sizeof(line), infile) != NULL)
	if (fputs(line, outfile) == EOF)
	{
	  _cupsLangPrintf(stderr,
                	  _("lppasswd: Unable to write to password file: %s"),
			  strerror(errno));
	  error = 1;
	  break;
	}
    }
  }

  if (op == CHANGE &&
      (strcmp(username, userline) || strcmp(groupname, groupline)))
  {
    _cupsLangPrintf(stderr,
                    _("lppasswd: user \"%s\" and group \"%s\" do not exist."),
        	    username, groupname);
    error = 1;
  }
  else if (op != DELETE)
  {
    if (oldpass &&
        strcmp(httpMD5(username, "CUPS", oldpass, md5new), md5line) != 0)
    {
      _cupsLangPuts(stderr, _("lppasswd: Sorry, password doesn't match."));
      error = 1;
    }
    else
    {
      snprintf(line, sizeof(line), "%s:%s:%s\n", username, groupname,
               httpMD5(username, "CUPS", newpass, md5new));
      if (fputs(line, outfile) == EOF)
      {
	_cupsLangPrintf(stderr,
                	_("lppasswd: Unable to write to password file: %s"),
			strerror(errno));
        error = 1;
      }
    }
  }

 /*
  * Close the files...
  */

  if (infile)
    fclose(infile);

  if (fclose(outfile) == EOF)
    error = 1;

 /*
  * Error out gracefully as needed...
  */

  if (error)
  {
    _cupsLangPuts(stderr, _("lppasswd: Password file not updated."));

    unlink(passwdnew);

    return (1);
  }

 /*
  * Save old passwd file
  */

  unlink(passwdold);
  if (link(passwdmd5, passwdold) && errno != ENOENT)
  {
    _cupsLangPrintf(stderr,
                    _("lppasswd: failed to backup old password file: %s"),
		    strerror(errno));
    unlink(passwdnew);
    return (1);
  }

 /*
  * Install new password file
  */

  if (rename(passwdnew, passwdmd5) < 0)
  {
    _cupsLangPrintf(stderr, _("lppasswd: failed to rename password file: %s"),
		    strerror(errno));
    unlink(passwdnew);
    return (1);
  }

  return (0);
}


/*
 * 'usage()' - Show program usage.
 */

static void
usage(FILE *fp)		/* I - File to send usage to */
{
  if (getuid())
    _cupsLangPuts(fp, _("Usage: lppasswd [-g groupname]"));
  else
    _cupsLangPuts(fp,
                  _("Usage: lppasswd [-g groupname] [username]\n"
		    "       lppasswd [-g groupname] -a [username]\n"
		    "       lppasswd [-g groupname] -x [username]"));

  exit(1);
}


/*
 * End of "$Id: lppasswd.c 10996 2013-05-29 11:51:34Z msweet $".
 */
