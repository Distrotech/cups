#!/bin/sh
#
# "$Id: run-stp-tests.sh 9034 2010-03-09 07:03:06Z mike $"
#
#   Perform the complete set of IPP compliance tests specified in the
#   CUPS Software Test Plan.
#
#   Copyright 2007-2013 by Apple Inc.
#   Copyright 1997-2007 by Easy Software Products, all rights reserved.
#
#   These coded instructions, statements, and computer programs are the
#   property of Apple Inc. and are protected by Federal copyright
#   law.  Distribution and use rights are outlined in the file "LICENSE.txt"
#   which should have been included with this file.  If this file is
#   file is missing or damaged, see the license at "http://www.cups.org/".
#

argcount=$#

#
# Don't allow "make check" or "make test" to be run by root...
#

if test "x`id -u`" = x0; then
	echo Please run this as a normal user. Not supported when run as root.
	exit 1
fi

#
# Force the permissions of the files we create...
#

umask 022

#
# Make the IPP test program...
#

make

#
# Solaris has a non-POSIX grep in /bin...
#

if test -x /usr/xpg4/bin/grep; then
	GREP=/usr/xpg4/bin/grep
else
	GREP=grep
fi

#
# Figure out the proper echo options...
#

if (echo "testing\c"; echo 1,2,3) | $GREP c >/dev/null; then
        ac_n=-n
        ac_c=
else
        ac_n=
        ac_c='\c'
fi

#
# Greet the tester...
#

echo "Welcome to the CUPS Automated Test Script."
echo ""
echo "Before we begin, it is important that you understand that the larger"
echo "tests require significant amounts of RAM and disk space.  If you"
echo "attempt to run one of the big tests on a system that lacks sufficient"
echo "disk and virtual memory, the UNIX kernel might decide to kill one or"
echo "more system processes that you've grown attached to, like the X"
echo "server.  The question you may want to ask yourself before running a"
echo "large test is: Do you feel lucky?"
echo ""
echo "OK, now that we have the Dirty Harry quote out of the way, please"
echo "choose the type of test you wish to perform:"
echo ""
echo "0 - No testing, keep the scheduler running for me (all systems)"
echo "1 - Basic conformance test, no load testing (all systems)"
echo "2 - Basic conformance test, some load testing (minimum 256MB VM, 50MB disk)"
echo "3 - Basic conformance test, extreme load testing (minimum 1GB VM, 500MB disk)"
echo "4 - Basic conformance test, torture load testing (minimum 2GB VM, 1GB disk)"
echo ""
echo $ac_n "Enter the number of the test you wish to perform: [1] $ac_c"

if test $# -gt 0; then
	testtype=$1
	shift
else
	read testtype
fi
echo ""

case "$testtype" in
	0)
		echo "Running in test mode (0)"
		nprinters1=0
		nprinters2=0
		pjobs=0
		pprinters=0
		loglevel="debug2"
		;;
	2)
		echo "Running the medium tests (2)"
		nprinters1=10
		nprinters2=20
		pjobs=20
		pprinters=10
		loglevel="debug"
		;;
	3)
		echo "Running the extreme tests (3)"
		nprinters1=500
		nprinters2=1000
		pjobs=100
		pprinters=50
		loglevel="debug"
		;;
	4)
		echo "Running the torture tests (4)"
		nprinters1=10000
		nprinters2=20000
		pjobs=200
		pprinters=100
		loglevel="debug"
		;;
	*)
		echo "Running the timid tests (1)"
		nprinters1=0
		nprinters2=0
		pjobs=10
		pprinters=0
		loglevel="debug2"
		;;
esac

#
# See if we want to do SSL testing...
#

echo ""
echo "Now you can choose whether to create a SSL/TLS encryption key and"
echo "certificate for testing; these tests currently require the OpenSSL"
echo "tools:"
echo ""
echo "0 - Do not do SSL/TLS encryption tests"
echo "1 - Test but do not require encryption"
echo "2 - Test and require encryption"
echo ""
echo $ac_n "Enter the number of the SSL/TLS tests to perform: [0] $ac_c"

