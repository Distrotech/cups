/*
 * "$Id: cupsaccept.c 2873 2010-11-30 03:16:24Z msweet $"
 *
 *   "cupsaccept", "cupsdisable", "cupsenable", and "cupsreject" commands for
 *   CUPS.
 *
 *   Copyright 2007-2010 by Apple Inc.
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
 *   main() - Parse options and accept/reject jobs or disable/enable printers.
 */

/*
 * Include necessary headers...
 */

#include <cups/cups-private.h>


/*
 * 'main()' - Parse options and accept/reject jobs or disable/enable printers.
 */

int					/* O - Exit status */
main(int  argc,				/* I - Number of command-line arguments */
     char *argv[])			/* I - Command-line arguments */
{
  int		i;			/* Looping var */
  char		*command,		/* Command to do */
		uri[1024],		/* Printer URI */
		*reason;		/* Reason for reject/disable */
  ipp_t		*request;		/* IPP request */
  ipp_op_t	op;			/* Operation */
  int		cancel;			/* Cancel jobs? */


  _cupsSetLocale(argv);

 /*
  * See what operation we're supposed to do...
  */

  if ((command = strrchr(argv[0], '/')) != NULL)
    command ++;
  else
    command = argv[0];

  cancel = 0;

  if (!strcmp(command, "cupsaccept") || !strcmp(command, "accept"))
    op = CUPS_ACCEPT_JOBS;
  else if (!strcmp(command, "cupsreject") || !strcmp(command, "reject"))
    op = CUPS_REJECT_JOBS;
  else if (!strcmp(command, "cupsdisable") || !strcmp(command, "disable"))
    op = IPP_PAUSE_PRINTER;
  else if (!strcmp(command, "cupsenable") || !strcmp(command, "enable"))
    op = IPP_RESUME_PRINTER;
  else
  {
    _cupsLangPrintf(stderr, _("%s: Don't know what to do."), command);
    return (1);
  }

  reason = NULL;

 /*
  * Process command-line arguments...
  */

  for (i = 1; i < argc; i ++)
    if (argv[i][0] == '-')
    {
      switch (argv[i][1])
      {
        case 'E' : /* Encrypt */
#ifdef HAVE_SSL
	    cupsSetEncryption(HTTP_ENCRYPT_REQUIRED);
#else
            _cupsLangPrintf(stderr,
	                    _("%s: Sorry, no encryption support."), command);
#endif /* HAVE_SSL */
	    break;

        case 'U' : /* Username */
	    if (argv[i][2] != '\0')
	      cupsSetUser(argv[i] + 2);
	    else
	    {
	      i ++;
	      if (i >= argc)
	      {
	        _cupsLangPrintf(stderr,
		                _("%s: Error - expected username after "
				  "\"-U\" option."), command);
	        return (1);
	      }

              cupsSetUser(argv[i]);
	    }
	    break;
	    
        case 'c' : /* Cancel jobs */
	    cancel = 1;
	    break;

        case 'h' : /* Connect to host */
	    if (argv[i][2] != '\0')
	      cupsSetServer(argv[i] + 2);
	    else
	    {
	      i ++;
	      if (i >= argc)
	      {
	        _cupsLangPrintf(stderr,
		                _("%s: Error - expected hostname after "
				  "\"-h\" option."), command);
	        return (1);
	      }

              cupsSetServer(argv[i]);
	    }
	    break;

        case 'r' : /* Reason for cancellation */
	    if (argv[i][2] != '\0')
	      reason = argv[i] + 2;
	    else
	    {
	      i ++;
	      if (i >= argc)
	      {
	        _cupsLangPrintf(stderr,
		                _("%s: Error - expected reason text after "
				  "\"-r\" option."), command);
		return (1);
	      }

	      reason = argv[i];
	    }
	    break;

        case '-' :
	    if (!strcmp(argv[i], "--hold"))
	      op = IPP_HOLD_NEW_JOBS;
	    else if (!strcmp(argv[i], "--release"))
	      op = IPP_RELEASE_HELD_NEW_JOBS;
	    else
	    {
	      _cupsLangPrintf(stderr, _("%s: Error - unknown option \"%s\"."),
			      command, argv[i]);
	      return (1);
	    }
	    break;

	default :
	    _cupsLangPrintf(stderr, _("%s: Error - unknown option \"%c\"."),
	                    command, argv[i][1]);
	    return (1);
      }
    }
    else
    {
     /*
      * Accept/disable/enable/reject a destination...
      */

      request = ippNewRequest(op);

      httpAssembleURIf(HTTP_URI_CODING_ALL, uri, sizeof(uri), "ipp", NULL,
                       "localhost", 0, "/printers/%s", argv[i]);
      ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
                   "printer-uri", NULL, uri);

      ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME,
                   "requesting-user-name", NULL, cupsUser());

      if (reason != NULL)
	ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_TEXT,
                     "printer-state-message", NULL, reason);

     /*
      * Do the request and get back a response...
      */

      ippDelete(cupsDoRequest(CUPS_HTTP_DEFAULT, request, "/admin/"));

      if (cupsLastError() > IPP_OK_CONFLICT)
      {
	_cupsLangPrintf(stderr,
			_("%s: Operation failed: %s"),
			command, ippErrorString(cupsLastError()));
	return (1);
      }

     /*
      * Cancel all jobs if requested...
      */

      if (cancel)
      {
       /*
	* Build an IPP_PURGE_JOBS request, which requires the following
	* attributes:
	*
	*    attributes-charset
	*    attributes-natural-language
	*    printer-uri
	*/

	request = ippNewRequest(IPP_PURGE_JOBS);

	ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
                     "printer-uri", NULL, uri);

	ippDelete(cupsDoRequest(CUPS_HTTP_DEFAULT, request, "/admin/"));

        if (cupsLastError() > IPP_OK_CONFLICT)
	{
	  _cupsLangPrintf(stderr, "%s: %s", command, cupsLastErrorString());
	  return (1);
	}
      }
    }

  return (0);
}


/*
 * End of "$Id: cupsaccept.c 2873 2010-11-30 03:16:24Z msweet $".
 */
