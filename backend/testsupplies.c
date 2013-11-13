/*
 * "$Id: testsupplies.c 3247 2011-05-12 06:22:31Z msweet $"
 *
 *   SNMP supplies test program for CUPS.
 *
 *   Copyright 2008-2011 by Apple Inc.
 *
 *   These coded instructions, statements, and computer programs are the
 *   property of Apple Inc. and are protected by Federal copyright
 *   law.  Distribution and use rights are outlined in the file "LICENSE.txt"
 *   "LICENSE" which should have been included with this file.  If this
 *   file is missing or damaged, see the license at "http://www.cups.org/".
 *
 *   This file is subject to the Apple OS-Developed Software exception.
 *
 * Contents:
 *
 *   main() - Show the supplies state of a printer.
 */

/*
 * Include necessary headers.
 */

#include "backend-private.h"


/*
 * 'main()' - Show the supplies state of a printer.
 */

int					/* O - Exit status */
main(int  argc,				/* I - Number of command-line args */
     char *argv[])			/* I - Command-line arguments */
{
  http_addrlist_t	*host;		/* Host addresses */
  int			snmp_fd;	/* SNMP socket */
  int			page_count,	/* Current page count */
			printer_state;	/* Current printer state */


  if (argc != 2)
  {
    puts("Usage: testsupplies ip-or-hostname");
    return (1);
  }

  if ((host = httpAddrGetList(argv[1], AF_UNSPEC, "9100")) == NULL)
  {
    perror(argv[1]);
    return (1);
  }

  if ((snmp_fd = _cupsSNMPOpen(host->addr.addr.sa_family)) < 0)
  {
    perror(argv[1]);
    return (1);
  }

  for (;;)
  {
    fputs("backendSNMPSupplies: ", stdout);

    if (backendSNMPSupplies(snmp_fd, &(host->addr), &page_count,
                            &printer_state))
    {
      puts("FAIL");
      return (1);
    }

    printf("backendSNMPSupplies: %s (page_count=%d, printer_state=%d)\n",
	   page_count < 0 || printer_state < CUPS_TC_other ||
	       printer_state > CUPS_TC_warmup ? "FAIL" : "PASS",
	   page_count, printer_state);

    sleep(5);
  }
}


/*
 * End of "$Id: testsupplies.c 3247 2011-05-12 06:22:31Z msweet $".
 */
