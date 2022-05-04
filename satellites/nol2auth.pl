#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# ����� L2 �����������
# ---------------------------------------------
$VER=50.33;

use Time::localtime;
use Fcntl qw(:flock);
use Crypt::Rijndael;
use IO::Socket;
use FindBin;
use DBI;

#$ipfw		= '/sbin/ipfw -q ';

$AgentName	= 'nol2auth';
$Mod_id		= 1;	# id ������, 1 - `����� L2 �����������`

$Slap_level=10;		# ������� "���������" ip, ����� �������� ip ����� ������������. ������������� 10
$Slap_noip=5;		# ��������� �� ������� ����������� � ��������������� ip ���� � ip, �� ������������������ �����������
			# ���� ������� $Slap_level/2, �� ����� "�������� ip" ����� ������ 2 ���� (��� ����������), ����� ���� ip ������� � ����� ����

$MaxBlockIpToStat=100;	# � ���������� ����� ������������ ����� ������������ ���������� ��������� ip

$sql_set_character_set="SET character_set_results=cp1251";

# === Start ���������� nosat.pl ====
# ����� ���������, ����������� � ������ ������

$Program_dir=$FindBin::Bin;
$satmod="$Program_dir/nosat.pl";
eval{require $satmod};
if( $@ )
{
   print "Need $satmod!\n";
   exit 1;
}

# === End ���������� nosat.pl ====

$Ip=$c{V_auth_Ip};	# verbose Ip

&Log("====== -  NoDeny L2-auth starting - ======");

$My_server_ip=$c{My_server_ip};
$Server_ip=$My_server_ip? inet_aton($My_server_ip) : INADDR_ANY;
$My_port=$c{My_port};

$proto=getprotobyname('udp');
unless( socket(SOCKET,PF_INET,SOCK_DGRAM,$proto) && bind(SOCKET,sockaddr_in($My_port,$Server_ip)) )
{
   $Exit_reason="������ �������� udp ������. �������� ���-�� �����";
   $Exit_cod=1;
   &Exit;
}

&Debug("������ ��������� ����� �� udp ���� $My_port");

$Ver_client=$c{Ver_client};

$DSNA="DBI:mysql:database=$Db_name;host=$c{Db_server_a};mysql_connect_timeout=$c{Db_mysql_connect_timeouta};";
$dbha='';

# �������� �������� ���� ����������� ����� ����������, ����� ����������� ����� ������������ � �������� ����.
# ������, ������������ ����� ������������ ������� ���������� � ����� �����������.
# ��������� �������� ������ ����� �� �������� ������ �������� ����������� � �� �����������,
# ��� ������ �� ���������� �����������. ������ 0 - ������ ����� ����������� � �� �����������
$t_dbauth_connect=0; 


$t_allowping=0;		# ���������� �����, ����� ����� ���������� ������� �������� ���������� ��������� ����-�����, 0 - ��� ������
$t_stat=0;		# ����� ����� ���������� �������� � ���� ���������� � ���� ������ ������, ������ ��
$t_tarif_load=0;	# ����� ����� ��������� ������ - ��� ��� ����� ���� �������� �������� �����������, 0 - ������ ��
$need_random=0;		# ���� "�������������� ����� ��������� ���������� �������", �������

$Where_grp=$c{Usr_auth_groups}? "AND grp IN($c{Usr_auth_groups})" : '';

# ������ ��� ���������� (�����������)
$t_last_stat=&TimeNow();
%StatUniqueIp=();	# ������� ������� ���������� ip
$StatPackets=0;		# ���������� ������������ �������
$StatFloodPackets=0;	# ����� ���������� ������� ������������ ��� ����

# ������ ��� ���������� �����������
#system("$ipfw table 127 flush"); 

while(1)
{
  select(undef,undef,undef,0.05); # ����� � ������� ������

  &TarifReload if &TimeNow()>$t_tarif_load;

  # �����������
  &AUTH;

  $t=&TimeNow();
  
  &SendAgentStat if $t_stat<$t; # ���� �������� ���������� � ���� ������

  # ��������, ����� ���� ���� ���������� � ����� (������ �����������!)
  foreach $ip (keys %Block)
  {
      next if $Block_ip_time{$ip}>$t;
      &Unblock_ip($ip);
  }

  $Exit_reason && last;
}

&Exit;

