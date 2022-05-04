#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$PR{106} or &Error('������ ��������.');

$Fact=$F{act};

# ������� ������: 1� ������������, 2�
%subs=(
 'sat_list'	=> \&sub_zero,	# ������ ���������� � ����� �������� �����������
 'sat_stat'	=> \&sub_zero,	# ���������� �� ����������� ������
 'sat_dstat'	=> \&sub_zero,	# ��������� ���������� �� ���� �� ����������� ������
 'sat_help'	=> \&sub_zero,
 'kernel_stat'	=> \&sub_zero,	# ���������� ���� NoDeny
);


sub ShowMenu
{
 $OUT.="<table class='width100 pddng'><tr><td valign=top class=nav2 width=16%>".&Mess3('row2',
  &ahref("$scrpt&act=sat_list",'����������').
  &ahref("$scrpt&act=kernel_stat",'����. ���������� �������').
  &ahref("$scrpt&act=kernel_stat&mode=1",'����. ������ sql').
  &ahref("$scrpt&act=sat_help",'������')).
 "</td><$tc valign=top><br>";
}

$tend='</td></tr></table>'.$br2;


$Sat_t_monitor=int $Sat_t_monitor; # ������ ������� � �����, � ������� �������� ����� ����������� ������ �� ����������� ����������
$Sat_t_monitor=8 if $Sat_t_monitor<1; 
$Sat_t_monitor*=3600; # ��������� � �������

$Sat_t_no_ping=((int $Sat_t_no_ping)||11)*60; # ��������� � ������� �����, ����� �������� ���� �� ����� ������ �� �����������, �� ���������������� ������ ������� ������� ������

$height_line=6; # ������ � �������� ��������, ������������ ������� �����������

$Fact='sat_list' unless defined $subs{$Fact};
&ShowMenu;
&{$Fact};
&{ $subs{$Fact} };
$OUT.=$tend;
&Exit;


# ---------------------
#    ���������� ����
# ---------------------

