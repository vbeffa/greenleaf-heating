#      HOME AUTOMATION EXECUTIVE
#      
#      This program is called by cron every minute.
#      cron runs all files found in /etc/cron.d
#      The file /etc/cron.d/CronJob1 has the content:
#
#   */1 * * * * pi /home/pi/CronJobs/CronTask1 > /dev/null 2>&1	# run this file at 1 minute
#   */5 * * * * pi /home/pi/CronJobs/WatchDog > /dev/null 2>&1  # reboot at 5 minutes if this file is stuck

#   6/24/2017:	Write sprinkler events to log_file_sprinkler file

#	DATABASE TABLES
#
#	can_open_port table:	
#		interlock flag to avoid parallel operations on the IO Cards
#	card_order table: 
#		check which USB port is connected to which IO Card
#	settings table: 
#		all flags set from SETTINGS page and used by program to control logic flow
#		celsius/fahr: not used
#		mail: not used; Always send email
#		sms: not used; Possible use to send sms when errors or security breach
#		heating (1/0): Used to activate heating
#		cooling (1/0): Used to activate cooling
#		summer/winter: Enable heating/cooling flags and change the airflow dampers (90 sec. timing)
#		email: address to send email to; Not used, hardcoded but can be changed in the future
#	heat table:
#		IO port mapping for heat zone relays
#		changes to "value" flags will be transferred to relays each minute
#	navien table:
#		IO port mapping for boiler relay
#		timer for activating the relay 5 minutes after ask for heat.
#	ac table:
#		IO port mapping for AC zone relays
#		changes to "value" flags will be transferred to relays each minute
#	temp table:
#		IO port mapping for reading temperatures
#		current and scheduled temperatures for heating and cooling
#		scheduled heating start and end times
#		zone flags indicating what zone is asking for heat
#		scheduled cooling is not provided but can be implemented
#	sprinkler table
#		IO port mapping for sprinkler relays
#		value shows what sprinkler is on from timer
#		man_on shows what sprinkler is forced manually on
#		sprinkler run times used by timer schedule
#		changes to "value" flags are transferred to relays each minute
#	timer_action table
#		status shows the position of the ON/OFF switch on the IRRIGATION table
#		start_time is the time of TIMER irrigation
#		run_time for each station is from the sprinkler table

# INDEX										Line
# SECTION 1: Check if another instance is active, wait to finish. 		100
# SECTION 2: Open Serial Ports							350
# SECTION 3: Read input sensors: 						439
#	SECTION 3.1: Read temperature sensors					440
#	SECTION 3.2: Read motion sensors					475
#	SECTION 3.3: Read humidity sensors (when installed)			550
# SECTION 4: SPRINKLER processing						586
#	SECTION 4.1: Read "sprinkler" table for sprinkler schedule		587
#	SECTION 4.2: Write sprinkler flags to database				739
#	SECTION 4.3: Transfer database flags to sprinkler relays		774
# SECTION 5: HEAT control (WINTER)						819
#	SECTION 5.1: Read "temp" table						837
#	SECTION 5.2: Read "navien" table for boiler control			879
#       SECTION 5.3: Compute heat requests, write flags to "heat" table		908
#	SECTION 5.4: Write flags to "navien" table				974
#	SECTION 5.5: Transfer database flags to heat relays			1006
#	SECTION 5.6: Transfer database flags to navien relay			1060
# SECTION 6: AC control (SUMMER)						1094
#	SECTION 6.1: Read "temp" table						1107
#	SECTION 6.2: Computer ac requests, write flags to "ac" table
# 	SECTION 6.3: Write FAN and AC flags to ac table
#	SECTION 6.4: Transfer database flags to ac relays			xxx

 
#!/usr/bin/perl -w
use warnings;
# use Device::SerialPort;
use DBI;
use Time::HiRes qw(usleep);
use Date::Parse;
use POSIX qw(strftime);

my $DBG = 1;		# debug mode: set to 1 to print error messages
my $io_id = 0;  	# ID of current IO card - used to count errors in the DB
my $db_open = 0;	# set to 1 of DB is connected
my $log_file = "/home/pi/perl/log_file";
my $log_file_sprinkler = "/home/pi/perl/log_file_sprinkler";
my $err_file = "/home/pi/perl/err_file";
my $summer_time = 0;	# must read from database
my $winter_time = 1;	# must read from database 
my $sprinkler_forced=0;	# one station forced on manually

# temp table variables

my @heat_zone = ();	# "name" goes here
my @room_temp = ();	# "value" goes here
my @high_temp = ();	# target temp for manual heating
my @low_temp = ();	# target temp for manual cooling
my @sched_temp = (); 	# target temp for scheduled heating
my @start_time1 = (); 	# schedule #1 start
my @end_time1 = (); 	# schedule #1 end
my @start_time2 = (); 	# schedule #2 start
my @end_time2 = (); 	# schedule #2 end
my @daily = ();		# apply schedule daily
my @one_time = ();	# apply schedule one time
my @day = ();		# one time day
my @z_1 = (); 		# zone heating flag for schedule 1
my @z_2 = ();		# zone heating flag for schedule 2