sub DbConnect
{
 $dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>0});
 $dbh && return;
 my $t=&TimeNow();
 # ���� ��������� ������ ���������������� ������ ������ �����, �� � ���� �� �����
 return if $t<($When_db_error_last+60) && !$V;
 $When_db_error_last=$t; 
 &Log("������ ���������� � �������� ��! ������ �������� �� �����������!");
}

sub RunServerCommand
{
}

# ================================================================
# �������� ������ �������
# ����: ip
# �����: �������������� ������ $U{ip}.{'xxx'}
# ================================================================
sub Get_user_data
{
 my $ip=shift;
 my ($sql,$sth,$p,$id,$mid,$pass,$name,$tm); 
 my $tm=int $U{$ip}{last_got_info}; 

 return if defined($U{$ip}{passwd1}) && $t<($tm+$c{T_get_new}); # ������� ����� ������ ��������� ������, ����� ������������� � �������� ������ ��

 if( $t>($tm+$c{T_get_old}) )
 {  # ������ ��������, ������� ������ ������� ������������� ������� ������ �.�. ����� ����� ���� ������ �������� � �.�.
    # ������� �� ��� ����, ��������� ��������� � �.�.
    $tm && &Debug("=== ��������� ��� ���������� � ������� (id=$id) ���� �������� ��� �����, ��� �� �� �������. ���� ������ �� ����� �������� ������ �������, �� ��� ����� ����������, ��� ������ ip � ���� ������ ���");
    delete $U{$ip}{passwd1};
    delete $U{$ip}{passwd2};
    delete $U{$ip}{passwd3};
    delete $U{$ip}{passwd4};
    delete $U{$ip}{id};   
    delete $U{$ip}{admin};
    delete $U{$ip}{state};
    delete $U{$ip}{auth};
    delete $U{$ip}{startmoney};
    delete $U{$ip}{packet};
    delete $U{$ip}{submoney};
    delete $U{$ip}{traf1};
    delete $U{$ip}{traf2};
    delete $U{$ip}{traf3};
    delete $U{$ip}{traf4};
    delete $U{$ip}{mess_time};
    delete $U{$ip}{rnd_str};
    delete $U{$ip}{id_query};
 } 

 $U{$ip}{cannot_get_info}=1; # ���� �������� �������, ��� �� ����� �������� ���� ���� �� ������ � ���� ��� ��� ������

 if( !$dbh )
 {
    &DbConnect;
    $dbh or return;
 }

 $sql="SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM $c{Db_usr_table} WHERE ip='$ip' $Where_grp LIMIT 1";
 $sth=$dbh->prepare($sql);
 if(! $sth->execute )
 {  # �������� �������� ���������� � mysql ��������. ���������������
    &DbConnect;
    $dbh or return;
    $sth=$dbh->prepare($sql);
    $sth->execute or return; # $dbh �� �������� - ��������� ������������ execute ������� �����������
 }

 $U{$ip}{cannot_get_info}=0;

 unless( $p=$sth->fetchrow_hashref )
 {
    &Debug("=== ������� � ip $ip ��� � ���� ������. ��� ����, ���� ������ ��� � ���� �����, �� �� ������� ���������� � ��� � ���������� - ".
      "���� ������ ������������� ������ ���������� ����� ������� �� ��������. ��� ������ �� ��������� ������ ��� ������ � ��������� ��");
    return;
 }

 $U{$ip}{last_got_info}=$t; # �������� ����� �������� ���� � �������

 $ip=$p->{ip};
 $id=$p->{id};

 if ($p->{lstate})
 {   # ����������� ���������
     $U{$ip}{passwd1}='';
     $U{$ip}{passwd2}='';
 }
  else
 {   # �������� ������ �� 2 �����: ���� ��� ������� ����������� ��������, ������ ��� ������.
     # ������ ������ ���� ������ 16 ���� (�������� ��������� 'Z' � '0')
     $pass=$p->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
     $U{$ip}{passwd2}=substr(substr($pass,0,3).'Z' x 16,0,16);
     $U{$ip}{passwd1}=substr($pass.'0' x 19,3,16);
     # ��� ����������� �����+������+ip
     $name=$p->{name};
     $U{$ip}{passwd4}=substr($pass.'Z' x 16,0,16);
     $U{$ip}{passwd3}=substr($name.'0' x 19,0,16);
 }

 $id_to_ip{$id}=$ip;

 $U{$ip}{id}=$id;   
 $U{$ip}{admin}=$p->{contract} eq 'adm'; # �����? 
 $U{$ip}{state}=$p->{state};
 $U{$ip}{auth}=$p->{auth};

 $mid=$p->{mid}||$id;

 # ������� ������ �� ������� � ������� � ������� users_trf
 $sth=$dbh->prepare("SELECT * FROM users_trf WHERE uid=$mid LIMIT 1");
 if ($sth->execute && ($p=$sth->fetchrow_hashref))
 {
    $U{$ip}{submoney}=$p->{submoney};
    $U{$ip}{packet}=$p->{packet};
    $U{$ip}{traf1}=$p->{traf1};
    $U{$ip}{traf2}=$p->{traf2};
    $U{$ip}{traf3}=$p->{traf3};
    $U{$ip}{traf4}=$p->{traf4};
    $U{$ip}{mess_time}=$p->{mess_time};
    $U{$ip}{startmoney}=$p->{startmoney};
 }
  else
 {
    $U{$ip}{traf1}=$U{$ip}{traf2}=$U{$ip}{traf3}=$U{$ip}{traf4}=0;
    $U{$ip}{mess_time}=$U{$ip}{startmoney}=$U{$ip}{submoney}=$U{$ip}{packet}=0;
 }
}

