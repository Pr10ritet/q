#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;
# ---------------------------------------------
#
# ������ �������� ��������
#
# ---------------------------------------------
# �������� ������� �� ��
# �������: 0 - ������ �� ���������
#	� ��� �� �������� ��������������� ���������� $Tarif_loaded
#  ����������� ������� $Plan_*[$i]
#  ������:
#  $srv_n[$i]  - �������� ������
#  $srv_p[$i]  - ��������� ������
#
#  ���� ���������� ���������� ���������� $Admin_office, ��� ��������� �� ����� ������ ����������
#  ������ ������������, �� ��� ������� ������ ��������������� $Plan_allow_show[$i] - �������
#  ������ �� ������ � �������� ������ ������� ������. ���� ����� ����� ���������� ������
#  ������� ��������, �� ��� ������ ������ �� ���� �������.
#  ����� $Plan_allow_show[$i] ������������
sub TarifReload
{
 my ($sth,$p,$i);
 $Tarif_loaded=0;	# ���� �������� �������, ��� ������ �� �����������

 foreach $i (1..31)
 {
    if( $srvs{$i}=~/^(.+)-(.+)$/ )
    {
       $srv_n[$i]=$1;
       $srv_p[$i]=$2;
    }else
    {
       $srv_n[$i]='';
       $srv_p[$i]=0;
    }
 }

 $i=0;
 @Plan_allow_show=();	# ���� ���������, ��� ������ ����� �����������
 $sth=$dbh->prepare("SELECT * FROM plans2 WHERE id<=$m_tarif");
 $sth->execute;
 while ($p=$sth->fetchrow_hashref)
 {
    $i=$p->{id};
    $_=$p->{name};
    s|[<>'\\&]||g;	# ������ �������������� �� ...
    s|^\s+$||;
    $Plan_name[$i]=$_;
    s|^\[\d+\]||;	# ������ ������������� �������
    $Plan_name_short[$i]=$_;
    $Plan_mb1[$i]=$p->{mb1};
    $Plan_mb2[$i]=$p->{mb2};
    $Plan_mb3[$i]=$p->{mb3};
    $Plan_mb4[$i]=$p->{mb4};
    $Plan_price[$i]=$p->{price};
    $Plan_price_change[$i]=$p->{price_change};
    $Plan_over1[$i]=$p->{priceover1};
    $Plan_over2[$i]=$p->{priceover2};
    $Plan_over3[$i]=$p->{priceover3};
    $Plan_over4[$i]=$p->{priceover4};
    $Plan_k[$i]=$p->{k};
    $Plan_m2_to_m1[$i]=$p->{m2_to_m1};
    $Plan_start_hour[$i]=$p->{start_hour};
    $Plan_end_hour[$i]=$p->{end_hour};
    $InOrOut1[$i]=$p->{in_or_out1};
    $InOrOut2[$i]=$p->{in_or_out2};
    $InOrOut3[$i]=$p->{in_or_out3};
    $InOrOut4[$i]=$p->{in_or_out4};
    $Plan_flags[$i]=$p->{flags}; 
    $Plan_speed[$i]=$p->{speed};
    $Plan_speed_out[$i]=$p->{speed_out};
    $Plan_speed2[$i]=$p->{speed2};
    $Plan_preset[$i]=$p->{preset};
    $Plan_usr_grp[$i]=$p->{usr_grp};
    $Plan_pays_opt[$i]=$p->{pays_opt};
    $Plan_newuser_opt[$i]=$p->{newuser_opt};
    $Plan_script[$i]=$p->{script};
    $Plan_descr[$i]=$p->{descr};
    $_=$p->{offices};
    $Plan_allow_show[$i]=1 if $PR{26} || /,$Admin_office,/; # �������� �� ������ ����� ��� ������, 26 - ������ � ������ �������
 }
 $Tarif_loaded=1 if $i;

 # ������ �� ��������
 $sth=$dbh->prepare("SELECT * FROM nets WHERE priority=0 AND class>=0 AND class<=9");
 $sth->execute;
 while ($p=$sth->fetchrow_hashref) {$PresetName{$p->{preset}}{$p->{class}}=$p->{comment}}
 
 %Plans3=();
 $sth=$dbh->prepare("SELECT * FROM plans3");
 $sth->execute;
 while ($p=$sth->fetchrow_hashref)
 {
    $i=$p->{id};
    $Plans3{$i}={ map { $_,$p->{$_} } ('name','price','price_change','usr_grp','usr_grp_ask','descr') };
    $Plans3{$i}{name_short}=$Plans3{$i}{name};
    $Plans3{$i}{name_short}=~s|^\[\d+\]||; # ������ ������������� �������
 }
#      'name'=>$p->{name},
#      'price'=>$p->{price},
#      'price_change'=>$p->{price_change},
#      'usr_grp'=>$p->{usr_grp},
#      'usr_grp_ask'=>$p->{usr_grp_ask},
#      'descr'=>$p->{descr}
 
 return $Tarif_loaded;
}


# ------------------------------------------------------------------------------
# ������������ ���������� ������ �� ���� ������������. ���� ����������� � ������
# ������ ������� �� ������� ������, � ������������� �� ����������� 1, �� ����
# ����������� 1 �������������, � ���� �����������, � �������� ���������� ����, ����������
#
# ����: ����_�����������_1, ����_�2, ����_�3, ����_�4, �_������
# �����: Traf1,Traf2,Traf3,Traf4
sub Chng_traf
{
 my ($Traf1,$Traf2,$Traf3,$Traf4,$paket)=(@_);
 if ($Plan_over2[$paket]==0) {$Traf1+=$Traf2; $Traf2=0}
 if ($Plan_over3[$paket]==0) {$Traf1+=$Traf3; $Traf3=0}
 if ($Plan_over4[$paket]==0) {$Traf1+=$Traf4; $Traf4=0}
 return ($Traf1,$Traf2,$Traf3,$Traf4);
}

sub prow
{
 ($_[0],$_[1])=($_[1],$_[0]);
 return $_[0];
}

# --- ��������� -> ������ ---
# ����: ������ �� ��� � �������: 
#  paket	- ����� ��������� �����
#  paket3	- ����� ��������������� ��������� �����
#  discount	- ������� ������
#  service	- ������
#  mode_report	- ����� ������ (0 - ����������� ��������� �����)
#  start_day	- ���� ������ �������������� �����
#  traf		- ������ �� ��� � ��������
#
# �����: ����� �� ��� � �������:
#  money	- ����� ������������� ������� � ������
#  money_over	- ����������� ����� ������ (0 - ���� ���)
#  block_cod	- ���� �� = 0, �� ������� �� ������� ���������� ������������� ������:
#		1 - ���������� �������� `����������� 1` � `���� ����������` = 0,
#		    ������������ ��� ������� ���������� �������������, �������
#		    ��������� ����������� (���� ����������� ������ ���� = 0)
# 	        4 - � ������ ������ ������� ����� ������ ������ ���� ��������
#  report	- ����� � html-����, ���� ����� ����� ������ = 0
#  service_list	- ������ ����� � ��������� (����� �������)
#  traf1,traf2,traf3,traf4 - ������ � ������ ����������������� �� `����������� 1`

sub Money
{
my ($d)=@_;

my ($paket,$paket3,$r1,$r2,$service,$start_day,$discount,$mode_report);
my ($k,$money,$money_over,$price,$m,$p,$i,$preset,$p_price,$real_start_day)=(1,0,0,0,0,0,0,0,0,0);
my @price_over;		# ��������� ����������� ������� �����������
my @money_over;		# ������� ����������� �� $gr
my @mb_over;		# ������� ����������� �� ��
my @p_mb;		# �������������� ��������
my @c;			# �������� �����������
my @traf;		# ������ �����������

my $ret={
 money		=> 0,
 money_over	=> 0,
 block_cod	=> '',
 report		=> '',
 service_list	=> '',
 traf1		=> 0,
 traf2		=> 0,
 traf3		=> 0,
 traf4		=> 0,
};

$paket=int $d->{paket};
$paket3=int $d->{paket3};
$service=int $d->{service};
$discount=int $d->{discount};
$start_day=int $d->{start_day};
$mode_report=!(int $d->{mode_report});

# ������ �� ���������
if( !$Tarif_loaded )
{
   $ret->{block_cod}=1;
   $ret->{report}="����� ������ �� ������ �� ����������. ���������� � ��������������." if $mode_report;
   return $ret;
}

if( $paket<=0 )
{
   $ret->{block_cod}=1;
   $ret->{report}="<b>������:</b> ���������������� �������� ����." if $mode_report;
   return $ret;
}

if( $paket3>0 && !defined $Plans3{$paket3} )
{
   $ret->{block_cod}=1;
   $ret->{report}="<b>������:</b> ���������������� �������������� �������� ����." if $mode_report;
   return $ret;
}

if( defined $d->{traf} )
{
   $p=$d->{traf};
   @traf=(
      0,
      &Get_need_traf($p->{in1},$p->{out1},$InOrOut1[$paket])/$mb,
      &Get_need_traf($p->{in2},$p->{out2},$InOrOut2[$paket])/$mb,
      &Get_need_traf($p->{in3},$p->{out3},$InOrOut3[$paket])/$mb,
      &Get_need_traf($p->{in4},$p->{out4},$InOrOut4[$paket])/$mb
   );
}
 else
{  # ������ ����� �������� �������
   @traf=map{ $d->{"traf$_"}+0 } (0..4);
}

$real_start_day=$start_day;
if( $start_day<0 )
{
   $start_day=localtime()->mday; # ������� ���� ������
   # ������ ���� - ����� ��������� ����� ��������� ���� ������ ����������� �������, � ���� �� ������,
   # ��������, ����� ������ - ����� �� � ��� ����� ����� ����:
   $real_start_day=$start_day if $traf[1]||$traf[2]||$traf[3]||$traf[4];
}

# ����� � $ret->{report} ���� ����������� 5 �������, � �� 2

$r1='row2';
$r2='row1';

{
 $k=1;
 last if $start_day<=0;
 # �� � ������ ������ ����� ������������ ��������. �������� ����������� ��������� ������� � �����
 $k=sprintf("%.2f",(32-$start_day)/31);
 $ret->{report}="<tr class=head><td colspan=5><br>��. �������, �� ������ ������������ ������� � <b>$start_day</b> �����, ".
   " �.�. �� ������ �����. �� ��������� ��������� ��������� ����� � �������������� ������: ".
   " ������ ��������� ����� �������� �� ����������� <b>$k</b><br><br>".$ret->{report} if $mode_report;
}
 
{
 last if $paket3<=0;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>".
   ($Plan3_Title || '�������������� �������� ����')."</td><$td>$Plans3{$paket3}{name}</td></tr>";
 $_=$k!=1 && "$k * $Plans3{$paket3}{price} = ";
 $m=$k*$Plans3{$paket3}{price};
 $_.="<span class=data2>$m</span>";
 $money+=$m;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>����, $gr</td><$td>$_</td></tr>";
 $m=$Plans3{$paket3}{descr};
 $m=~s|&|&amp;|g;
 $m=~s|<|&lt;|g;
 $m=~s|>|&gt;|g;
 $m=~s|'|&#39;|g;
 $m=~s|\n|<br>|g;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>��������</td><$td>$m</td></tr>" if $m;
}


if( $service )
{  # �� ������� ���� 1 ������ ������������
   for ($i=1;$i<32;$i++,$service>>=1)
   {
      next unless $service & 1;
      $m=$srv_p[$i];
      $money+=$m;
      $mode_report or next;
      $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=3>";
      $_=$srv_n[$i] || '��� ��������';
      s/&/&amp;/g;
      s/</&lt;/g;
      s/>/&gt;/g;
      s/'/&#39;/g;
      $ret->{report}.="������ <b>$_</b>, $gr";
      $ret->{service_list}.="$_: $m $gr\n";
      $ret->{report}.="</td><$td colspan=2><span class=data2>$m</span></td></tr>";
   }
}

$preset=$Plan_preset[$paket];
@c=('',&Get_Name_Class($preset));

$i=$m=0;

# ��������������� ������ �� ������������ (���� �����������==0, �� ����������� � ��������� �����������)
@traf=('',&Chng_traf($traf[1],$traf[2],$traf[3],$traf[4],$paket));
(undef,$ret->{traf1},$ret->{traf2},$ret->{traf3},$ret->{traf4})=@traf;

$p_price=$Plan_price[$paket];
$p_mb[1]=$Plan_mb1[$paket];
$p_mb[2]=$Plan_mb2[$paket];
$p_mb[3]=$Plan_mb3[$paket];
$p_mb[4]=$Plan_mb4[$paket];

if( $start_day>0 )
{  # �� � ������ ������ ����� ������������ ��������. �������� ����������� ��������� ������� � �����
   $p_mb[1]*=$k if $p_mb[1]<$unlim_mb;
   $p_mb[2]*=$k if $p_mb[2]<$unlim_mb;
   $p_mb[3]*=$k if $p_mb[3]<$unlim_mb;
   $p_mb[4]*=$k if $p_mb[4]<$unlim_mb;
}

$price_over[1]=$Plan_over1[$paket];
$price_over[2]=$Plan_over2[$paket];
$price_over[3]=$Plan_over3[$paket];
$price_over[4]=$Plan_over4[$paket];

$mb_over[1]=$traf[1]-$p_mb[1];
if( $mb_over[1]>0 )
{  # ���������� �������� �������� `����������� 1`
   if( $price_over[1] )
   {
      $money_over+=$price_over[1]*$mb_over[1];
   }else
   {# �������� ��������� �������
      $ret->{block_cod}=1;
   }
}
 else
{
   $mb_over[1]=0; # ! �.�. ����� ���� < 0
}

{
 $p=$k!=1 && "$k * $p_price = ";
 $p_price*=$k;

 $mode_report or last;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>".($Plan2_Title || '�������� ����').'</td>'.
  "<$td>".($Plan_name_short[$paket] || "��������! ���������� � ��������������. ������ � ����� ������: ������������ ����� ��������� �����").'</td></tr>';

 $ret->{report}.='<tr class='.&prow($r1,$r2).'><td colspan=5><b>�����������:</b> '.
   ($p_mb[1]? "��� ���������� ��������������� ������� ��������� &#171;$c[1]&#187;, ���������� �������������� ������������ ��������� �� ����� ������." :
   "&#171;$c[1]&#187; ������ �� ���������������.").'</td></tr>' if $price_over[1]==0 && $p_mb[1]<$unlim_mb;

 $p.="<span class=data2>$p_price</span>";
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>����, $gr</td><$td>$p</td></tr>";

 last if $Plan_start_hour[$paket]==$Plan_end_hour[$paket];

 $k=$Plan_k[$paket];
 # > 0 - �����������, �� ������� ���������� ���� � ������ �������� �������
 # < 0 - ����������� �� ������� �����
 # ==1 - ����������������� �������
 $ret->{report}.='<tr class='.&prow($r1,$r2).'><td colspan=5><b>�����������:</b> ';
 $p="� $Plan_start_hour[$paket] �� $Plan_end_hour[$paket] �����";

 if ($Plan_flags[$paket]=~/n/)
 {
    $ret->{report}.="�������� ����������� $p<br><br>";
 }

 if ($k<0)
 {
    $ret->{report}.="������ � �������� ������ ������ $p";
 }
  elsif ($k==1)
 {
    $ret->{report}.="� ���������� ������� $p <b>$c[1]</b> ������ ����� �������� ��� ";
    $ret->{report}.=$Traf_change_dir?
       "<b>$c[2]</b>".($Plan_over2[$paket]!=0 && ", � <b>$c[3]</b> - ��� <b>$c[4]</b>") :
       "<b>$c[3]</b>".($Plan_over2[$paket]!=0 && ", � <b>$c[2]</b> - ��� <b>$c[4]</b>");
 }
  elsif ($k>0)
 {
    $ret->{report}.="$p ������ ��������� � ������������� $Plan_k[$paket]";
 }
 $ret->{report}.='</td></tr>';
}

$money+=$p_price;

$_=$traf[2]-$p_mb[2];
$mb_over[2]=$_<0? 0 : $_;

# ���� � ������ �������, ��� ������ �����������_2 ��� ����������� �����������_1
# ����� ������� �������� �����������_1 � ����������� $Plan_m2_to_m1[$paket]
if ($Plan_m2_to_m1[$paket] && $mb_over[2] && $traf[1]<$p_mb[1])
{  # ������� �������� �������_2 ���� �� ���������� �������_1
   $p=($p_mb[1]-$traf[1])*$Plan_m2_to_m1[$paket];
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=5>�������� ���� ���������������, ��� ���� �� �� ���������� ��� ��������� ������� $c[1], ��".
      " $c[2] ������ ����� ���� �������� ��� $c[1] � �����������:<br>".
      " $c[2] <b>$Plan_m2_to_m1[$paket]</b> �� = <b>1</b> �� $c[1].</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>�������������� $c[1] ������</td>".
      "<$td>".sprintf("%.2f",$p_mb[1]-$traf[1])." ��</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>$c[2] ����������</td>".
      "<$td>".sprintf("%.2f",$p)." ��</td><td>&nbsp;</td></tr>" if $mode_report;
   $p=$mb_over[2] if $p>$mb_over[2];
   $mb_over[2]-=$p;
   $traf[2]-=$p;      # ���� ����������� 2 ������� ���� ������
   $traf[1]+=$p/$Plan_m2_to_m1[$paket]; # ������� ������� ���� ������
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=3>$c[2] �������� ��� $c[1]</td>".
      "<$td>".sprintf("%.2f",$p)." ��</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>����� $c[2] ������ ����� ����������</td>".
      "<$td>".sprintf("%.2f",$traf[2])." ��</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>�������������� $c[1]</td>".
      "<$td>".sprintf("%.2f",$traf[1])." ��</td><td>&nbsp;</td></tr>" if $mode_report;
}

$money_over[2]=$price_over[2]*$mb_over[2];

foreach $i (3,4)
{
   $_=$traf[$i]-$p_mb[$i];
   $mb_over[$i]=$_<0? 0 : $_;
   $money_over[$i]=$price_over[$i]*$mb_over[$i];
}

$money_over+=$money_over[2]+$money_over[3]+$money_over[4];

{
 $mode_report or last;
 $ret->{report}.="<tr class=head><$tc>��� �������</td><$tc>��������, ��</td><$tc>������������, ��</td><$tc>����������, ��</td><$tc>��������� ����������, $gr</td></tr>";
 foreach $i (1..4)
 {
    if ($i==1 || $price_over[$i]!=0)
    {
       $m=sprintf("%.2f",$traf[$i]);
       $m=$m>=0? $m : '0&nbsp;&nbsp;<br>������ '.abs($m);
       $ret->{report}.="<tr class=".&prow($r1,$r2)."><td>&nbsp;&nbsp;$c[$i]</td><$td>".
         ($p_mb[$i]<$unlim_mb || $mb_over[$i]? $p_mb[$i].'&nbsp;&nbsp;</td>'.
           "<$td>$m&nbsp;&nbsp;</td>".
           "<$td>".sprintf("%.2f",$mb_over[$i])."&nbsp;&nbsp;</td>".
           "<$td nowrap>&nbsp;&nbsp;".(!$price_over[$i]? '0' : $price_over[$i]<0.001? sprintf("%.5f",$price_over[$i]) : sprintf("%.3f",$price_over[$i]) )." $gr/�� * ".sprintf("%.2f",$mb_over[$i])." �� = <span class=data2>".sprintf("%.2f",$price_over[$i]*$mb_over[$i])."</span></td></tr>" :
         "<b>�����������</b></td><$td>$m&nbsp;&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>");
    }
 }     
}

if (!$ret->{block_cod} && $Plan_k[$paket]<0)
{
   $p=localtime();
   if ($Plan_k[$paket]>-10 || (($p->wday)>0 && ($p->wday)<6))
   {
      my $hour=$p->hour;
      my $start=$Plan_start_hour[$paket];
      my $end=$Plan_end_hour[$paket];
      $ret->{block_cod}=4 if ($start>$end && ($hour<$start && $hour>=$end))||($start<$end && ($hour<$start || $hour>=$end));
   }
}

$money+=$money_over;
$m=$money;
$i=-sprintf("%.2f",$money * $discount/100);
$money=sprintf("%.2f",$m+$i);

if ($mode_report)
{
   if ($discount)
   {
      $ret->{report}.=sprintf("<tr class=".&prow($r1,$r2)."><td colspan=4>�������� ��������� ��������� �����, $gr</td><$td><span class=data2>%.2f</span></td></tr>",$m).
        "<tr class=".&prow($r1,$r2)."><td colspan=4><span class=data1>������, %</span></td><$td><span class=data1>$discount</span></td></tr>".
        "<tr class=".&prow($r1,$r2)."><td colspan=4><span class=data1>������, $gr</span></td><$td><span class=data1>$i</span></td></tr>";
   }
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4><b>����� � ������</b>, $gr</td><$td><span class=data2>$money</span></td></tr>";
   $ret->{report}="<table class='tbg1 width100'>$ret->{report}</table>";
}

if ($real_start_day<0)
{
   $ret->{report}.="<div class=rowsv>�� ��� �� ������ ������������ �������, �� ����� �� ��������� ������.</div>" if $mode_report;
   return $ret;
}

$ret->{money}=$money;
$ret->{money_over}=$money_over;
return $ret;
}

# ����: �������� ������, ��������� ������, �����:
#  0 - ��������, 1 - ���������, 2 - �����,  3 - ���������� ������������
# �����: ������
sub Get_need_traf
{
 my ($mb_in,$mb_out,$mod)=(@_);
 return($mb_in) unless $mod;
 return($mb_out) if $mod==1;
 return($mb_in + $mb_out) if $mod==2;
 return($mb_in > $mb_out? $mb_in : $mb_out) if $mod==3;
 return (0);
}

# ����������� ������������ ������������� �������
sub Get_name_traf
{
 return (!$_[0]? '��������' : $_[0]==1? '���������' : $_[0]==2? '����+�����' : $_[0]==3? '���������� ������������' : '???');
}

# ����������� ���� �����������
sub Get_text_block_cod
{
 return((
   '',
   '�������� ����� �������',
   '�������� ����� �������� �������������',
   '',
   '� ������ ����� ����� ������ ������������ �� ������� ��������� �����'
  )[$_[0]]||'-');
}

# ��������� �������� ������� ��� ���������������� �������
# ����: � �������
# �������: ������ �������� ����������� �� 1 �� 9
sub Get_Name_Class
{
 my ($p)=(@_);
 return($PresetName{$p}{1}||"'����������� 1'",$PresetName{$p}{2}||"'����������� 2'",$PresetName{$p}{3}||"'����������� 3'",$PresetName{$p}{4}||"'����������� 4'",
        $PresetName{$p}{5}||"'����������� 5'",$PresetName{$p}{6}||"'����������� 6'",$PresetName{$p}{7}||"'����������� 7'",$PresetName{$p}{8}||"'����������� 8'",'�������������');
}

$unlim_mb=999000000; # ���������� ��, ������� � ������� �������, ��� ��� �����

1;
