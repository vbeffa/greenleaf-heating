#!/usr/bin/perl

use warnings;
use DBI;
use CGI;

my $DBG = 0;

# Open DB
$db ="mysql";
$pas = $ENV{"GREENLEAF_DB_PASSWORD"} // die "GREENLEAF_DB_PASSWORD must be set";
$db ="ha";
$dbh = DBI->connect("DBI:mysql:$db:localhost", "root", $pas) or die "Could not connect to database: $DBI::errstr"; 
if($DBG eq 1) { print "#Database OK\n"; }

# subrutina executie unei comenzi ce nu returneaza un cursor (la noi UPDATE)
sub dosql 
{ 
   $d = $_[0];
   $dbh->do($d);
   if($DBG eq 1) { printf "   SQL...$d...\n"; }
   return 1;
}

my $qcgi = CGI->new();

#
# tre sa controlez daca e realizat LOGIN; datele se iau din cookies
#
$c1 = $qcgi->cookie("username");
$c2 = $qcgi->cookie("passwd");
if(!$c1)
{
	$c1 = 'guest';
}
if(!$c2)
{
	$c2 = ' ';
}
$c1 = 'marius';
$c2 = '1234';
$qh1 = $dbh->prepare("select count(*) from user where name = '".$c1."' and passwd = '".$c2."' ");
$qh1->execute();
$qh1->bind_columns(undef, \$id1);
$qh1->fetch();
if($id1 != 1)      # nu este un user autentificat
{
   print "Content-type: text/html\n\n";
   exit;
}
# INCEPE PROCESAREA VENITA DIN IN QUERY_STRING
#
#   orice apel http este de forma
#   setAny.cgi?oper=OPERATIE&p1=v1&p2=v2...

my $par = $qcgi->param('oper');