sub kernel_stat
{
 $Fmode=int $F{mode};
 $Fyear=int $F{year} || $year_now;
 $list_year=&Set_year_in_list($Fyear);
 $Fmon=int $F{mon};
 $Fmon=$mon_now if $Fmon<1 || $Fmon>12;
 ($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
 $max_day=&GetMaxDayInMonth($Fmon,$Fyear);		# ������� ���������� ��������� ����� � ����������� ������
 $Fday=int($F{day})||$day_now;
 $Fday=$max_day if $Fday>$max_day || $Fday<1;
 $OUT.=&form_a('#'=>1,'act'=>$Fact,'mode'=>$Fmode)."<select size=1 name=day>";
 $OUT.="<option value=$_".($Fday==$_?' selected':'').">$_</option>" foreach (1..31); # �� ���� 1..$max_day �.�. ����� ����� ���� ������ ����, � ����� ������ �� ������
 $OUT.="</select> $mon_list $list_year <input type=submit value='��������'></form>";
 $time1=timelocal(0,0,0,$Fday,$Fmon-1,$Fyear);		# ������ ���
 $time2=timelocal(59,59,23,$Fday,$Fmon-1,$Fyear);	# ����� ���

 $sql="SELECT * FROM traf_info WHERE time>=$time1 AND time<=$time2 ORDER BY time DESC";
 
 if (!$Fmode)
 {
    $OUT.="* - ����� ��� ������� ��� �������: 1 - ����������, 2 - �� �������� �������, 3 - �����������, 4 - ����������";
    $header=&RRow('head','ccccccccccc',
     '�����<br>�����<br>����������',
     '����������<br>������������<br>�����',
     '�����<br>���������,<br>���������� ��<br>�����������,<br>����',
     '�����<br>�������<br>�����������,<br>���',
     '�����<br>����������<br>�������<br>��������,<br>���',
     '�����<br>����������<br>���������<br>�����������<br>������',
     '�����<br>���������<br>������<br>�������<br>��� ��������<br>��������',
     '�����<br>������<br>�����������<br>�������',
     '����������<br>�������<br>� ����<br>�������',
     '������<br>����������<br>�������,%',
     '*');
     #'������������<br>sql<br>�����������');
    $colspan=11;  
 }else
 {   
    $colspan=4;
    $header=&RRow('head','cc',
     '�����<br>�����<br>����������',
     '���������� ���������� sql-�������� � ����������� �� �� �����');
    $colspan=2;   
 }   
 $header.="</tr>";

 $t2=0;
 @i=();
 $j=0;
 $out='';
 $sth=&sql($dbh,$sql);
 while ($p=$sth->fetchrow_hashref)
 {
    $t1=$p->{time};
    if( $t1!=$t2 )
    {
        if( $t2 )
        {
           $href=&ahref("$scrpt&when=$t2",&the_hour($t2));
           if (!$Fmode)
           {
               $out.=&RRow('*','crrcccccrcr',$href,&split_n($i[1]),&split_n($i[8]),$i[2],$i[3],$i[9],$i[4],$i[15],&split_n($i[5]),
                  $i[14]<100? "<span class=error>$i[14]</span>" : $i[14],$i[29]);
           }else
           {
               $out.=&RRow('*','cl',$href,"<pre>$i[30]</pre>");
               #$out.=&RRow('*','llll',$href,$i[20],$i[21],$i[22]);
           }       
        }    

        if( ++$j>30 )
        {  # ������ 30 ����� ������� �����
           $out.=$header;
           $j=0;
        }
        $t2=$t1;    
        @i=();
    }

    $cod=$p->{cod};
    $data1=$p->{data1};

    $cod or next;

    if( $cod==8 )
    {  # ����� ���������� ��������� ������
       foreach (split /\n/,$data1)
       {
          $i[8]+=$1 if /: *(\d+) *$/;
       }
       next;   
    }

    if( $cod>0 && $cod<=15 )
    {
       $i[$cod]+=$data1;
       next;
    }
     
    if( $cod>=20 && $cod<=22 )
    {
       $i[$cod]++;
       next;
    }
    $i[$cod].=$data1;
 }
 $OUT.=&Table('tbg width100',"<tr class=head><$tc colspan=$colspan><br><b>���������� ����</b>$br2</td></tr>$header$out"); 
 if( $Fmode==1 )
 { # ��������� ������� � 3� �������
   $OUT.="</td><$tc valign=top>".&MessX('�����������:<br><br><p class=story>� ������ ������� ������������� �������������� ������, ���������� '.
     '�� ������� ���������� ����� sql-�������� ��������� ����. ��� ������� ������������� ��� ����, ����� �� ����������������� ����� '.
     '��������� �������� ����������� ����� sql-�������� ��� ������������� ��������� ������ ����� ���������� � ��.</p><p class=story>'.
     '����� ������� � ���������� �������� �������� ������������� �������, ���� �������� ������ ���������� �������, ��� �������� '.
     '�������� ����� �������. �� ����� ������� �������, ���� ��������� ��������� sql-�������: ��������� �������� ���������� � ����. '.
     '��� ������ ����� ��������������� ������� �������� ��������, ��������� � ���������� ����, �� �������� ������������� ����� sql. '.
     '� ������� '.&commas('�������������').' ������������ �������� �����������, ��� �� ������ ��� ����������� ������ ������� �� '.
     '���������� sql ��������������� �����. �������� ����������� �������� � ���������� ��� � ��������� �������� � ������ '.&commas('��������� ����').
     '.</p><p class=story>�� ��������� ������������ ������������� sql ���������. ��� ����, ������ ����, ��� ���������� ������� ���� ������ '.
     &commas('������ sql').' � ������� '.&commas('����������').'. �� �������� ������� ������ ���������� ������� ����� �������������.</p>');
 }
}


# ======================================================================================================================
#                                                    ����������             
# ======================================================================================================================

# �������� ������� ������������ ���������
# ����:
#  1 - � ���������
# �����:
#  1 - ��� ������ � ��������
sub GetSatConfig
{
 my ($id)=@_;
 $id=int $id;
 my ($sth,$p,%c);
 $sth=$dbh->prepare("SELECT * FROM conf_sat WHERE id=$id LIMIT 1");
 $sth->execute;
 return () unless $p=$sth->fetchrow_hashref;
 %c=();
 $c{login}=&Filtr_out($p->{login});
 $c{name}=&Filtr_out($p->{login});
 $c{comment}=&Filtr_out($p->{login});
 foreach (split /\n/,$p->{config}) {$c{$1}=$2 if /^([^ ]+) (.*)$/}
 return %c;
}

sub GetLoginSat
{
 $sat_id=int $F{sat_id};
 $mod_id=int $F{mod_id};
 %c=&GetSatConfig($sat_id);
 $login=(!!$mod_id && &ahref("$scrpt0&a=oper&act=sat_edit&id=$sat_id",$c{login}||'???')." (id=$sat_id) ").
   (('����','������ L2-�����������','������ �������','������ nomake')[$mod_id]||'������������ ������');
}

sub ShowAgentMonitor
{# ����������� ����� ���������� �� ����������� ������
 # ����: id ���������, id ������, ��� ���������, �������� ������
 my ($sat_id,$mod_id,$sat_name,$mod_name)=@_;
 my ($sth,$p,$tt,$tstart,$tend,$t2);
 my %f;
 my $ping_error=1; # ���� ��������� �������, ��� ������ ���������� �� ������ �� ���������� ���� ������������ ������� $Sat_t_no_ping ���

 $tend=$t-$ts*3600;
 $tstart=$tend-3600; # ���������� ������ �� ������ ������� ���
 $sth=$dbh->prepare("SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id AND time>$tstart AND time<$tend ORDER BY time DESC");
 $sth->execute;
 $tt=$tend;
 $t2=$tend-$Sat_t_no_ping; # ���� ����� ����� �������� ������� ����� ������ � ����������, �� ��� �� � $ping_error ��������� � 0
 $y='';
 while ($p=$sth->fetchrow_hashref)
 {
    $f{$_}=$p->{$_} foreach ('time','error');
    $ping_error=0 if $f{time}>$t2;
    $tt-=$f{time};
    $tt=int $tt/4;
    $y.="<img width=$tt height=$height_line vspace=3 src='$img_dir/f1.gif'>" if $tt>0;
    $y.="<img width=".($tt>0?2:1)." height=".($height_line+6)." src='$img_dir/f".($f{error}?3:2).".gif'>";
    $tt=$f{time}-8;
 }
 $tt=int ($tt-$tstart)/4;
 $y.="<img width=$tt height=$height_line vspace=3 src='$img_dir/f1.gif'>" if $tt>0;
 $OUT.=($ping_error?"<tr class='rowover error'>":"<tr class=row2>")."<td class=nav3><a href='$scrpt&act=sat_stat&sat_id=$sat_id&mod_id=$mod_id'>$sat_name</a></td><td nowrap>$mod_name</td><td>$y</td></tr>";
}

sub ShowSatList
{
 $ts=$_[0];
 $OUT.="<table class=tbg1>".
   "<tr class=head><td>&nbsp;</td><td>&nbsp;</td><$tc>���������� �� $_[1]</td></tr>".
   "<tr class=tablebg><$tc>��������</td><$tc>�����</td><td>";
   
 foreach $i (0..11)
   {# � ���� 12 �������� �� 5 �����
    $OUT.="<img width=74 height=$height_line src='$img_dir/f1.gif'>";
    $OUT.="<img width=1 height=$height_line src='$img_dir/f2.gif'>";
   } 
 $OUT.='</td></tr>';

 &ShowAgentMonitor(0,0,'���� NoDeny','&nbsp;');
 
 $sth=&sql($dbh,"SELECT * FROM conf_sat ORDER BY login");
 while ($p=$sth->fetchrow_hashref)
 {
    $id=$p->{id};
    %c=&GetSatConfig($id);
    next unless $c{Noserver_monitor} || $c{L2_auth_monitor}; # �� ���� ����� �� �����������
    &ShowAgentMonitor($id,1,$c{login},"L2-�����������") if $c{L2_auth_monitor}; # 1 - id ������ L2-�����������
    &ShowAgentMonitor($id,2,$c{login},"�������") if $c{Noserver_monitor}; # 2 - id ������ noserver.pl
    &ShowAgentMonitor($id,3,$c{login},"nomake") if $c{Nomake_monitor}; # 3 - id ������ nomake.pl
 }
 $OUT.="</table>";
}

sub sat_list
{
 $OUT.=&MessX(&bold('���������� ����������')).$br;
 &ShowSatList(0,"��������� 60 �����");
 $OUT.=$br3;
 &ShowSatList(1,"���������� ���");
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="60; url='$scrpt'">};
}

