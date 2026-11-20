#!/usr/bin/perl -w

# /var/www/setup.html calls /var/www/setMan.cgi (this script) with parameter 1 (WINTER) or -1 (SUMMER)
# /var/www/setMan.cgi calls /usr/lib/cgi-bin/set_airflow with parameter 1 or -1
# /usr/lib/cgi-bin/set_airflow calls /usr/lib/cgi-bin/set_winter& or set_summer&
# /usr/lib/cgi-bin/set_winter calls /usr/lib/cgi-bin/airflow_winter with flags 1 and 0 (after 90 sec)
# /usr/lib/cgi-bin/set_summer calls /usr/lib/cgi-bin/airflow_summer with flags 1 and 0 (after 90 sec)

use warnings;
use CGI;

my $qcgi = CGI->new();

print "Content-type: text/html\n\n";

my $p0 = $qcgi->param('from');			# WINTER = 1, SUMMER = 0;
	
$b = "sudo /usr/lib/cgi-bin/set_airflow $p0";
system($b) == 0 or die "KO - System failed: $?";

print "OK\n$b";