# -------------------------------------------------------------------------------
# ------ senzorii de clima ---- apeluri din heating.html si heating_schedule.html
if($par eq 'heat')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('tip');
   if($p1 eq 's')   # setare temperatura intr-o camera
   {
         my @var = split /~/, $p1;
         for($i = 0; $i < @var.length; $i += 2)
         {
            $r = dosql("update heating set temp=".$var[2 * $i + 1]." where room_id = ".$var[2 * $i]);
         }
         print "Values saved on server";
   }
   elsif($p1 eq 'w')   # setare timpi, starttime,... intr-o camera
   {
         $p2 = $qcgi->param('w');
         my @var = split /~/, $p2;
         $col = 11;
         $lin = 6;
         for($i = 0; $i < $lin * $col; $i += $col)
         {
            $d1 = "update temp set high_temp=$var[$i + 2], start_time1=";
            if($var[$i + 3] eq "")
            {
                  $d1 = $d1."null";
            }
            else
            {
                  $d1 = $d1."'$var[$i + 3]'";
            }
            $d1 = $d1.",end_time1=";
            if($var[$i + 4] eq "")
            {
                  $d1 = $d1."null";
            }
            else
            {
                  $d1 = $d1."'$var[$i + 4]'";
            }
            $d1 = $d1.",start_time2=";
            if($var[$i + 5] eq "")
            {
                  $d1 = $d1."null";
            }
            else
            {
                  $d1 = $d1."'$var[$i + 5]'";
            }
            $d1 .= ",end_time2=";
            if($var[$i + 6] eq "")
            {
                  $d1 = $d1."null";
            }
            else
            {
                  $d1 = $d1."'$var[$i + 6]'";
            }
            $d1 = $d1.", z_1=".$var[$i + 9];
            $d1 = $d1.", z_2=".$var[$i + 10];
            $d1 = $d1.", daily=".$var[$i + 7];
            $d1 = $d1.", one_time=".$var[$i + 8];

            $d1 .= " where id = $var[$i]";
            $r = dosql("$d1");
         }
         print "Values saved on server";
   }
   else
   {
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# setari sprinklere
elsif($par eq 'spr')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('tip');
   $p2 = $qcgi->param('z');
   $p3 = $qcgi->param('v');
   if($p1 eq 'z')   # setare pe ON a unui sprinkler, daca nu mai este altul deja setat
   {
         $qh1 = $dbh->prepare("select sum(value) from sprinkler");
         $qh1->execute();
         $qh1->bind_columns(undef, \$id1);
         $qh1->fetch();
         if($id1 > 1 and $p3 > 0)
         {
            print "KO";
            exit;
         }
         else
         {

            if($p3 eq '1')
            {
	            #dosql("update timer_action set status = 0");
	            dosql("update sprinkler_forced set forced = ".$p2);
	            dosql("update sprinkler set value = 1 where id = ".$p2);
            }
            else
            {
	            dosql("update timer_action set status = 1");
	            dosql("update sprinkler_forced set forced = 0");
	            dosql("update sprinkler set value = 0 where id = ".$p2);
            }

	    $qh1 = $dbh->prepare("select port from sprinkler where id = ".$p2);
            $qh1->execute();
            $qh1->bind_columns(undef, \$port1);
            $qh1->fetch();

            system($port1." $p3") == 0 or die "KO - System failed: $?";
            print "Values saved on server";
            exit;
         }
   }
   elsif($p1 eq 'id')   # setare TIMER
   {
         $p2 = $qcgi->param('id');
#         print "update timer_action set status = $p2, start_time = '$p3'";
         $r = dosql("update timer_action set status = $p2, start_time = '$p3'");
#         if($p3 eq 0)
#         {
#            $r = dosql("update sprinkler set value = 0");
#         }
         print "Values saved on server.";
         exit;
   }
   elsif($p1 eq 's')   # setare parametri executie automata pentru toate sprinkerele din DB
   {
         @var = split(/\|/, $qcgi->param('s'));
         $k = @var;
         $j1 = $k / 18;
         for($i = 0; $i < $j1; $i++)
         {
            $j = $i * 18;
            $s3 = "update sprinkler set man_on=0, run_time=$var[$j + 10], mon=$var[$j + 11], tue=$var[$j + 12], wed=$var[$j + 13], thu=$var[$j + 14], fri=$var[$j + 15], sat=$var[$j + 16], sun=$var[$j + 17] where id = ($i + 1)";
            $r = dosql($s3);
#print "$s3\n";
         }
         print "Values saved on server.";
         exit;
   }
   else
   {
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# setari din climate
elsif($par eq 'clim')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('what');
   $p2 = $qcgi->param('val');
   if($p1 eq 'd')   # stergere user din tabela USER
   {
         $r = dosql("delete from users where id = $p2");
         print "OK";
         exit;
   }
   elsif($p1 eq 'a')   # adaugare user in tabela USER
   {
         $qh1 = $dbh->prepare("select count(*) from users where name = '$p2' and passwd = '$p3'");
         $qh1->execute();
         $qh1->bind_columns(undef, \$id1);
         $qh1->fetch();
         if($id1 eq 0) 
         {
            $r = dosql("insert into users (name, passwd) values ('$p2', '$p3')");
            print "OK";
         }
         else
         {
            print "KO";
         }
         exit;
   }
   elsif($p1 eq 's')   # salvari din heating
   {
         @var = split /~/, $p2;
         $N = @var.length;
	 for($i = 0; $i < $N - 1; $i += 3)
	 {
		$linia = "update temp set high_temp=".$var[$i + 1].", low_temp=".$var[$i + 2]." where id=".$var[$i];
	    	$r = dosql($linia);
#		print $linia."\n";
	 }
         print "Values saved on server";
   }
   elsif($p1 eq 'hav') #turn the heat air valve
   {
	    $qh1 = $dbh->prepare("select port from heat where name='Air_vane'");
		$qh1->execute();
		$qh1->bind_columns(undef, \$port1);
		$qh1->fetch();
		#print("Command: ".$port1." $p2");
		dosql("update heat set value='$p2' where name='Air_vane'");
		
		system($port1." $p2") == 0 or die "KO - System failed: $?";
   }
   elsif($p1 eq 'cav') #turn the cooling air vane
   {
	    $qh1 = $dbh->prepare("select port from ac where name='Air_vane'");
		$qh1->execute();
		$qh1->bind_columns(undef, \$port1);
		$qh1->fetch(); 
		#print("Command: ".$port1." $p2");
		dosql("update ac set value='$p2' where name='Air_vane'");
		
		system($port1." $p2") == 0 or die "KO - System failed: $?";
   }
   else
   {
   }
   print "\n";
   exit;
}
# -------------------------------------------------------------------------------
# setari diverse
elsif($par eq 'set')
{
   print "Content-type: text/html\n\n";
   $p1 = $qcgi->param('tip');
   $p2 = $qcgi->param('id');
   $p3 = $qcgi->param('val');
   if($p1 eq 'd')   # stergere user din tabela USER
   {
         $r = dosql("delete from users where id = $p2");
         print "OK";
         exit;
   }
   elsif($p1 eq 'a_set')   # adaugare user in tabela USER
   {
         @var = split /~/, $p3;
         $r2 = "update settings set celsius=$var[0], fahr=$var[1], mail=$var[2], sms=$var[3], sms_number='$var[4]', heating=$var[5], winter=$var[6], summer=$var[7], cooling=$var[8], email='$var[9]', ac_fan=$var[10]";
         $r = dosql($r2);
		 $r2 = "update rain_delay set enable=$var[11], auto=$var[12], value=$var[13]";
		 $r = dosql($r2);
         print "Values saved on server";
   }
   elsif($p1 eq 'set')   # setari campuri din tabela SETTINGS
   {
         @var = split /~/, $p2;
         $r = dosql("update settings set grade=$var[0], mail=$var[1], sms=$var[2], sms_number='$var[3]', heatind=$var[4], airflow=$var[5]");
         print "OK";
   }
   else
   {
   }
   print "\n";
   exit;
}
else
{
   print "Content-type: text/html\n\n";
   exit;
}