# ����� ���������� ������������ ������
sub sat_stat
{
 &GetLoginSat;
 
 $sql="SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id ORDER BY time DESC";
 ($sql,$OUT2,$rows,$sth)=&Show_navigate_list($sql,$start,60,"$scrpt&act=sat_stat&sat_id=$sat_id&mod_id=$mod_id");

 $OUT.="<table class='tbg3 width100'><tr class=head><$tc colspan=2>���������� ��������� $login</td></tr>";
 $OUT.="<tr class=head><td colspan=2>$OUT2</td></tr>" if $OUT2; 
 $OUT.="<tr class=tablebg><$tc>�����</td><$tc>����������</td></tr>";
 
 $a="$scrpt&act=sat_dstat&sat_id=$sat_id&mod_id=$mod_id&time=";
 while ($p=$sth->fetchrow_hashref)
 {
   ($time,$mod_id,$sat_id,$error,$info)=&Get_filtr_fields('time','mod_id','sat_id','error','info');
    if( $mod_id==1 )
    {  # ����� L2-�����������
       ($info,$ip_list)=split /\n/,$info;
       ($t_monint,$ips,$packets,$floodpackets,$ban_ip)=split /\|/,$info;
       $ban_ip=&bold($ban_ip) if $ban_ip;
       $info="���������� �������: $packets. ������� ������������ ��� ����: $floodpackets. ���������� ip, ���������� �������: $ips. ��������� ip: $ban_ip."
    }
     else
    {
       $info=&Show_all($info);
    } 
    $OUT.=&RRow('*','ll',&ahref("$a$time",&the_time($time)),$info);
 }
 $OUT.="</table>";
}