if test $# -gt 0; then
	ssltype=$1
	shift
else
	read ssltype
fi
echo ""

case "$ssltype" in
	1)
		echo "Will test but not require encryption (1)"
		;;
	2)
		echo "Will test and require encryption (2)"
		;;
	*)
		echo "Not using SSL/TLS (0)"
		ssltype=0
		;;
esac

#
# Information for the server/tests...
#

user="$USER"
if test -z "$user"; then
	if test -x /usr/ucb/whoami; then
		user=`/usr/ucb/whoami`
	else
		user=`whoami`
	fi

	if test -z "$user"; then
		user="unknown"
	fi
fi

port=8631
cwd=`pwd`
root=`dirname $cwd`

#
# Make sure that the LPDEST and PRINTER environment variables are
# not included in the environment that is passed to the tests.  These
# will usually cause tests to fail erroneously...
#

unset LPDEST
unset PRINTER

#
# See if we want to use valgrind...
#

echo ""
echo "This test script can use the Valgrind software from:"
echo ""
echo "    http://developer.kde.org/~sewardj/"
echo ""
echo $ac_n "Enter Y to use Valgrind or N to not use Valgrind: [N] $ac_c"

if test $# -gt 0; then
	usevalgrind=$1
	shift
else
	read usevalgrind
fi
echo ""

case "$usevalgrind" in
	Y* | y*)
		VALGRIND="valgrind --tool=memcheck --log-file=/tmp/cups-$user/log/valgrind.%p --error-limit=no --leak-check=yes --trace-children=yes --read-var-info=yes"
		if test `uname` = Darwin; then
			VALGRIND="$VALGRIND --dsymutil=yes"
		fi
		export VALGRIND
		echo "Using Valgrind; log files can be found in /tmp/cups-$user/log..."
		;;

	*)
		VALGRIND=""
		export VALGRIND
		;;
esac

#
# See if we want to do debug logging of the libraries...
#

echo ""
echo "If CUPS was built with the --enable-debug-printfs configure option, you"
echo "can enable debug logging of the libraries."
echo ""
echo $ac_n "Enter Y or a number from 0 to 9 to enable debug logging or N to not: [N] $ac_c"

if test $# -gt 0; then
	usedebugprintfs=$1
	shift
else
	read usedebugprintfs
fi
echo ""

case "$usedebugprintfs" in
	Y* | y*)
		echo "Enabling debug printfs (level 5); log files can be found in /tmp/cups-$user/log..."
		CUPS_DEBUG_LOG="/tmp/cups-$user/log/debug_printfs.%d"; export CUPS_DEBUG_LOG
		CUPS_DEBUG_LEVEL=5; export CUPS_DEBUG_LEVEL
		CUPS_DEBUG_FILTER='^(http|_http|ipp|_ipp|cups.*Request|cupsGetResponse|cupsSend).*$'; export CUPS_DEBUG_FILTER
		;;

	0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
		echo "Enabling debug printfs (level $usedebugprintfs); log files can be found in /tmp/cups-$user/log..."
		CUPS_DEBUG_LOG="/tmp/cups-$user/log/debug_printfs.%d"; export CUPS_DEBUG_LOG
		CUPS_DEBUG_LEVEL="$usedebugprintfs"; export CUPS_DEBUG_LEVEL
		CUPS_DEBUG_FILTER='^(http|_http|ipp|_ipp|cups.*Request|cupsGetResponse|cupsSend).*$'; export CUPS_DEBUG_FILTER
		;;

	*)
		;;
esac

#
# Start by creating temporary directories for the tests...
#

echo "Creating directories for test..."