my @temp_array = (104,103.8,103.6,103.5,103.3,103.1,102.7,102.6,102.4,102.2,102,101.8,101.5,101.3,101.1,100.9,100.8,100.6,100.4,100.2,
99.9,99.7,99.5,99.3,99.1,99,98.8,98.6,98.4,98.2,97.9,97.7,97.5,97.3,97.2,97,96.8,96.6,96.4,96.3,96.1,95.9,95.7,95.5,95.4,95.2,95,94.8,
94.6,94.5,94.3,94.1,93.9,93.7,93.6,93.4,93.2,93,92.8,92.7,92.5,92.3,92.1,91.9,91.8,91.6,91.4,91.2,91,90.9,90.7,90.5,90.3,90.1,90,
89.8,89.6,89.5,89.4,89.2,89.1,88.9,88.7,88.5,88.3,88.2,88,87.8,87.6,87.5,87.4,87.3,87.1,86.9,86.7,86.5,86.4,86.2,86.1,86,85.8,85.6,
85.5,85.3,85.1,85,84.9,84.7,84.6,84.4,84.2,84,83.8,83.7,83.5,83.3,83.1,83,82.9,82.8,82.6,82.4,82.2,82.1,82,81.9,81.7,81.5,81.4,81.3,
81.1,81,80.8,80.6,80.5,80.4,80.2,80.1,80,
79.9,79.7,79.5,79.3,79.3,79.2,79,78.8,78.6,78.5,78.4,78.3,78.1,78,77.9,77.7,77.5,77.5,77.4,77.2,77,76.9,76.8,76.6,76.5,76.4,76.3,76.1,
75.9,75.8,75.7,75.6,75.4,75.3,75.2,75,74.8,74.8,74.7,74.5,74.4,74.3,74.1,73.9,73.9,73.8,73.6,73.5,73.4,73.2,73,73,72.9,72.7,72.5,72.3,
72.1,72.1,72,71.8,71.7,71.6,71.4,71.3,71.2,71.1,71,70.9,70.7,70.5,70.4,70.3,70.2,70.1,70,
69.8,69.7,69.6,69.4,69.4,69.3,69.1,69,68.9,68.7,68.6,68.5,68.4,68.3,68.2,68,67.9,67.8,67.6,67.6,67.5,67.4,67.3,67.1,67,66.9,66.7,66.7,
66.6,66.4,66.3,66.2,66,65.9,65.8,65.8,65.7,65.5,65.4,65.3,65.1,65,64.9,64.9,64.8,64.6,64.5,64.4,64.2,64.1,64,64,63.9,63.7,63.6,63.5,
63.3,63.2,63.1,63.1,63,62.8,62.7,62.6,62.5,62.4,62.2,62.2,62.1,62,61.9,61.7,61.6,61.5,61.4,61.3,61.2,61.1,61,60.9,60.8,60.6,60.5,60.4,
60.4,60.3,60.2,60.1,
59.9,59.8,59.7,59.6,59.5,59.4,59.3,59.2,59.1,59,58.9,58.8,58.6,58.6,58.5,58.4,58.3,58.2,58.1,57.9,57.8,57.7,57.7,57.6,57.5,57.4,57.2,
57.1,57,56.9,56.8,56.8,56.7,56.6,56.5,56.3,56.2,56.1,56,55.9,55.9,55.8,55.7,55.6,55.4,55.3,55.2,55.1,55,55,54.9,54.8,54.7,54.6,54.5,
54.3,54.2,54.1,54.1,54,53.9,53.8,53.7,53.6,53.5,53.4,53.3,53.2,53.1,53,52.9,52.8,52.7,52.6,52.5,52.4,52.3,52.3,52.2,52.1,52,51.9,51.8,
51.6,51.4,51.4,51.3,51.2,51.1,51,50.9,50.8,50.7,50.6,50.5,50.5,50.4,50.3,50.2,50.1,50,
49.9,49.8,49.7,49.6,49.6,49.5,49.4,49.3,49.2,49.1,49,48.9,48.8,48.7,48.7,48.6,48.5,48.4,48.3,48.2,48.1,48,47.9,47.8,47.8,47.7,47.6,
47.5,47.4,47.3,47.2,47.1,47,46.9,46.9,46.8,46.7,46.6,46.5,46.4,46.3,46.2,46.1,46,46,45.9,45.8,45.7,45.6,45.5,45.4,45.3,45.2,45.1,
45.1,45,44.9,44.8,44.7,44.6,44.5,44.4,44.3,44.2,44.2,44.1,44,43.9,43.9,43.8,43.7,43.6,43.5,43.4,43.3,43.3,43.2,43.1,43,42.9,42.8,
42.7,42.6,42.5,42.4,42.4,42.3,42.2,42.2,42.1,42,41.9,41.8,41.7,41.6,41.5,41.5,41.4,41.3,41.2,41.1,41,40.9,40.9,40.8,40.7,40.6,40.6,
40.5,40.4,40.3,40.2,40.1,40,
39.9,39.8,39.8,39.7,39.7,39.6,39.5,39.4,39.2,39.1,39,38.9,38.8,38.8,38.8,38.7,38.6,38.5,38.4,38.3,38.2,38.1,38,37.9,37.9,37.9,37.8,
37.7,37.6,37.5,37.4,37.3,37.2,37.1,37.1,37,37,36.9,36.8,36.7,36.6,36.5,36.4,36.4,36.3,36.2,36.1,36.1,36,35.9,35.8,35.7,35.6,35.6,
35.5,35.4,35.3,35.2,35.2,35.1,35,34.9,34.9,34.8,34.7,34.6,34.5,34.4,34.3,34.3,34.3,34.2,34.1,34,33.9,33.8,33.7,33.7,33.6,33.5,33.4,
33.4,33.3,33.2,33.1,33,33,32.9,32.8,32.7,32.6,32.5,32.5,32.5,32.4,32.3,32.2,32.1,32);


my @h_v = (); 		# status of heat relays; used for AC also 

#########################################
# Open DB
#########################################

$db ="mysql";
$pas = $ENV{"GREENLEAF_DB_PASSWORD"} // die "GREENLEAF_DB_PASSWORD must be set";
# Database password is supplied through GREENLEAF_DB_PASSWORD;
$db ="ha";
$dbh = DBI->connect("DBI:mysql:$db:localhost", "root", $pas) or die "Could not connect to database: $DBI::errstr";
if($DBG eq 1) { print "#Database OK\n"; }
$db_open = 1;

######################################################################
# SECTION 1: Check if another instance is active, wait to finish. 
######################################################################

# Check if the IO Process is Locked                                     
# read can_open_port table; if no = 1 the process is locked, stop execution

my $port_not_locked = 1;		# assume IO port is not locked by another process