# ================================================================
# ��������� ������ � ����������� �� ������ ��������
# ����: ip
sub Block_ip
{
 my $ip=shift;
 return if $Block{$ip};
 #system("$ipfw table 127 add $ip");
 $Block{$ip}=1;
}

# ================================================================
# ������������ ������ � ����������� �� ������ ��������
# ����: ip
sub Unblock_ip
{
 my $ip=shift;
 return unless $Block{$ip};
 #system("$ipfw table 127 delete $ip");
 &Debug("��� $ip �������������� ����������� � ��������");
 delete $Block{$ip};
 $Count_flood_packets{$ip}=0;
}

# ================================================================
sub Slap_Ip
# ����: ip, ������� ���������
# ������������ ��������� � ������ ���������� ��������� ������� ���������
# � ���� ������ ��������� ������ �����������, �� ip �������� �� $T_usr_block ���
{
 my ($ip,$slap)=@_;
 # $Block_ip_time{$ip} ��������� ������� �������:
 #  - ������� ���������, ����� �������� ����� ������ 1000
 #  - �����, �� �������� ����� �������� ����� ������� �� $ip
 # ���� ����� ������ ip ��� ������������, �� ������� ������� ���������
 $Block_ip_time{$ip}=0 if $Block_ip_time{$ip}>1000;
 $Block_ip_time{$ip}+=$slap;
 &Debug("$ip ������������ �� $slap �������. � ������ ������ � ���� $Block_ip_time{$ip} �������. ��� ���������� $Slap_level ������� � �����-���� �� $c{T_usr_block} ���");
 if( $Block_ip_time{$ip}>=$Slap_level )
 {
    &Debug("$ip ����� � �����-���� �� ����� $c{T_usr_block} ���");
    $Block_ip_time{$ip}=&TimeNow()+$c{T_usr_block};
    $Error_auth_count{$ip}=0; # ������� ������� ��������� �����������
 }
}