rm -rf /tmp/cups-$user
mkdir /tmp/cups-$user
mkdir /tmp/cups-$user/bin
mkdir /tmp/cups-$user/bin/backend
mkdir /tmp/cups-$user/bin/driver
mkdir /tmp/cups-$user/bin/filter
mkdir /tmp/cups-$user/certs
mkdir /tmp/cups-$user/share
mkdir /tmp/cups-$user/share/banners
mkdir /tmp/cups-$user/share/drv
mkdir /tmp/cups-$user/share/locale
for file in ../locale/cups_*.po; do
	loc=`basename $file .po | cut -c 6-`
	mkdir /tmp/cups-$user/share/locale/$loc
	ln -s $root/locale/cups_$loc.po /tmp/cups-$user/share/locale/$loc
	ln -s $root/locale/ppdc_$loc.po /tmp/cups-$user/share/locale/$loc
done
mkdir /tmp/cups-$user/share/mime
mkdir /tmp/cups-$user/share/model
mkdir /tmp/cups-$user/share/ppdc
mkdir /tmp/cups-$user/interfaces
mkdir /tmp/cups-$user/log
mkdir /tmp/cups-$user/ppd
mkdir /tmp/cups-$user/spool
mkdir /tmp/cups-$user/spool/temp
mkdir /tmp/cups-$user/ssl

ln -s $root/backend/dnssd /tmp/cups-$user/bin/backend
ln -s $root/backend/http /tmp/cups-$user/bin/backend
ln -s $root/backend/ipp /tmp/cups-$user/bin/backend
ln -s $root/backend/lpd /tmp/cups-$user/bin/backend
ln -s $root/backend/mdns /tmp/cups-$user/bin/backend
ln -s $root/backend/pseudo /tmp/cups-$user/bin/backend
ln -s $root/backend/snmp /tmp/cups-$user/bin/backend
ln -s $root/backend/socket /tmp/cups-$user/bin/backend
ln -s $root/backend/usb /tmp/cups-$user/bin/backend
ln -s $root/cgi-bin /tmp/cups-$user/bin
ln -s $root/monitor /tmp/cups-$user/bin
ln -s $root/notifier /tmp/cups-$user/bin
ln -s $root/scheduler /tmp/cups-$user/bin/daemon
ln -s $root/filter/commandtops /tmp/cups-$user/bin/filter
ln -s $root/filter/gziptoany /tmp/cups-$user/bin/filter
ln -s $root/filter/pstops /tmp/cups-$user/bin/filter
ln -s $root/filter/rastertoepson /tmp/cups-$user/bin/filter
ln -s $root/filter/rastertohp /tmp/cups-$user/bin/filter
ln -s $root/filter/rastertolabel /tmp/cups-$user/bin/filter
ln -s $root/filter/rastertopwg /tmp/cups-$user/bin/filter