$qh1 = $dbh->prepare("select no from can_open_port");
$qh1->execute();
$qh1->bind_columns(undef, \$v);
if($qh1->fetch())
{ 
  if($v eq 1)
  {
   $port_not_locked = 0;
  } 
  else
  {
# the program can continue, lock database flag to prevent parallel launches
    dosql("update can_open_port set no = 1");
  }
}

if($port_not_locked == 0)	# port is locked by another process
{
  sleep(5);			# wait 5 seconds and check again
  $qh1 = $dbh->prepare("select no from can_open_port");
  $qh1->execute();
  $qh1->bind_columns(undef, \$v);
  if($qh1->fetch())
  { 
    if($v eq 1)
    {
       log_event("Interlock flag stuck (io2db.pl)");	#no process should lock the port for more than 4 seconds
       system('echo "Interlock flag stuck"|mail -s "Home Automation Error" mbeffa@gmail.com');
       exit;
    } 
    else
    {
# the program can continue, lock database flag to prevent parallel launches
      $port_not_locked = 1;
      dosql("update can_open_port set no = 1");
    }
  }
}

######## WARNING: DO NOT CHANGE THE DECLARED ORDER for tty_order

$id = 1;
$usb = "/dev/ttyACM".$id;
my $port1 = Device::SerialPort ->new($usb);
$id = 0;
$usb = "/dev/ttyACM".$id;
my $port2 = Device::SerialPort ->new($usb);
my $port_out1 = '';
my $port_out2 = '';
my $N = 5000;  # max number of port accesses before timeout

#****************************************
# START OF SUBROUTINE DEFINITIONS
#****************************************

#########################################
# dosql: execute sql command
#########################################

sub dosql 
{ 
  $d = $_[0];
  $dbh->do($d);
  if($DBG eq 1) { printf "  SQL...$d...\n"; }
  return 1;
}

#########################################
#log_event: write event in log file
#########################################

sub log_event
{
  $s = $_[0];	#string to be printed
  $s .= (" " x (40 - length($s)));	#pad string with spaces to 40 characters
  open (FILE, ">>$log_file") or die "Cannot open log file\n";
  print (FILE $s);
  close FILE;
  system('date >> /home/pi/perl/log_file');
}

sub log_event_sprinkler
{
  $s = $_[0];	#string to be printed
  $s .= (" " x (40 - length($s)));	#pad string with spaces to 40 characters
  open (FILE, ">>$log_file_sprinkler") or die "Cannot open log file\n";
  print (FILE $s);
  close FILE;
  system('date >> /home/pi/perl/log_file_sprinkler');
}

#########################################
# log_error: print error message
#########################################

sub log_error
{
  $s = 'Error: '.$_[0];
  log_event($s);

  open (FILE, ">$err_file") or die "Cannot open error file\n";
  print (FILE $s);
  close FILE;
  system('date >> /home/pi/perl/err_file');
  system('cat /home/pi/perl/err_file | mail -s "Home Automation Error" mbeffa@gmail.com');

  $port1->close;
  $port2->close;
# if this process locked the database, clear interlock flag before exit 
  if($db_open > 0)
  {
    dosql("update can_open_port set no = 0");
#    $dbh->disconnect();
  }
  exit;
}
#########################################
# io_op1: read/write IOCARD0
#########################################

sub io_op1
{
  my $byte = 0;
  $io_id = 0;
  $port_out1 = "";
  if(!$port1->write($_[0]))
  {
    log_error("Cannot write IOCARD0");
  }
  for ($i = 1; $i <= $N; $i++) 
  {
    usleep(1000);
    $byte = $port1 -> read(1);
    if ($byte eq "~")
      {last};
  }
  if($i >= $N) 
    { log_error("READ timeout on CARD0 (first ~)"); }
  for ($i = 1; $i <= $N; $i++) 
  {
    $byte = $port1 -> read(1);
#   usleep(10000);
    usleep(1000);	#changed from 10000 on 2-25-2017 - need to watch it
    if ($byte eq "~")
      {last};
    $port_out1 = $port_out1 . $byte;
  }
  if($i >= $N) 
    { log_error("READ timeout on CARD0 (last ~)"); }
  $ij = index $port_out1, "=";
  $ik = index $port_out1, "in";
  if($ij gt 0 && $ik ge 0)
  {
    $port_out1 = substr($port_out1, $ij + 1);
  }
}

#########################################
# io_op2: read/write IOCARD1
#########################################

sub io_op2
{
  my $byte = 0;
  $io_id = 1;
  $port_out2 = "";
  if(!$port2->write($_[0]))
  {
    log_error("Cannot write IOCARD1");
  }
  for ($i = 1; $i <= $N; $i++) 
  {
    usleep(1000);
    $byte = $port2 -> read(1);
    if ($byte eq "~")
      {last};
  }
  if($i >= $N) 
    { log_error("READ timeout on CARD1 (first ~)"); }
  for ($i = 1; $i <= $N; $i++) 
  {
    $byte = $port2 -> read(1);
#   usleep(10000);
    usleep(1000);	#changed from 10000 on 2-25-2017 - need to watch it
    if ($byte eq "~")
      {last};
    $port_out2 = $port_out2 . $byte;
  }
  if($i >= $N) 
    { log_error("READ timeout on CARD1 (last ~)"); }
  $ij = index $port_out2, "=";
  $ik = index $port_out2, "in";
  if($ij gt 0 && $ik ge 0)
  {
      $port_out2 = substr($port_out2, $ij + 1);
  }
#    usleep(1000 * 100);
}


#****************************************
# END OF SUBROUTINE DEFINITIONS
#****************************************

#****************************************
# START OF SEQUENTIAL IO ACCESS
#****************************************

#########################################
# SECTION 2: Open Serial Ports to IO Cards
#########################################

