#!/usr/bin/perl

# getAny.pl


use warnings;
use DBI;
use CGI;

my $DBG = 0;	# debug mode: set to 1 to print error messages

# Open DB
$db ="mysql";
$pas = $ENV{"GREENLEAF_DB_PASSWORD"} // die "GREENLEAF_DB_PASSWORD must be set";
$db ="ha";
$dbh = DBI->connect("DBI:mysql:$db:localhost", "root", $pas) or die "Content-type: text/html\n\nCould not connect to database: $DBI::errstr";
if($DBG eq 1) { print "#Database OK\n"; }

my $qcgi = CGI->new();

# INCEPE PROCESAREA VENITA DIN IN QUERY_STRING
#
#   orice apel http este de forma
#	getAny.cgi?oper=OPERATIE&p1=v1&p2=v2...

my $par = $qcgi->param('oper');

# -------------------------------------------------------------------------------
# ------ senzorii de miscare ---- apeluri din security.html
if($par eq 'pir')
{
   print "Content-type: text/html\n\n";
   $qh1 = $dbh->prepare("select id, value from sensor order by 1");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id11, \$val11);
   while($qh1->fetch()) 
   {
      print "$id11~$val11~";
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# ------ senzorii de clima ---- apeluri din heating.html
elsif($par eq 'heat')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('tip');
   if($p1 eq 'q')
   {
      $qh1 = $dbh->prepare("select id, value, high_temp, start_time1, end_time1, start_time2, end_time2, daily, one_time, z_1, z_2 from temp where id in (2,3,4,5,6,9) order by id");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4, \$id5, \$id6, \$id7, \$id8, \$id9, \$id10);
      while($qh1->fetch()) 
      {
         print "$id1~$id2~$id3~$id4~$id5~$id6~$id7~$id8~$id9~$id10~";
      }
   }
   if($p1 eq 'h')
   {
      $qh1 = $dbh->prepare("select id, value, high_temp, start_time1, end_time1, start_time2, end_time2, daily, one_time, z_1, z_2 from temp where id in (2,3,4,5,6,9) order by id");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4, \$id5, \$id6, \$id7, \$id8, \$id9, \$id10, \$id11);
      while($qh1->fetch()) 
      {
         print "$id1~$id2~$id3~$id4~$id5~$id6~$id7~$id8~$id9~$id10~$id11~";
      }
   }
  elsif($p1 eq 'sp')
   {
      $qh1 = $dbh->prepare("select value from temp where id not in (2,3,4,5,6) order by name");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1);
      while($qh1->fetch()) 
      {
         print "$id1~";
      }
   }
   else
   {
      $qh1 = $dbh->prepare("select id, value, high_temp from temp where id in (2,3,4,5,6) order by id");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1, \$id2, \$id3);
      while($qh1->fetch()) 
      {
         print "$id1~$id2~$id3~";
      }
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# ------ aspersoare ---- apeluri din irrigation.html
elsif($par eq 'spr')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('tip');
   if($p1 eq 'a')
   {
      $qh1 = $dbh->prepare("select id, substr(name, 1, 1) name, value, position from sprinkler order by id");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4);
      while($qh1->fetch()) 
      {
         print "$id1|$id2|$id3|$id4|";
      }
   }
   elsif($p1 eq 's')
   {
      $qh1 = $dbh->prepare("select id, name, value, '' as time, port, position, io_card, op, lastval, man_on, run_time, mon ,tue, wed, thu, fri, sat, sun from sprinkler order by id");

      $qh1->execute();
      $qh1->bind_columns(undef,\$id1,\$id2,\$id3,\$id4,\$id5,\$id6,\$id7,\$id8,\$id9,\$id10,\$id11,\$id12,\$id13,\$id14,\$id15,\$id16,\$id17,\$id18);
      while($qh1->fetch()) 
      {
         print "$id1|$id2|$id3|$id4|$id5|$id6|$id7|$id8|$id9|$id10|$id11|$id12|$id13|$id14|$id15|$id16|$id17|$id18|";
      }
   }
   elsif($p1 eq 'r') #rain delay
   {
	   $qh1 = $dbh->prepare("select enable, auto, value, rain_level, level_th from rain_delay");

      $qh1->execute();
      $qh1->bind_columns(undef,\$id1,\$id2,\$id3,\$id4, \$id5);
      if($qh1->fetch()) 
      {
         print "$id1|$id2|$id3|$id4|$id5|";
      }
   }
   else
   {
      $qh1 = $dbh->prepare("select * from timer_action");
      $qh1->execute();
      $qh1->bind_columns(undef, \$id1, \$id2);
      if($qh1->fetch()) 
      {
         print "$id1|$id2|";
      }
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# ------ setari useri si variabile ---- apeluri din setting.html
elsif($par eq 'set')
{
   print "Content-type: text/html\n\n";
   $qh1 = $dbh->prepare("select * from settings");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4, \$id5, \$id6, \$id7, \$id8, \$id9, \$id10, \$id11);
   while($qh1->fetch()) 
   {
      print "$id1~$id2~$id3~$id4~$id5~$id6~$id7~$id8~";
   }
   $qh1 = $dbh->prepare("select * from user order by 1");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1, \$id2, \$id3);
   while($qh1->fetch()) 
   {
      print "$id1~$id2~";
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# ------ logare ---- apeluri din _home.html
elsif($par eq 'log')
{
   $p1 = $qcgi->param('u');
   $p2 = $qcgi->param('p');
   $qh1 = $dbh->prepare("select * from user where name = '$p1' and passwd = '$p2' ");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1, \$id2, \$id3);
   if($qh1->fetch()) 
   {
      my @cookie = [ $qcgi->cookie(-name=>'username', -value=>"$p1", -expires=>'', -path=>'/'), 
         $qcgi->cookie(-name=>'passwd', -value=>"$p2", -expires=>'', -path=>'/'), 
         $qcgi->cookie(-name=>'loginok', -value=>"1", -expires=>'', -path=>'/') ];
      print $qcgi->header( -type => "text/html", -cookie => @cookie );
      print "_cefac.html";
   }
   else
   {
      print "Content-type: text/html\n\n";
      print "Login error - ERR #4\n";
   }
   exit;
}
# -------------------------------------------------------------------------------
# ------ send email ---- apeluri din contact.html
elsif($par eq 'email')
{
   $p1 = $qcgi->param('u');
   $p2 = $qcgi->param('p');
   exit;
}
# ------------------------------------------------------------------------------
# ------ starea comenzilor facute din camere
elsif($par eq 'arrows')
{
   print "Content-type: text/html\n\n";
   $zr = '';
   $qh1 = $dbh->prepare("select value from heat where id in (2,3,4,5,6) order by id");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1);
   while($qh1->fetch())
   {
      $zr .= $id1 . ',';
   }
   $qh1 = $dbh->prepare("select value from ac where id in (2,3,4,5,6) order by id");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1);
   while($qh1->fetch())
   {
      $zr .= $id1 . ',';
   }
   $qh1 = $dbh->prepare("select value from heat where name='Boiler'");
   $qh1->execute();
   $qh1->bind_columns(undef, \$id1);
   $qh1->fetch();
   $zr .= $id1 . ',';
   print $zr."\n";
   exit;
} 
# ------------------------------------------------------------------------------
# ------ climate.html
elsif($par eq 'clim')
{
   $p1 = $qcgi->param('what');
   print "Content-type: text/html\n\n";
   if($p1 eq 'setari')
   {
     $zr = '';
     $qh1 = $dbh->prepare("select celsius, fahr, mail, sms, sms_number, heating, winter, summer, cooling, email, ac_fan from settings");
     $qh1->execute();
     $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4, \$id5, \$id6, \$id7, \$id8, \$id9, \$id10, \$id11);
     $qh1->fetch();
	 
	 $qh1 = $dbh->prepare("select enable, auto, value from rain_delay");
     $qh1->execute();
     $qh1->bind_columns(undef, \$id12, \$id13, \$id14);
     $qh1->fetch();
	 
     $zr .= $id1 . '~'.$id2 . '~'.$id3 . '~'.$id4 . '~'.$id5 . '~'.$id6 . '~'.$id7 . '~'.$id8 . '~'.$id9 . '~'.$id10 . '~' .$id11 . '~'.$id12 . '~'.$id13 . '~' .$id14 . '~';
#
#		sprintf(lin, "select * from user order by 1");
#		SQL_Query(lin, SQLbuf, pfields);
#		for(i = 0; i < rows_in; i++)
#			printf("%s~%s~", pfields[3 * i], pfields[3 * i + 1]);
     print $zr."\n";
     exit;
   }
   elsif($p1 eq 'temp')
   {
     $zr = '';
     $qh1 = $dbh->prepare("select id, value, high_temp, low_temp from temp where id in (2,3,4,5,6,9) order by id");
     $qh1->execute();
     $qh1->bind_columns(undef, \$id1, \$id2, \$id3, \$id4);
     while($qh1->fetch())
     {
        $zr .= $id1 . '~'.$id2 . '~'.$id3 . '~'.$id4 . '~';
     }
     print $zr."\n";
     exit;
   }
   elsif($p1 eq 'tp')
   {
     $zr = '';
     $qh1 = $dbh->prepare("select value from temp where id not in (2,3,4,5,6,9) order by name");
     $qh1->execute();
     $qh1->bind_columns(undef, \$id1);
     while($qh1->fetch())
     {
        $zr .= $id1 . '~';
     }
     print $zr."\n";
     exit;
   }
}
elsif($par eq 'rain')
{
	
}
else
{
   print "Content-type: text/html\n\n";
   exit;
}