ln -s $root/data/classified /tmp/cups-$user/share/banners
ln -s $root/data/confidential /tmp/cups-$user/share/banners
ln -s $root/data/secret /tmp/cups-$user/share/banners
ln -s $root/data/standard /tmp/cups-$user/share/banners
ln -s $root/data/topsecret /tmp/cups-$user/share/banners
ln -s $root/data/unclassified /tmp/cups-$user/share/banners
ln -s $root/data /tmp/cups-$user/share
ln -s $root/ppdc/sample.drv /tmp/cups-$user/share/drv
ln -s $root/conf/mime.types /tmp/cups-$user/share/mime
ln -s $root/conf/mime.convs /tmp/cups-$user/share/mime
ln -s $root/data/*.h /tmp/cups-$user/share/ppdc
ln -s $root/data/*.defs /tmp/cups-$user/share/ppdc
ln -s $root/templates /tmp/cups-$user/share

#
# Local filters and configuration files...
#

if test `uname` = Darwin; then
	ln -s /usr/libexec/cups/filter/cgpdfto* /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/cgbannertopdf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/cgimagetopdf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/cgtexttopdf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/nsimagetopdf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/nstexttopdf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/pictwpstops /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/pstoappleps /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/pstocupsraster /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/pstopdffilter /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/rastertourf /tmp/cups-$user/bin/filter
	ln -s /usr/libexec/cups/filter/xhtmltopdf /tmp/cups-$user/bin/filter

	if test -f /private/etc/cups/apple.types; then
		ln -s /private/etc/cups/apple.* /tmp/cups-$user/share/mime
	elif test -f /usr/share/cups/mime/apple.types; then
		ln -s /usr/share/cups/mime/apple.* /tmp/cups-$user/share/mime
	fi
else
	ln -s /usr/lib/cups/filter/bannertops /tmp/cups-$user/bin/filter
	ln -s /usr/lib/cups/filter/imagetops /tmp/cups-$user/bin/filter
	ln -s /usr/lib/cups/filter/imagetoraster /tmp/cups-$user/bin/filter
	ln -s /usr/lib/cups/filter/pdftops /tmp/cups-$user/bin/filter
	ln -s /usr/lib/cups/filter/texttops /tmp/cups-$user/bin/filter

	ln -s /usr/share/cups/mime/legacy.convs /tmp/cups-$user/share/mime
	ln -s /usr/share/cups/charsets /tmp/cups-$user/share
	if test -f $root/data/psglyphs; then
		ln -s /usr/share/cups/data/psglyphs $root/data
	fi
	ln -s /usr/share/cups/fonts /tmp/cups-$user/share
fi

#
# Then create the necessary config files...
#

echo "Creating cupsd.conf for test..."

if test $ssltype = 2; then
	encryption="Encryption Required"
else
	encryption=""
fi

cat >/tmp/cups-$user/cupsd.conf <<EOF
StrictConformance Yes
Browsing Off
Listen localhost:$port
Listen /tmp/cups-$user/sock
PassEnv LOCALEDIR
PassEnv DYLD_INSERT_LIBRARIES
MaxSubscriptions 3
MaxLogSize 0
AccessLogLevel actions
LogLevel $loglevel
LogTimeFormat usecs
PreserveJobHistory Yes
PreserveJobFiles No
<Policy default>
<Limit All>
Order Allow,Deny
$encryption
</Limit>
</Policy>
EOF

cat >/tmp/cups-$user/cups-files.conf <<EOF
FileDevice yes
Printcap
User $user
ServerRoot /tmp/cups-$user
StateDir /tmp/cups-$user
ServerBin /tmp/cups-$user/bin
CacheDir /tmp/cups-$user/share
DataDir /tmp/cups-$user/share
FontPath /tmp/cups-$user/share/fonts
DocumentRoot $root/doc
RequestRoot /tmp/cups-$user/spool
TempDir /tmp/cups-$user/spool/temp
AccessLog /tmp/cups-$user/log/access_log
ErrorLog /tmp/cups-$user/log/error_log
PageLog /tmp/cups-$user/log/page_log
EOF

if test $ssltype != 0 -a `uname` = Darwin; then
	echo "ServerCertificate $HOME/Library/Keychains/login.keychain" >> /tmp/cups-$user/cups-files.conf
fi

#
# Setup lots of test queues - half with PPD files, half without...
#

echo "Creating printers.conf for test..."

i=1
while test $i -le $nprinters1; do
	cat >>/tmp/cups-$user/printers.conf <<EOF
<Printer test-$i>
Accepting Yes
DeviceURI file:/dev/null
Info Test PS printer $i
JobSheets none none
Location CUPS test suite
State Idle
StateMessage Printer $1 is idle.
</Printer>
EOF

	cp testps.ppd /tmp/cups-$user/ppd/test-$i.ppd

	i=`expr $i + 1`
done

while test $i -le $nprinters2; do
	cat >>/tmp/cups-$user/printers.conf <<EOF
<Printer test-$i>
Accepting Yes
DeviceURI file:/dev/null
Info Test raw printer $i
JobSheets none none
Location CUPS test suite
State Idle
StateMessage Printer $1 is idle.
</Printer>
EOF

	i=`expr $i + 1`
done

if test -f /tmp/cups-$user/printers.conf; then
	cp /tmp/cups-$user/printers.conf /tmp/cups-$user/printers.conf.orig
else
	touch /tmp/cups-$user/printers.conf.orig
fi

#
# Setup the paths...
#

echo "Setting up environment variables for test..."

if test "x$LD_LIBRARY_PATH" = x; then
	LD_LIBRARY_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc"
else
	LD_LIBRARY_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc:$LD_LIBRARY_PATH"
fi

export LD_LIBRARY_PATH

LD_PRELOAD="$root/cups/libcups.so.2:$root/filter/libcupsimage.so.2:$root/cgi-bin/libcupscgi.so.1:$root/scheduler/libcupsmime.so.1:$root/ppdc/libcupsppdc.so.1"
if test `uname` = SunOS -a -r /usr/lib/libCrun.so.1; then
	LD_PRELOAD="/usr/lib/libCrun.so.1:$LD_PRELOAD"
fi
export LD_PRELOAD

if test "x$DYLD_LIBRARY_PATH" = x; then
	DYLD_LIBRARY_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc"
else
	DYLD_LIBRARY_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc:$DYLD_LIBRARY_PATH"
fi

export DYLD_LIBRARY_PATH

if test "x$SHLIB_PATH" = x; then
	SHLIB_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc"
else
	SHLIB_PATH="$root/cups:$root/filter:$root/cgi-bin:$root/scheduler:$root/ppdc:$SHLIB_PATH"
fi

export SHLIB_PATH

CUPS_DISABLE_APPLE_DEFAULT=yes; export CUPS_DISABLE_APPLE_DEFAULT
CUPS_SERVER=localhost:8631; export CUPS_SERVER
CUPS_SERVERROOT=/tmp/cups-$user; export CUPS_SERVERROOT
CUPS_STATEDIR=/tmp/cups-$user; export CUPS_STATEDIR
CUPS_DATADIR=/tmp/cups-$user/share; export CUPS_DATADIR
LOCALEDIR=/tmp/cups-$user/share/locale; export LOCALEDIR

#
# Set a new home directory to avoid getting user options mixed in...
#

HOME=/tmp/cups-$user
export HOME

#
# Force POSIX locale for tests...
#

LANG=C
export LANG

LC_MESSAGES=C
export LC_MESSAGES

#
# Start the server; run as foreground daemon in the background...
#

echo "Starting scheduler:"
echo "    $VALGRIND ../scheduler/cupsd -c /tmp/cups-$user/cupsd.conf -f >/tmp/cups-$user/log/debug_log 2>&1 &"
echo ""

if test `uname` = Darwin -a "x$VALGRIND" = x; then
	DYLD_INSERT_LIBRARIES=/usr/lib/libgmalloc.dylib
	../scheduler/cupsd -c /tmp/cups-$user/cupsd.conf -f >/tmp/cups-$user/log/debug_log 2>&1 &
else
	$VALGRIND ../scheduler/cupsd -c /tmp/cups-$user/cupsd.conf -f >/tmp/cups-$user/log/debug_log 2>&1 &
fi

cupsd=$!

if test "x$testtype" = x0; then
	# Not running tests...
	echo "Scheduler is PID $cupsd and is listening on port 8631."
	echo ""

	# Create a helper script to run programs with...
	runcups="/tmp/cups-$user/runcups"

	echo "#!/bin/sh" >$runcups
	echo "# Helper script for running CUPS test instance." >>$runcups
	echo "" >>$runcups
	echo "# Set required environment variables..." >>$runcups
	echo "CUPS_DATADIR=\"$CUPS_DATADIR\"; export CUPS_DATADIR" >>$runcups
	echo "CUPS_SERVER=\"$CUPS_SERVER\"; export CUPS_SERVER" >>$runcups
	echo "CUPS_SERVERROOT=\"$CUPS_SERVERROOT\"; export CUPS_SERVERROOT" >>$runcups
	echo "CUPS_STATEDIR=\"$CUPS_STATEDIR\"; export CUPS_STATEDIR" >>$runcups
	echo "DYLD_LIBRARY_PATH=\"$DYLD_LIBRARY_PATH\"; export DYLD_LIBRARY_PATH" >>$runcups
	echo "LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\"; export LD_LIBRARY_PATH" >>$runcups
	echo "LD_PRELOAD=\"$LD_PRELOAD\"; export LD_PRELOAD" >>$runcups
	echo "LOCALEDIR=\"$LOCALEDIR\"; export LOCALEDIR" >>$runcups
	echo "SHLIB_PATH=\"$SHLIB_PATH\"; export SHLIB_PATH" >>$runcups
	if test "x$CUPS_DEBUG_LEVEL" != x; then
		echo "CUPS_DEBUG_FILTER='$CUPS_DEBUG_FILTER'; export CUPS_DEBUG_FILTER" >>$runcups
		echo "CUPS_DEBUG_LEVEL=$CUPS_DEBUG_LEVEL; export CUPS_DEBUG_LEVEL" >>$runcups
		echo "CUPS_DEBUG_LOG='$CUPS_DEBUG_LOG'; export CUPS_DEBUG_LOG" >>$runcups
	fi
	echo "" >>$runcups
	echo "# Run command..." >>$runcups
	echo "exec \"\$@\"" >>$runcups

	chmod +x $runcups

	echo "The $runcups helper script can be used to test programs"
	echo "with the server."
	exit 0
fi

if test $argcount -eq 0; then
	echo "Scheduler is PID $cupsd; run debugger now if you need to."
	echo ""
	echo $ac_n "Press ENTER to continue... $ac_c"
	read junk
else
	echo "Scheduler is PID $cupsd."
	sleep 2
fi

IPP_PORT=$port; export IPP_PORT

while true; do
	running=`../systemv/lpstat -r 2>/dev/null`
	if test "x$running" = "xscheduler is running"; then
		break
	fi

	echo "Waiting for scheduler to become ready..."
	sleep 10
done

#
# Create the test report source file...
#

date=`date "+%Y-%m-%d"`
strfile=/tmp/cups-$user/cups-str-1.7-$date-$user.html

rm -f $strfile
cat str-header.html >$strfile

#
# Run the IPP tests...
#

echo ""
echo "Running IPP compliance tests..."

echo "<H1>1 - IPP Compliance Tests</H1>" >>$strfile
echo "<P>This section provides the results to the IPP compliance tests" >>$strfile
echo "outlined in the CUPS Software Test Plan. These tests were run on" >>$strfile
echo `date "+%Y-%m-%d"` by $user on `hostname`. >>$strfile
echo "<PRE>" >>$strfile

fail=0
for file in 4*.test ipp-2.1.test; do
	echo $ac_n "Performing $file: $ac_c"
	echo "" >>$strfile

	if test $file = ipp-2.1.test; then
		uri="ipp://localhost:$port/printers/Test1"
		options="-V 2.1 -d NOPRINT=1 -f testfile.ps"
	else
		uri="ipp://localhost:$port/printers"
		options=""
	fi
	$VALGRIND ./ipptool -tI $options $uri $file >> $strfile
	status=$?

	if test $status != 0; then
		echo FAIL
		fail=`expr $fail + 1`
	else
		echo PASS
	fi
done

echo "</PRE>" >>$strfile

#
# Run the command tests...
#

echo ""
echo "Running command tests..."

echo "<H1>2 - Command Tests</H1>" >>$strfile
echo "<P>This section provides the results to the command tests" >>$strfile
echo "outlined in the CUPS Software Test Plan. These tests were run on" >>$strfile
echo $date by $user on `hostname`. >>$strfile
echo "<PRE>" >>$strfile

for file in 5*.sh; do
	echo $ac_n "Performing $file: $ac_c"
	echo "" >>$strfile
	echo "\"$file\":" >>$strfile

	sh $file $pjobs $pprinters >> $strfile
	status=$?

	if test $status != 0; then
		echo FAIL
		fail=`expr $fail + 1`
	else
		echo PASS
	fi
done

echo "</PRE>" >>$strfile

#
# Stop the server...
#

kill $cupsd

#
# Append the log files for post-mortim...
#

echo "<H1>3 - Log Files</H1>" >>$strfile

#
# Verify counts...
#

echo "Test Summary"
echo ""
echo "<H2>Summary</H2>" >>$strfile

# Job control files
count=`ls -1 /tmp/cups-$user/spool | wc -l`
count=`expr $count - 1`
if test $count != 0; then
	echo "FAIL: $count job control files were not purged."
	echo "<P>FAIL: $count job control files were not purged.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: All job control files purged."
	echo "<P>PASS: All job control files purged.</P>" >>$strfile
fi

# Pages printed on Test1 (within 1 page for timing-dependent cancel issues)
count=`$GREP '^Test1 ' /tmp/cups-$user/log/page_log | awk 'BEGIN{count=0}{count=count+$7}END{print count}'`
expected=`expr $pjobs \* 2 + 34`
expected2=`expr $expected + 2`
if test $count -lt $expected -a $count -gt $expected2; then
	echo "FAIL: Printer 'Test1' produced $count page(s), expected $expected."
	echo "<P>FAIL: Printer 'Test1' produced $count page(s), expected $expected.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: Printer 'Test1' correctly produced $count page(s)."
	echo "<P>PASS: Printer 'Test1' correctly produced $count page(s).</P>" >>$strfile
fi

# Paged printed on Test2
count=`$GREP '^Test2 ' /tmp/cups-$user/log/page_log | awk 'BEGIN{count=0}{count=count+$7}END{print count}'`
expected=`expr $pjobs \* 2 + 3`
if test $count != $expected; then
	echo "FAIL: Printer 'Test2' produced $count page(s), expected $expected."
	echo "<P>FAIL: Printer 'Test2' produced $count page(s), expected $expected.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: Printer 'Test2' correctly produced $count page(s)."
	echo "<P>PASS: Printer 'Test2' correctly produced $count page(s).</P>" >>$strfile
fi

# Paged printed on Test3
count=`$GREP '^Test3 ' /tmp/cups-$user/log/page_log | grep -v total | awk 'BEGIN{count=0}{count=count+$7}END{print count}'`
expected=2
if test $count != $expected; then
	echo "FAIL: Printer 'Test3' produced $count page(s), expected $expected."
	echo "<P>FAIL: Printer 'Test3' produced $count page(s), expected $expected.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: Printer 'Test3' correctly produced $count page(s)."
	echo "<P>PASS: Printer 'Test3' correctly produced $count page(s).</P>" >>$strfile
fi

# Requests logged
count=`wc -l /tmp/cups-$user/log/access_log | awk '{print $1}'`
expected=`expr 37 + 18 + 28 + $pjobs \* 8 + $pprinters \* $pjobs \* 4`
if test $count != $expected; then
	echo "FAIL: $count requests logged, expected $expected."
	echo "<P>FAIL: $count requests logged, expected $expected.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count requests logged."
	echo "<P>PASS: $count requests logged.</P>" >>$strfile
fi

# Did CUPS-Get-Default get logged?
if $GREP -q CUPS-Get-Default /tmp/cups-$user/log/access_log; then
	echo "FAIL: CUPS-Get-Default logged with 'AccessLogLevel actions'"
	echo "<P>FAIL: CUPS-Get-Default logged with 'AccessLogLevel actions'</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP CUPS-Get-Default /tmp/cups-$user/log/access_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: CUPS-Get-Default not logged."
	echo "<P>PASS: CUPS-Get-Default not logged.</P>" >>$strfile
fi

# Emergency log messages
count=`$GREP '^X ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 0; then
	echo "FAIL: $count emergency messages, expected 0."
	$GREP '^X ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count emergency messages, expected 0.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^X ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count emergency messages."
	echo "<P>PASS: $count emergency messages.</P>" >>$strfile
fi

# Alert log messages
count=`$GREP '^A ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 0; then
	echo "FAIL: $count alert messages, expected 0."
	$GREP '^A ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count alert messages, expected 0.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^A ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count alert messages."
	echo "<P>PASS: $count alert messages.</P>" >>$strfile
fi

# Critical log messages
count=`$GREP '^C ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 0; then
	echo "FAIL: $count critical messages, expected 0."
	$GREP '^C ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count critical messages, expected 0.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^C ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count critical messages."
	echo "<P>PASS: $count critical messages.</P>" >>$strfile
fi

# Error log messages
count=`$GREP '^E ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 33; then
	echo "FAIL: $count error messages, expected 33."
	$GREP '^E ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count error messages, expected 33.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^E ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count error messages."
	echo "<P>PASS: $count error messages.</P>" >>$strfile
fi

# Warning log messages
count=`$GREP '^W ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 9; then
	echo "FAIL: $count warning messages, expected 9."
	$GREP '^W ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count warning messages, expected 9.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^W ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count warning messages."
	echo "<P>PASS: $count warning messages.</P>" >>$strfile
fi

# Notice log messages
count=`$GREP '^N ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count != 0; then
	echo "FAIL: $count notice messages, expected 0."
	$GREP '^N ' /tmp/cups-$user/log/error_log
	echo "<P>FAIL: $count notice messages, expected 0.</P>" >>$strfile
	echo "<PRE>" >>$strfile
	$GREP '^N ' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
	echo "</PRE>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count notice messages."
	echo "<P>PASS: $count notice messages.</P>" >>$strfile
fi

# Info log messages
count=`$GREP '^I ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count = 0; then
	echo "FAIL: $count info messages, expected more than 0."
	echo "<P>FAIL: $count info messages, expected more than 0.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count info messages."
	echo "<P>PASS: $count info messages.</P>" >>$strfile
fi

# Debug log messages
count=`$GREP '^D ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count = 0; then
	echo "FAIL: $count debug messages, expected more than 0."
	echo "<P>FAIL: $count debug messages, expected more than 0.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count debug messages."
	echo "<P>PASS: $count debug messages.</P>" >>$strfile
fi

# Debug2 log messages
count=`$GREP '^d ' /tmp/cups-$user/log/error_log | wc -l | awk '{print $1}'`
if test $count = 0; then
	echo "FAIL: $count debug2 messages, expected more than 0."
	echo "<P>FAIL: $count debug2 messages, expected more than 0.</P>" >>$strfile
	fail=`expr $fail + 1`
else
	echo "PASS: $count debug2 messages."
	echo "<P>PASS: $count debug2 messages.</P>" >>$strfile
fi

# Log files...
echo "<H2>access_log</H2>" >>$strfile
echo "<PRE>" >>$strfile
sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' /tmp/cups-$user/log/access_log >>$strfile
echo "</PRE>" >>$strfile

echo "<H2>error_log</H2>" >>$strfile
echo "<PRE>" >>$strfile
$GREP -v '^d' /tmp/cups-$user/log/error_log | sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' >>$strfile
echo "</PRE>" >>$strfile

echo "<H2>page_log</H2>" >>$strfile
echo "<PRE>" >>$strfile
sed -e '1,$s/&/&amp;/g' -e '1,$s/</&lt;/g' /tmp/cups-$user/log/page_log >>$strfile
echo "</PRE>" >>$strfile

#
# Format the reports and tell the user where to find them...
#

cat str-trailer.html >>$strfile

echo ""

if test $fail != 0; then
	echo "$fail tests failed."
	cp /tmp/cups-$user/log/error_log error_log-$date-$user
	cp $strfile .
else
	echo "All tests were successful."
fi

echo "Log files can be found in /tmp/cups-$user/log."
echo "A HTML report was created in $strfile."
echo ""

if test $fail != 0; then
	echo "Copies of the error_log and `basename $strfile` files are in"
	echo "`pwd`."
	echo ""

	exit 1
fi

#
# End of "$Id: run-stp-tests.sh 9034 2010-03-09 07:03:06Z mike $"
#