if(!$port1)
{
  log_error("Device $usb FAIL");
}
else
{
  $port1->user_msg(ON);
  if(!$port1->baudrate(9600)) 	{ log_error("Cannot set baudrate"); }
  if(!$port1->parity("none")) 	{ log_error("Cannot set parity"); }
  if(!$port1->databits(8)) 	{ log_error("Cannot set databits"); }
  if(!$port1->stopbits(1)) 	{ log_error("Cannot set stopbits"); }
  if(!$port1->handshake("xoff")){ log_error("Cannot set handshake"); }
  if(!$port1->write_settings) 	{ log_error("Cannot write settings"); }
}
if($DBG eq 1) { print "#IOCARD #0 OK\n"; }

#########################################
# Open serial port to IOCARD1
#########################################

if(!$port2)
{
  log_error("Device $usb FAIL");
}
else
{
  $port2->user_msg(ON);
  if(!$port2->baudrate(9600)) 	{ log_error("Cannot set baudrate"); }
  if(!$port2->parity("none")) 	{ log_error("Cannot set parity"); }
  if(!$port2->databits(8)) 	{ log_error("Cannot set databits"); }
  if(!$port2->stopbits(1)) 	{ log_error("Cannot set stopbits"); }
  if(!$port2->handshake("xoff")){ log_error("Cannot set handshake"); }
  if(!$port2->write_settings) 	{ log_error("Cannot write settings"); }
}
if($DBG eq 1) { print "#IOCARD #1 OK\n"; }

# citesc ultimele erori contorizate, daca ele sunt
$qh1 = $dbh->prepare("select id_order, count from timeout_error order by id");
$qh1->execute();
$qh1->bind_columns(undef, \$v, \$v1);
$app_counter0 = 0;
$app_counter1 = 0;
$counter0 = 0;
$counter1 = 0;
if($qh1->fetch())
{ 
  $app_counter0 = $v; 
  $counter0 = $v1; 
}
if($qh1->fetch())
{ 
  $app_counter1 = $v; 
  $counter1 = $v1; 
}

# read ID from the last program launch (each launch increments it)
# this is required to send email when two consecutive launches result in errors

$qh1 = $dbh->prepare("select * from run_process");
$qh1->execute();
$qh1->bind_columns(undef, \$v);
$run_counter = 0;
if($qh1->fetch())
{ 
  $run_counter = $v; 
}

my $tty_order = 0;  # normala
$p1 = 'IO0';
$p2 = 'IO1';

# read LOOPBACK to find IO Card port order

$qh1 = $dbh->prepare("select tty_order from card_order");
$qh1->execute();
$qh1->bind_columns(undef, \$id);
if($qh1->fetch())
  { $tty_order = $id; }
if($DBG eq 1) { print "tty order: $tty_order\n"; }
if($tty_order eq 1)
{
  $p1 = 'IO1';
  $p2 = 'IO0';
}

#########################################
# SECTION 3: Read Input Sensors
# SECTION 3.1 Read Temperature Sensors
#########################################

$j = $run_counter % 8 + 1;	# al catelea id_senzor este de citit ($run_counter modulo 8 + 1)

if($DBG eq 1) { print "#Temp sensors ? --> $p1\n"; }
$b = '';
$qh1 = $dbh->prepare("select name, port, value from temp where id = $j");
$qh1->execute();
$qh1->bind_columns(undef, \$v0, \$port, \$vl);

my $temp_index = 0;
$qh1->fetch();
if($tty_order eq 0)
{
      io_op1($port);
      $b = $port_out1;
}
else
{
      io_op2($port);
      $b = $port_out2;
}

# print "Value from IO Card: $b\n";
# Lookup table has temperatures for all ADC values from 0272 to 0891.
# Corresponding temperatures are 104F to 32F

$temp_index = int(substr($b,3)) - 271;

# print "Value for temp array: $temp_index\n";

if (($temp_index > 0) and ($temp_index < 615))
{
   $t = $temp_array[$temp_index];	#convert A/D value to Fahrenheit
   
#  print "$v0 crt temp = $t\n";
   
# recover last value from DB and make average, to smooth noise on temperature readings
   
   $t = ($t + $vl) / 2;
   
#  print "$v0 avg temp = $t\n";
   
   $c = "update temp set value = $t where id = $j";
   dosql($c);
   $temp = sprintf("%.1f", $t);

   my $minutes = substr(localtime,14,2);
   if (($minutes >= 0) and ($minutes <= 7))
   {
# log temperatures only once every hour
      log_event("Temp $v0 $temp F");
   }
#  log_event("Temp $v0 $temp F");
}
else
{
#   log_event("Temperature $v0 out of range");
}

#########################################
# SECTION 3.2 Read Motion Sensors 
#########################################

  if($DBG eq 1) { print "#PIR sensors ? --> $p1\n"; }
  $qh1 = $dbh->prepare("select id, name, port from sensor order by 1");
  $qh1->execute();
  $qh1->bind_columns(undef, \$id, \$name, \$port);
  $a = '--------------';
  $i = 0;
  $x = 0;
  @id = (0, 0, 0, 0, 0, 0, 0, 0);
  while($qh1->fetch()) 
  {
    $id[$i] = $id;
    $name[$i] = $name;
    $i12 = substr($port, 3, 2);
    $x = 0;
    if($i12 ge 10)
    {
      $x = 1;
    }
    $j = hex($i12) - $x * 16;
    if($j gt 0)
    {
      $a = substr($a, 0, $j) . '1' . substr($a, $j + 1);
    }
    else
    {
      $a = '1' . substr($a, $j + 1);
    }
    $i++;
  }
  $a = "~IN" . $x . "=" . $a . "~";
  if($DBG eq 1) { print "  Command: $a  "; }
  $b = '';
  if($tty_order eq 0)
  {
    io_op1($a);
    $b = $port_out1;
  }
  else
  {
    io_op2($a);
    $b = $port_out2;
  }