# ================================================================
#                          �����������
# ================================================================
sub AUTH
{
 my ($hispaddr,$addr,$port,$send,$id,$txt,$i,$ver,$cipher);

 my $rin='';
 vec($rin,fileno(SOCKET),1)=1;
 while (select($txt=$rin,undef,undef,0)) # ������� 0 ������
 {
    $t=&TimeNow();
    $txt='';
    $hispaddr=recv(SOCKET,$txt,100,0); # ���������� ���, ��� � ������� �� 100� ������
    ($port,$addr)=sockaddr_in($hispaddr);
    $ip=join(".",unpack("C4",$addr));
    if( $ip eq '127.0.0.1' || $ip eq $My_server_ip )
    {  # ������� �� �������
       &RunServerCommand($txt);
       next;
    }

    $StatUniqueIp{$ip}++; # ������� ������������ ip
    $StatPackets++; # ���������� ������������ �������

    if( $Block_ip_time{$ip}>$t )
    {  # ����� ���� ��� �� �����
       $StatFloodPackets++; # ��� ���������� ����� ���������� ������� ������������ ��� ����
       next if $Block{$ip}; # �� ������ ���� � ����� �� ���������, ����� ���� ������������
       &Debug("����� �� $ip, ���� ip � �����-����� ��-�� '���������'. �������� �� �����-����� ����� ".($Block_ip_time{$ip}-$t)." ���");
       if( $Count_flood_packets{$ip}++==50 )
       {   # ����������� ����, ������ ������ � ��������
           &Debug("����������� ���� �� ������� $ip, ��������� ������ � ��������");
           &Block_ip($ip);
           # � ������� �������� � ���� nodeny ��� �������� ����, ���� ������ �������� �� ��� ��������
       }
       next;
      }

    $Count_flood_packets{$ip}=0;

    &Debug("=== ����� �� $ip");

    # ��������� ����� ��� ������ (��� ����� ����������!)
    $addr=inet_aton($ip);
    $hispaddr=sockaddr_in($My_port,$addr);

    # �������� ���� �� � ���� ����� ip � ������� ��� ������, ���� ����
    &Get_user_data($ip);

    # ���� ������ ����������� - � ���� ��� ������ ip
    # ���� ������ ������ - ����������� ��������� ��� �������� ip
    if(! $U{$ip}{passwd1} )
    {
       next if $U{$ip}{cannot_get_info}; # �� ���� ip �� �� ������ �������� ���� (��������: �� ������ �� ����� ���� �� �� � ����),
					   # ������� �� �� ����� ��� ������ ��������, ���������� � ������� ��� �� ������������ �� ��������� ������
       &Debug(defined($U{$ip}{passwd1})? "��� $ip ��������� �����������. �������� ��������� '�������� �����'" : "$ip ����������� � ���� ������!");
       send(SOCKET,'eri',0,$hispaddr); # ������� ��������� "� ���� �� ��� ip"
       &Slap_Ip($ip,$Slap_noip); # �������
       next;
    }

    # �������� ������� ��������� �����������, ��� ������ �� �����, ��� ������� ����������� �� ���������
    if( $Error_auth_count{$ip}++>10 )
    {  # ������� ����� ��������� �����������
       &Debug("��� $ip ��������� ������ �� ��������� �����������");
       &Slap_Ip($ip,$Slap_level); # ������� �� ��������� �.� ����� ip ����� � ����� ����
       send(SOCKET,'erw',0,$hispaddr); # ������� �������� ������� �� ������� ������
       next;
    }

    # �������� ������ �� ������������ ��������� ������?
    if( length($txt)<16 )
    {
       # ���������� ��������� ������ ��� �����������
       my $str=substr(rand().rand().'errorinlastline',2,16);
       # id ������ ��������� ��������� �������, � � ��� ������ �����, ������� ���������
       $str=new Crypt::Rijndael $str,Crypt::Rijndael::MODE_CBC;
       $str=$str->encrypt(substr(rand().rand().'qazxswedcvfrtgbn',2,16));
       $str=~s/,/-/g; # ����������� "�������" ����� ���������� � �����, ������ �� ������ ������
       $U{$ip}{rnd_str}=$str;
       $U{$ip}{id_query}=$txt; # �������� id �������
       # ����������� �����+������+ip ��� ������+ip ?
       my $type_auth=substr($txt,2,1) eq 'a';
       $send=$type_auth? $U{$ip}{passwd4} : $U{$ip}{passwd2};
       $send=new Crypt::Rijndael $send,Crypt::Rijndael::MODE_CBC;
       $send='id'.($send->encrypt($str)).$txt; # ��������� ��������� ������ ��������� �������
       send(SOCKET,$send,0,$hispaddr);
       &Debug("������ �� �����������. ��� �����������: ".($type_auth?'�����+������+ip':'������+ip').". ID �������=$txt. ������������� ���� ������ � �����");
       next;
    }

    # 2� ������ ����������� - �������� ����� � ���������� ������ �� �����������

    if(! $U{$ip}{rnd_str})
    {
       &Debug("����� �� $ip, �� ������� �� ����������� �� ����. ����������");
       &Slap_Ip($ip,2); # ������� �� 2 ������ 
       next;
    }

    $ver=int(substr $U{$ip}{'id_query'},0,2); # ������ ������������
    $ver=1 if $ver<1 || $ver>255;

    # ����������� �����+������+ip ��� ������+ip ?
    $cipher=substr($U{$ip}{id_query},2,1) eq 'a'? $U{$ip}{passwd3} : $U{$ip}{passwd1};
    $cipher=new Crypt::Rijndael $cipher,Crypt::Rijndael::MODE_CBC;
    $decrpt=$cipher->decrypt(substr $txt,0,16);
    my $str=$U{$ip}{rnd_str};
    my $rnd=$str; # ������������ ��������� ������, � $str ����� ����� ��������� (������ ������ ������������)
    $ClientAnswer=''; # ����� ������� �� �������������� ������� ���������� ��������
    my ($orig_com,$com);
    if( length($txt)==16 )
    {  # ������ �������� (������� ����� ������������� ���������)
       $orig_com=substr $decrpt,0,1;
       $com=$orig_com;
       $decrpt=substr $decrpt,1,15; # �.�. ������ ������ ��� ������� �� �������
       $str=substr $str,1,15;
       $id='';
    }else
    {
       $orig_com=substr $txt,16,1;  # ������� �������
       $com=lc($orig_com);
       $id=length($txt)<18 ? '' : substr $txt,17,length($txt)-17; # id ������
       ($id,$ClientAnswer)=($1,$2) if $id=~/^(.+?)\|(.+)$/;
    }

    if( $id ne $U{$ip}{id_query} )
    {  # id �� �� ������ ������
       &Slap_Ip($ip,1); # ������� �� 1 �����
       next;
    }

    $U{$ip}{rnd_str}=''; # ������ �� ���� ������ �������������� ����� ������

    if( $decrpt ne $str )
    {   # ��������� �����������
        send(SOCKET,"no$U{$ip}{'id_query'}",0,$hispaddr); # �.�. ����� 'no'+$zapros2 <>16, �� ������ ������� �� ����� ������������ ��� ��� ������ ��� ����������
        &Debug("2� ��� �����������. ��������� �����������");
        &Slap_Ip($ip,5); # ������� �� 5 �������
        next;
    }

    # --- ����������� ������ ������� ---
    &Debug("2� ��� �����������. ����������� �������. ����� �����������: $com");

    # ����� ����������

    #if( $Error_auth_count{$ip}>10 )
    #{   # ��������� ����������� ���� �������, �� �� ����� ���� ����� ��������� �������
    #    send(SOCKET,"no$U{$ip}{'id_query'}",0,$hispaddr); # �.�. ����� 'no'+$zapros2 <>16, �� ������ ������� �� ����� ������������ ��� ��� ������ ��� ����������
    #    if( $decrpt ne $str )
    #    {
    #       &Debug("2� ��� �����������. ����������� �������, �� �.� �� ����� ���� ����� ��������� ������� �� ���� ��� ������� ���, ".
    #              "��� ����������� �� �������. ���� $ip �� ���������� ������, �� � ��������� ������� ������������") if $V;
    #       $Error_auth_count{$ip}=0;
    #       next;
    #    }

    # �������� ������� ������������ �������
    $Error_auth_count{$ip}=0;

    # ����� $com =
    # a - ������ �� ��������� ������� �������
    # b - ������ �� ������������ �������
    # c - ������ �� ��������� ������� � ����� 2 �����������
    # e - ������ �� ��������� ������� ������� � �������� ��������� ����������

    # ���� ������ ������� ������ � ������� �������� - ������ �� �������� ������� � ������� (� ����� ������������� ������ ������ ������ �����������)
    if( $com ne $orig_com )
    {
       $send='go';
       $str=$U{$ip}{id_query}.'|';
       $str.=' ' x 16;
       if( $U{$ip}{ask_com} )
       {  # ���� �� �������� �����, ����� ���������� ������ ���� ��� �������� �������. �� ������� ������� ������� ��������� �� �������������, �������
          # � ���� ��� ��������� ���������� ����� ������ ���� ��������
          $Block_ip_time{$ip}=&TimeNow()+8;
       }
        else
       {
          $Block_ip_time{$ip}=0; # ������� ������ ���������
          $U{$ip}{ask_com}=1; # ���� '���� ��������� ������� � �������'
       } 
    }
     else
    {     
       # ��������. �.�. ������� ����������� �������� ������ ������������ �������, ������������� ����� ������ ������� ���������� ����������� 
       #(������������� ����� ������ ��-�� ��������� �������), ���� ������� ���������� ����������� � ������� ����� ������� (������������� ����� ����),
       # ������� �� ��������� ���������� ������� �������� $ip � ����� ���� :) �.� ��� ������� ������ �����������.
       # ����� ���������� ������� ��� ����� ������������ ����� ������ ������� ���� ������� ������� �����������, ������ ��� ��������� ������ �.�
       # �� �� ����� ������� �� ������ ��������� ����� (������� ������� ��� �������� �� ������ � ��������). ���� �� ������ �� ������� ��������� �����,
       # �� �� ����� �������� ���������������� ������ 5 ������, � ����� �� ��������� ������.
       # ��������� ����� �� ������ ���������: ���� � ������ � ���� ������, �� ��� ���������

       $Block_ip_time{$ip}=&TimeNow()+8;

       $U{$ip}{ask_com}=0;

       # 2 ������ ����� �������� ���� ������� "���� ��������"
       $t_allowping=$t+120 if $com eq 'e' && $U{$ip}{admin};

       # $cod - ������������ ��������� ������������
       # 5 - ���� ������ ������ � ���� ������
       my $cod=$U{$ip}{state} eq 'off'? 5 : $com;
       # ���� ������ ��� ����� �� ����������� ������� � � ���� ���� ������� �� ������ ������, �� ������� ������������
       $cod=int $U{$ip}{auth} if $U{$ip}{auth}>0 && $U{$ip}{auth}<10;

       if( $v )
       {
          &Debug("������ $ip ������ �� ������� ���������� �������") if $cod==1;
          &Debug("������ $ip ������ �� ������� �������� �������������") if $cod==2;
          &Debug("������ $ip ������ �� ������� ����������� ������� �� ������� �����") if $cod==4;
          &Debug("������ $ip ������������ � ���� ������") if $cod==5;
          &Debug("������ ��� �� ������������ �� ����������� $ip � ���� ������� ����������������. ������� ������� ���� �������, ��� ����� ����������� ������������� �� �����������") if $U{$ip}{'auth'} eq 'no';
       }

       $cod=3 if $Ver_client>$ver; # ��� "������ ������������ ��������" ������������ ��������� ���������
       # cod2 = 2 - �������� ������� ������������������ ����� ��������� ���������� �������
       my $cod2=$t_allowping>$t? '1' : $need_random? '2' : '0';
       $mess_time=int $U{$ip}{'mess_time'};
       $send=$U{$ip}{admin}? 'sv' : 'ok'; # 'sv' ��������� �������� "�����" � ������������

       if( $ver<25 )
       {# ������ ������ ������������
          $str="$U{$ip}{id_query},$cod$cod2,$U{$ip}{traf1},$U{$ip}{traf2},$U{$ip}{submoney},$U{$ip}{startmoney},0.-999999!$mess_time#";
       }else
       {
          $i=$U{$ip}{packet};
          $str="$U{$ip}{id_query},$cod,$cod2,$U{$ip}{traf1},$U{$ip}{traf2},$U{$ip}{traf3},$U{$ip}{traf4},$U{$ip}{submoney},$U{$ip}{startmoney},$mess_time";
          $str.=",$Tarif{$i}{1}";
          $str.=",$Tarif{$i}{2}";
          $str.=",$Tarif{$i}{3}";
          $str.=",$Tarif{$i}{4},";
       }
       $str.='.'.' ' x 15;
    }

    $cipher=new Crypt::Rijndael $rnd,Crypt::Rijndael::MODE_CBC;
    while( length($str)>15 )
    {
       $send.=$cipher->encrypt(substr $str,0,16);
       $str=substr $str,16,length($str)-16;
    }
    send(SOCKET,$send,0,$hispaddr);

    # ������� � ����, ��� ������ �������������
    my $act=$com eq 'a'? 10 : $com eq 'c'? 11 : 12; # ��� �����������

    my $sql="INSERT INTO dblogin set mid=$U{$ip}{id},act=$act,time=unix_timestamp()";

    my $rows;
    if( $dbha )
    {  # ���� ���������� � ����� �����������
       $rows=$dbha->do($sql);
       $rows==1 && &Debug("����������� �������� � ���� �����������");
       $rows==1 && next;
    }

    # �������� ��� ���������� � ����� ������������
    if( $t_dbauth_connect>&TimeNow() )
    {  # ���� ������ ������������� ���������� � ����� ����������� - ������ �� ������ ���������
       # ������� ������� � �������� ����
       $dbh->do($sql) if $dbh;
       next;
    }

    # ������� ����������� � ����� �����������
    $dbha=DBI->connect($DSNA,$Db_user,$Db_pw,{PrintError=>0});
    next if $dbha && ($rows=$dbha->do($sql)) && $rows==1;
    # �� ���������� ��������, ������� � �������� ����
    $dbh->do($sql) if $dbh;
    $t_dbauth_connect=&TimeNow()+15; # 15 ������ �� ����� �������� ����������� � ����� �����������
    &Debug("����������� �������� � �������� ���� �.�. �� ���������� �������� � ���� �����������");
 }
}