# ==========================
sub Show_Mod_1
{
 ($error,$info)=@_;
 ($info,$ip_list)=split /\n/,$info;
 $ip_list=~s/,/<br>/g;
 ($t_monint,$ips,$packets,$floodpackets,$ban_ip)=split /\|/,$info;
 $OUT.=&PRow."<td>���������� �������</td><$td>".&bold($packets)."</td><td></td></tr>".
       &PRow."<td>������� ������������ ��� ����</td><$td>".&bold($floodpackets)."</td><td>���������� �������, ������� ������ ���� ������������. ��� �� ����������� �����, �������� �������� �� ��������� � ���������� ���� ������� � ����� ��������� ��������, ���� �� �����-������ ������ ����� ����� ����������� ����� �����������</td></tr>".
       &PRow."<td>���������� ip</td><$td>".&bold($ips)."</td><td>���������� ���������� ip-������� �� ������� ������� ������ 1 �����. � ������� �������� (���������� ����� � �������� ip) ��� ����� �������� ����� ���������� ��������, ���������� �������������� �� ������ ���������</td></tr>".
       &PRow."<td>��������� ip</td><$td>".&bold($ban_ip)."</td><td>���������� ip, ������� �������� �� ��������� ����� ��� ������ �� �����</td></tr>".
       &PRow."<td valign=top>��������� ip</td><$td>$ip_list</td><td valign=top>������ ip, ������� ���� ��������. �������� ��������, ��� ������ ip ��� �� ����������� ����������. ��� ����� ���� ������� ���������� ����� ����� ������ ����� �����������. �����, ��������, � ���������� �������� �������� ��������� �� �� �������� ������ ���������� ��� �������, ������� ������������ �������� ��������� �������. � ����������, ��������� ����������� ������������ �� ��������� �������� ��� ����� ������ �������� �� �������.<br><br>���� ������ ip �������, �� �� ��� ip ���������� �����.</td></tr>";
       
}

# ����� ��������� ���������� �� ���� ������������ ������
sub sat_dstat
{
 &GetLoginSat;

 $time=int $F{time};
 $tt=&the_time($time);
 $sth=$dbh->prepare("SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id AND time=$time LIMIT 1");
 $sth->execute;
 &Error("� ��������� ���� ������� $tt ���������� ������ $mod_id ��������� $login �����������.",$tend) unless $p=$sth->fetchrow_hashref;
 
 ($error,$info)=&Get_filtr_fields('error','info');
 $OUT.="<table class='tbg3 width100'><tr class=head><$tc colspan=3>���������� �� ��������� $login</td></tr>";
 &Show_Mod_1($error,$info) if $mod_id==1;
 $OUT.="</table>";
}



sub sat_help
{
 $OUT.=<<MESS
<div class='message lft'>������<br><br>
<b>���������� ����������</b> ������������ ��� �������������� ����������� ���������� ��������, ������� ����� ���� �����������
��������������������, ����������� ������������������ ��� �������������� ������-���� ������ NoDeny, ��������������
������������ ������ ��������. �������� - ��� ������, �� ������� ����������� ������, ������������������ ��� ����������
��������, ����������� � ������ ����������. ������ ����� ����� ������������ ���������� ������� ���������� � �����������
���� ������ ���������� � ����� ���������. ���� ������������ ���������� ������� ���������� �� ���������, �������
"���� �������". ����������� ����� �������� ��������������������. ��������, ��� ������ �� ������������� ������ ��
��������� ������ ����� ������������ �������, �������� ������������� ������� ������ ������-����������� ������� ������.<br>
<br>
� ������� ����������� ������ ������ ���������� ��� �������. �� ���� ������ � ����������� �� ������� ���������� ������
�� ������, � ������������ ������� �������� ������� �������� ��� �������� �����. ������� ������� ���������� ����������
����� ������. ������� ��������, ��� ��� ������ ��������� ��� �������� � ��� ������ �������. ��� ��������� �� ������
���������� � ��������� ���������� ������
</div>
MESS
   
}

1;