#print "receive: $b\n"; 
  
  # ignore string length, sometimes the port returns truncated string
  # isolate the correct values, one at a time
  
  #if(length($b) >= 13)
  {
    $j = 0;
    for($i = 0; $i < length($b); $i++)
    {
      $c = substr($b, $i, 1);
      if($c ne "-")
      {
        $d = "update sensor set value = '" . $c . "' where id = " . $id[$j];

#print "updating sensors in $name[$j]  $c \n";
if ($c == 1) 
   {
   log_event ("Motion Sensor ON in $name[$j]:");
   }

        dosql($d);
        $j++;
      }
    }
  }

#########################################
# SECTION 3.3 Read Humidity Sensors - later
# 	No humidity sensors installed
#########################################

# print "#Humidity sensors ? --> $p2\n";
# $b = '';
# $j = 0;
# $qh1 = $dbh->prepare("select id, port from humidity order by 1");
# $qh1->execute();
# $qh 1->bind_columns(undef, \$id1, \$port);
# while($qh1->fetch()) 
# {
#   print "  Command: $port  ";
#   if($tty_order eq 0)
#   {
#     io_op2($port);
#     $b = $port_out2;
#   }
#   else
#   {
#     io_op1($port);
#     $b = $port_out1;
#   }
#   print "receive: $b\n";
#   $b = substr($b, 4);
#   $c = "update humidity set value = $b where id = $j";
#   dosql($c);
#   $j++;
# }
# print "#Humidity sensors OK\n";

# All sensor inputs have been transfered to the database
# Next read from database all flags for sprinkler timing


#################################################
# SECTION 4: SPRINKLER Processing
# SECTION 4.1 Read "sprinkler: table for sprinkler schedule
#################################################

# check if sprinkler was forced on manually

##################### read man_on #####################

$qh1 = $dbh->prepare("select man_on from sprinkler");
$qh1->execute();
$qh1->bind_columns(undef, \$v0);
my @man_on = ();	# set if one station was forced on manually

for ($i = 1; $i <= 8; $i++)
{ 
  if($qh1->fetch()) 
  { 
  $man_on[$i] = $v0;
  $sprinkler_forced = $sprinkler_forced + $man_on[$i];
  } 
}
#print "SPRINKLER FORCED: $sprinkler_forced\n";

############## read start_time ##################

$timer_on = 0;
$timer_value = '';
# timer_action table has timer status and start_time
$qh1 = $dbh->prepare("select * from timer_action ");    
$qh1->execute();
$qh1->bind_columns(undef, \$timer_on, \$timer_value);
$qh1->fetch();