# ========================================================================
#             �������� �������� ����������� � �������
# �������:
#  ������ $Tarif{$id}{$class} = '�������� �����������',
#         ��� $id - id ������, $class - ����� ����������� (1..4)
# ========================================================================
sub TarifReload
{
 my ($sth,$sql,$p,$id,$preset);
 $t_tarif_load=&TimeNow()+600; # ��������� ��������� ����� 10 ����� 

 $V=$v; # verbose
 if( $dbh )
 {
    &DbConnect;
    $dbh or return;
 }

 $dbh->do($sql_set_character_set);

 # ������� �������� ����������� � ��������
 $sql="SELECT * FROM nets WHERE priority=0 AND class IN (1,2,3,4)";
 $sth=$dbh->prepare($sql);
 if(! $sth->execute )
 {  # �������� �������� ���������� � mysql ��������. ���������������
    &DbConnect;
    $dbh or return;
    
    $dbh->do($sql_set_character_set);
    $sth=$dbh->prepare($sql);
    $sth->execute or return;
 }
   
 while( $p=$sth->fetchrow_hashref )
 {
    $PresetName{$p->{preset}}{$p->{class}}=$p->{comment};
 }
 
 $sth=$dbh->prepare("SELECT id,preset FROM plans2");
 $sth->execute or return;
 while( $p=$sth->fetchrow_hashref )
 {
    $id=$p->{id};
    $preset=$p->{preset};
    $Tarif{$id}{1}=$PresetName{$preset}{1}||'';
    $Tarif{$id}{2}=$PresetName{$preset}{2}||'';
    $Tarif{$id}{3}=$PresetName{$preset}{3}||'';
    $Tarif{$id}{4}=$PresetName{$preset}{4}||'';
    $Tarif{$id}{1}=~s/,//g; # �.�. � ��������� ������ ������� - �����������
    $Tarif{$id}{2}=~s/,//g;
    $Tarif{$id}{3}=~s/,//g;
    $Tarif{$id}{4}=~s/,//g;
    &Debug("��� ������ $id �������� �����������:\n".
      "   1: $Tarif{$id}{1}".
      "   2: $Tarif{$id}{2}".
      "   3: $Tarif{$id}{3}".
      "   4: $Tarif{$id}{4}");
 }
}

# =========================================
#      ������ ���������� � ���� ������
# =========================================
sub SendAgentStat
{
 $t_stat=$t+$ReStat; # ����� ��������� ����������
 
 my ($ip,$ip_list,$n);
 my $set='';
 $set.=($t-$t_last_stat).'|'; # ����������������� ����� �����������
 $t_last_stat=$t;
 $set.=scalar(keys %StatUniqueIp).'|'; # ���������� ip �� ���� �����������
 %StatUniqueIp=();
 $set.="$StatPackets|$StatFloodPackets|";
 $StatPackets=0;
 $StatFloodPackets=0;
 # ��������� ip, ������� �������� ������ ��� �� 10 ������ (�� ������ �.�. ����� ������� ����������� ip ������� �� ��������� ������)
 $n=0;
 foreach $ip (%Block_ip_time)
 {
    next if $Block_ip_time{$ip}<($t+10);
    $ip_list.="$ip," if $n<$MaxBlockIpToStat;
    $n++;
 }
 $ip_list=~s/,$//;
 $set.="$n\n";
 $set.="$ip_list\n";
 &SaveSatStateInDb($set,0);
}