if( $timer_on eq 1 )	# TIMER is ON
{
# start_time is set by user in IRRIGATION page
  $qh1 = $dbh->prepare("select start_time from timer_action");
  $qh1->execute();
  $qh1->bind_columns(undef, \$v);
  my @start_time = (); # read start time;
  $qh1->fetch();
# pregatesc primul timp
  $start_time[1] = str2time($v);

# print "Timpul din tabela timer_action " . $v . "  (intern) = " . $start_time[1]\n";

  #################### read run_time ####################

  $qh1 = $dbh->prepare("select run_time from sprinkler");
  $qh1->execute();
  $qh1->bind_columns(undef, \$v1);
  my @run_time = (); 	# read run time;

  for ($i = 1; $i <= 8; $i++)
  { 
    if($qh1->fetch()) 
    { 
    $run_time[$i] = $v1 * 60;

# pregatesc secventa de timpi de lansare OBS. valorile timpilor sunt in format integer
    $start_time[$i+1] = $start_time[$i] + $run_time[$i];
# print "start time $i = $start_time[$i]\n";
    } 
  }
  
  my $weekday = substr(localtime,0,3);
  my @week_day = ();

  #################### read Monday flags ####################

  if ($weekday eq "Mon")
    {  
    $qh1 = $dbh->prepare("select mon from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Tuesday flags ###################
    
  if ($weekday eq "Tue")
    {
    $qh1 = $dbh->prepare("select tue from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Wednesday flags #################
    
  if ($weekday eq "Wed")
    {
    $qh1 = $dbh->prepare("select wed from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Thursday flags ##################
    
  if ($weekday eq "Thu")
    {
    $qh1 = $dbh->prepare("select thu from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Friday flags ####################
    
  if ($weekday eq "Fri")
    {
    $qh1 = $dbh->prepare("select fri from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Saturday flags ##################
    
  if ($weekday eq "Sat")
    {
    $qh1 = $dbh->prepare("select sat from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

  #################### read Sunday flags ####################
    
  if ($weekday eq "Sun")
    {
    $qh1 = $dbh->prepare("select sun from sprinkler");
    $qh1->execute();
    $qh1->bind_columns(undef, \$v);
    
    for ($i = 1; $i <= 8; $i++)
      { if($qh1->fetch()) { $week_day[$i] = $v; } }
    }

#################################################
# SECTION 4.2: Write sprinkler flags to database
#################################################

  $crt_tm = time;
  for ($i = 1; $i <= 8; $i++) 
  { 
    $start_tm = $start_time[$i];
    $run_tm  = $run_time[$i];
    $end_tm  = $start_tm + $run_tm;
    $wk_day  = $week_day[$i];
#    print "> Sprinkler #" . $i . " - start: " . $start_tm . " for " . $run_tm . " sec. until " . $end_tm . " today permission = " . $wk_day . "\n";

    if (($crt_tm >= $start_tm) and ($crt_tm < $end_tm) and ($wk_day == 1))
    {
      dosql("update sprinkler set value = 1 where id = $i");
#     log_event("Sprinkler Station #$i ON");
    }
    else
    {
      dosql("update sprinkler set value = 0 where id = $i");
    }
  }
}
else	# TIMER is OFF
{
   if ($sprinkler_forced == 0)	#no station was forced on
   {
   for ($i = 1; $i <= 8; $i++)
      {
      dosql("update sprinkler set value = 0 where id = $i");
      }
   }
}

##############################################
# SECTION 4.3: Transfer Database Flags to Sprinkler Relays
##############################################

$b = '';
#$j = 0;
$value='';
$sql1 = "select id, value, port from sprinkler where value <> lastval";
$qh1 = $dbh->prepare($sql1);
$qh1->execute();
$qh1->bind_columns(undef, \$id, \$value, \$port);
while($qh1->fetch()) 
{
  $c = '';
  $b = substr($port, 0, 7) . $value . '~';
  $d = substr($port, 4, 2);
  $im_id = $id;
  $im_id_n = 'FRONT';
  if($id >= 4)
  {
     $im_id_n = 'BACK';
     $im_id = $id - 3;
  }
  if($value eq '0') 
  {
    $b = "~in" . $d . "~";
#   log_event("Sprinkler Station #$id Auto OFF:");
    log_event_sprinkler("Sprinkler Station #$im_id $im_id_n Auto OFF:");

  }
  else
  {
    $b = "~out" . $d . "=0~";
#   log_event("Sprinkler Station #$id Auto ON:");
    log_event_sprinkler("Sprinkler Station #$im_id $im_id_n Auto ON:");
  }
  if($DBG eq 1) { print "  Command: $b  "; }
  if($tty_order eq 0)
  {
    io_op1($b);
    $c = $port_out1;

  if($DBG eq 1) { print "  Command: $c  "; }
  }
  else
  {
    io_op2($b);
    $c = $port_out2;
  if($DBG eq 1) { print "  Command: $c  "; }
  }
  if($DBG eq 1) { print "receive: $c\n"; }
  $c = "update sprinkler set lastval = $value where id = $id";
  dosql($c);
}
#######  END OF SPRINKLER PROCESSING  ########

##############################################
# SECTION 5: Manual HEAT control (WINTER)
##############################################

# Read settings table

$qh1 = $dbh->prepare("select heating, cooling, summer, winter from settings ");    
$qh1->execute();
$qh1->bind_columns(undef,  \$heating, \$cooling, \$summer_time, \$winter_time);
$qh1->fetch();

if ($winter_time == 1) {goto WINTER;}
if ($summer_time == 1) {goto SUMMER;}

WINTER:

if ($heating == 0) 			# turn off all flags and heat relays
{ 
   dosql("update heat set value=0");	# all heat flags off
   for ($i = 1; $i <= 5; $i++)
      { $h_v[$i] = 0; }			# all relay flags off
   goto HEAT_RELAYS;			# turn off all relays, do not check temp table  
}
# print "winter time: $winter_time, summer time = $summer_time, heating = $heating, cooling = $cooling\n";

##############################################################
# SECTION 5.1: Read "temp" table
##############################################################

$qh1=$dbh->prepare("select name,value,high_temp,low_temp,sched_temp,start_time1,end_time1,
	start_time2,end_time2,daily,one_time,day,z_1,z_2 from temp order by id");
$qh1->execute();
$qh1->bind_columns(undef,\$v1,\$v2,\$v3,\$v4,\$v5,\$v6,\$v7,\$v8,\$v9,\$v10,\$v11,\$v12,\$v13,\$v14);

for ($i = 1; $i <= 8; $i++)
{
   if($qh1->fetch())
   {
      $heat_zone[$i] 	= $v1; 
      $room_temp[$i] 	= $v2; 
      $high_temp[$i] 	= $v3; 
      $low_temp[$i] 	= $v4; 
      $sched_temp[$i] 	= $v5; 
      $start_time1[$i] 	= str2time($v6); 
      $end_time1[$i] 	= str2time($v7); 
      $start_time2[$i] 	= str2time($v8); 
      $end_time2[$i] 	= str2time($v9); 
      $daily[$i] 	= $v10;
      $one_time[$i] 	= $v11;
      $day[$i]		= $v12;
      $z_1[$i] 		= $v13; 
      $z_2[$i] 		= $v14; 
   }
}

##############################################################
# SECTION 5.2: Read "navien" table for boiler control
##############################################################

$qh1 = $dbh->prepare("select value from navien");
$qh1->execute();
$qh1->bind_columns(undef, \$v);
my $navien = 0; 	# read relay status

if($qh1->fetch())
{ 
   $navien = $v; 
}

$qh1 = $dbh->prepare("select min_count from navien");
$qh1->execute();
$qh1->bind_columns(undef, \$v);
my $min_count = 0; 	# count minutes since one zone was turned on

# ask for heat if any heat zone is on for 5 minutes 

if($qh1->fetch())
{ 
   $min_count = $v; 
}

##############################################
# SECTION 5.3: Compute heat requests, write flags to "heat" table
##############################################

$crt_tm = time;
$today =  strftime "%Y-%m-%d", localtime;

for ($i = 2; $i <= 6; $i++)   # Process Guest Living Master Bdrm2 Office
{

#if ($i == 3)
#{
#print "HEATING VARIABLES for zone $i $heat_zone[$i]\n";
#print "Room Temp: 	$room_temp[$i]\n";
#print "Target Temp:  	$high_temp[$i]\n";
#print "Sched Temp:	$sched_temp[$i]\n";
#print "Current Time: 	$crt_tm\n";
#print "Start Time1:  	$start_time1[$i]\n";
#print "End Time1: 	$end_time1[$i]\n";
#print "Today:		$today\n";
#print "Start Time2:  	$start_time2[$i]\n";
#print "End Time2: 	$end_time2[$i]\n";
#print "Daily flag:	$daily[$i]\n";
#print "One Time flag: 	$one_time[$i]\n";
#print "One Time Day:	$day[$i]\n";
#print "Zone Flag 1:  	$z_1[$i]\n";
#print "Zone Flag 2:  	$z_2[$i]\n";
#}

# Check heating schedules, update flags
   if          # any zone asks for heat 
   (
      ($high_temp[$i] > $room_temp[$i])   #zone(i) asks for heat manually 
      or               # zone(i) has schedule1 daily
      (
         ($sched_temp[$i] > $room_temp[$i]) and 
         ($crt_tm > $start_time1[$i]) and 
         ($crt_tm < $end_time1[$i]) and 
         ($daily[$i] == 1) and 
         ($z_1[$i] == 1)
      )   
      or               # zone(i) has schedule1 one time today
      (
         ($sched_temp[$i] > $room_temp[$i]) and 
         ($crt_tm > $start_time1[$i]) and 
         ($crt_tm < $end_time1[$i]) and 
         ($one_time[$i] == 1) and 
         ($today eq $day[$i]) and
         ($z_1[$i] == 1)
      )   
      or               # zone(i) had schedule2 daily
      (
         ($sched_temp[$i] > $room_temp[$i]) and 
         ($crt_tm > $start_time2[$i]) and 
         ($crt_tm < $end_time2[$i]) and 
         ($daily[$i] == 1) and 
         ($z_2[$i] == 1)
      )
      or               # zone(i) has schedule2 one time today
      (
         ($sched_temp[$i] > $room_temp[$i]) and 
         ($crt_tm > $start_time2[$i]) and 
         ($crt_tm<$end_time2[$i]) and 
         ($one_time[$i] == 1) and 
         ($today eq $day[$i]) and
         ($z_2[$i] == 1)
      )
   )

   {			# turn heat on for zone $i
      dosql("update heat set value = 1 where id = " . ($i - 1));
      $h_v[$i-1] = 1; 
   }
else            	# turn heat off
   {
      dosql("update heat set value = 0 where id = " . ($i - 1));
      $h_v[$i-1] = 0; 
   } 
}	# end of process Guest Living Master Bdrm2 Office zones for heat

HEAT_RELAYS:

#####################################################
# SECTION 5.4: Write flags to "navien" table
# Radiant heat system uses wax activated valves
# Valves need 5 minutes to open up
# Fire the boiler after 5 minutes of continuous ask from any zone
#####################################################

if ($h_v[1] + $h_v[2] + $h_v[3] + $h_v[4] +$h_v[5] == 0)# Nobody wants heat
{
   dosql("update navien set value = 0");
   dosql("update navien set min_count = 0");
   dosql("update heat set value = 0 where id = 6"); 	# Heat pumps OFF
}
else							# Somebody wants heat
{
   dosql("update heat set value = 1 where id = 6"); 	# Set flag for heat pumps ON
   $min_count = $min_count + 1;
   if ($min_count >= 5)
   {
      dosql("update navien set value = 1");      	# Set flag to fire the boiler
   }
   else
   {
      dosql("update navien set min_count = $min_count");# Count this pass
      log_event("Asking for Heat $min_count min.:");
   }
}

##############################################
# SECTION 5.5: Transfer database flags to heat relays
##############################################

# Heat Relays are connected as follows: 
# Flow_C = out00;	Used to change airflow from summer to winter 
# Flow_H = out01;	Used to change airflow from summer to winter 
# Pumps = out02 - Turn ON when any zone is ON
# Heat Office = out03;	id = 6
# Heat Bdrm2 = out04;	id = 5
# Heat Master = out05;	id = 4
# Heat Living = out06;	id = 3
# Heat Guest = out07;	id = 2

$sql1 = "select id, value, port, name from heat where value <> lastval";
$qh1 = $dbh->prepare($sql1);
$qh1->execute();
$qh1->bind_columns(undef, \$id, \$value, \$port, \$zone);
while($qh1->fetch()) 
{
   $c = '';
   $b = substr($port, 0, 7) . $value . '~';
   $d = substr($port, 4, 2);
   if($value eq '0') 
   {
      $b = "~in" . $d . "~";
      log_event("Turn OFF heat $zone");
   }
   else
   {
      $b = "~out" . $d . "=0~";
      log_event("Turn ON heat $zone");
   }
   if($tty_order eq 0)
   {
      io_op2($b);
      $c = $port_out2;
   }
   else
   {
      io_op1($b);
      $c = $port_out1;
   }
   $c = "update heat set lastval = $value where id = $id";
   dosql($c);
}

##############################################
# SECTION 5.6: Transfer database flags to navien relay
##############################################

$sql1 = "select id, value, port from navien where value <> lastval";
$qh1 = $dbh->prepare($sql1);
$qh1->execute();
$qh1->bind_columns(undef, \$id, \$value, \$port);
while($qh1->fetch()) 
{
   $c = '';
   $b = substr($port, 0, 7) . $value . '~';
   $d = substr($port, 4, 2);
   if($value eq '0') 	# read port to clear relay
   {
      $b = "~in" . $d . "~";
      log_event("Turn OFF Navien Boiler:");
   }
   else
   {
      $b = "~out" . $d . "=0~";	# write port to set relay
      log_event("Turn ON Navien Boiler:");
   }
#  print "  Command: $b  "; 
   if($tty_order eq 0)
   {
      io_op2($b);
      $c = $port_out2;
   }
   else
   {
      io_op1($b);
      $c = $port_out1;
   }
   $c = "update navien set lastval = $value where id = $id";
   dosql($c);
}

goto END;	# END when WINTER

SUMMER:		# Summe and cooling is ON
# print "Summer time: $winter_time, summer time = $summer_time, heating = $heating, cooling = $cooling\n";

if ($cooling == 0) 	# turn off all flags, in case cooling turned off while ac was on
{ 
   dosql("update ac set value=0");	# all cooling flags off
   for ($i = 1; $i <= 5; $i++)
      { $h_v[$i] = 0; }			# all relay flags off
   goto AC_RELAYS;			# turn off all relays, do not check temp table  
}
##############################################
# SECTION 6: AC control (SUMMER)
# SECTION 6.1: Read "temp" table
##############################################

$qh1=$dbh->prepare("select name,value,high_temp,low_temp,sched_temp,start_time1,end_time1,
	start_time2,end_time2,daily,one_time,day,z_1,z_2 from temp order by id");
$qh1->execute();
$qh1->bind_columns(undef,\$v1,\$v2,\$v3,\$v4,\$v5,\$v6,\$v7,\$v8,\$v9,\$v10,\$v11,\$v12,\$v13,\$v14);

for ($i = 1; $i <= 8; $i++)
  {
  if($qh1->fetch())
    {
      $heat_zone[$i] 	= $v1; 
      $room_temp[$i] 	= $v2; 
      $high_temp[$i] 	= $v3; 
      $low_temp[$i] 	= $v4; 
      $sched_temp[$i] 	= $v5; 
      $start_time1[$i] 	= str2time($v6); 
      $end_time1[$i] 	= str2time($v7); 
      $start_time2[$i] 	= str2time($v8); 
      $end_time2[$i] 	= str2time($v9); 
      $daily[$i] 	= $v10;
      $one_time[$i] 	= $v11;
      $day[$i]		= $v12;
      $z_1[$i] 		= $v13; 
      $z_2[$i] 		= $v14; 
    }
  }

##############################################
# SECTION 6.2: Compute ac requests, write flags to "ac" table
##############################################

$crt_tm = time;
$today =  strftime "%Y-%m-%d", localtime;

for ($i = 2; $i <= 6; $i++)   # Process Guest Living Master Bdrm2 Office for ac
{
# Check ac schedules, update flags
   if          # any zone asks for heat 
   (
      ($low_temp[$i] < $room_temp[$i])   #zone(i) asks for cold manually 
      or               # zone(i) has schedule1 daily
      (
         ($sched_temp[$i] < $room_temp[$i]) and 
         ($crt_tm > $start_time1[$i]) and 
         ($crt_tm < $end_time1[$i]) and 
         ($daily[$i] == 1) and 
         ($z_1[$i] == 1)
      )   
      or               # zone(i) has schedule1 one time today
      (
         ($sched_temp[$i] < $room_temp[$i]) and 
         ($crt_tm > $start_time1[$i]) and 
         ($crt_tm < $end_time1[$i]) and 
         ($one_time[$i] == 1) and 
         ($today eq $day[$i]) and
         ($z_1[$i] == 1)
      )   
      or               # zone(i) had schedule2 daily
      (
         ($sched_temp[$i] < $room_temp[$i]) and 
         ($crt_tm > $start_time2[$i]) and 
         ($crt_tm < $end_time2[$i]) and 
         ($daily[$i] == 1) and 
         ($z_2[$i] == 1)
      )
      or               # zone(i) has schedule2 one time today
      (
         ($sched_temp[$i] < $room_temp[$i]) and 
         ($crt_tm > $start_time2[$i]) and 
         ($crt_tm<$end_time2[$i]) and 
         ($one_time[$i] == 1) and 
         ($today eq $day[$i]) and
         ($z_2[$i] == 1)
      )
   )

   {			# turn ac on for zone $i
      dosql("update ac set value = 1 where id = $i");
      $h_v[$i-1] = 1; 
   }
else            	# turn ac off
   {
      dosql("update ac set value = 0 where id = $i");
      $h_v[$i-1] = 0; 
   } 
}	# end of process Guest Living Master Bdrm2 Office zones for ac

#####################################################
# SECTION 6.4: Write FAN and AC flags to ac table
#####################################################

if ($h_v[1] + $h_v[2] + $h_v[3] + $h_v[4] +$h_v[5] == 0)# Nobody wants cold
{
   dosql("update ac set value = 0");			# FAN off, AC Unit off
}
else							# Somebody wants cold
{
   dosql("update ac set value = 1 where id = 6"); 	# Set flag for AC fan ON
   dosql("update ac set value = 1 where id = 7"); 	# Set flag for AC Unit ON
}

AC_RELAYS:

##############################################
# SECTION 6.4: Transfer database flags to ac relays
##############################################

# AC Relays control local dampers to each zone.
# Dampers need a few seconds to open.

# AC Relays are connected as follows:
# Guest = out10;        id = 1
# Living = out11;       id = 2
# Master = out12;       id = 3
# Bdrm2 = out13;        id = 4
# Office = out14;       id = 5
# Fan = out15;          id = 6; AC FAN - on before compressor
# AC = out16;           id = 7; AC Unit
# Spare = out17;        id = 8; Spare relay

$sql1 = "select id, value, port, name from ac where value <> lastval";
$qh1 = $dbh->prepare($sql1);
$qh1->execute();
$qh1->bind_columns(undef, \$id, \$value, \$port, \$zone);
while($qh1->fetch()) 
{
   $c = '';
   $b = substr($port, 0, 7) . $value . '~';
   $d = substr($port, 4, 2);
   if($value eq '0') 
   {
      $b = "~in" . $d . "~";
      log_event("Turn OFF AC $zone");
      log_event("Turn OFF AC Fan");
      log_event("Turn OFF AC Unit");
   }
   else
   {
      $b = "~out" . $d . "=0~";
      log_event("Turn ON AC $zone");
      log_event("Turn ON AC Fan");
      log_event("Turn ON AC Unit");
   }
   if($tty_order eq 0)
   {
      io_op2($b);
      $c = $port_out2;
   }
   else
   {
      io_op1($b);
      $c = $port_out1;
   }
   $c = "update ac set lastval = $value where id = $id";
   dosql($c);
}

goto END;	# END OF SUMMER

END:

$port1->close;
$port2->close;

# prepare for next run

$run_counter++;

# save next run count into database

dosql("update run_process set counter = $run_counter");

# unlock the program for next use
dosql("update can_open_port set no = 0");

# write run_process into ha_counter for the watchdog

$file1 = "/home/pi/perl/ha_counter";

open (FILE, ">$file1") or die "Cannot open ha_counter\n";
print (FILE $run_counter);

#system('cat /home/pi/perl/line >> /home/pi/perl/log_file');


#$dbh->commit() or die "Commit error";

#$dbh->disconnect();
