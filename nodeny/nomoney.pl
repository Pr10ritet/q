#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;
# ---------------------------------------------
#
# Модуль денежных расчетов
#
# ---------------------------------------------
# Загрузка тарифов из БД
# Возврат: 0 - тарифы НЕ загружены
#	в это же значение устанавливается переменная $Tarif_loaded
#  Формируются массивы $Plan_*[$i]
#  Услуги:
#  $srv_n[$i]  - название услуги
#  $srv_p[$i]  - стоимость услуги
#
#  Если определена глобальная переменная $Admin_office, что указывает на отдел админа вызвавшего
#  данную подпрограмму, то для каждого тарифа устанавливается $Plan_allow_show[$i] - признак
#  давать ли доступ к текущему тарифу данному админу. Если админ имеет привилегии работы
#  разными отделами, то ему дается доступ ко всем тарифам.
#  Ядром $Plan_allow_show[$i] игнорируется
sub TarifReload
{
 my ($sth,$p,$i);
 $Tarif_loaded=0;	# пока поставим признак, что тарифы не загрузились

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
 @Plan_allow_show=();	# надо учитывать, что тарифы могут обновляться
 $sth=$dbh->prepare("SELECT * FROM plans2 WHERE id<=$m_tarif");
 $sth->execute;
 while ($p=$sth->fetchrow_hashref)
 {
    $i=$p->{id};
    $_=$p->{name};
    s|[<>'\\&]||g;	# ручное редактирование БД ...
    s|^\s+$||;
    $Plan_name[$i]=$_;
    s|^\[\d+\]||;	# уберем сортировочный префикс
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
    $Plan_allow_show[$i]=1 if $PR{26} || /,$Admin_office,/; # разрешен ли данный тариф для админа, 26 - доступ к другим отделам
 }
 $Tarif_loaded=1 if $i;

 # Данные по пресетам
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
    $Plans3{$i}{name_short}=~s|^\[\d+\]||; # уберем сортировочный префикс
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
# Подпрограмме передается трафик по всем направлениям. Если направление в данном
# пакете требует не считать трафик, а перебрасывать на направление 1, то траф
# направления 1 увеличивается, а траф направления, с которого перекинули траф, обнуляется
#
# Вход: траф_направления_1, траф_н2, траф_н3, траф_н4, №_пакета
# Выход: Traf1,Traf2,Traf3,Traf4
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

# --- Мегабайты -> Деньги ---
# Вход: ссылка на хеш с ключами: 
#  paket	- номер тарифного плана
#  paket3	- номер дополнительного тарифного плана
#  discount	- процент скидки
#  service	- услуги
#  mode_report	- режим отчета (0 - формировать текстовый отчет)
#  start_day	- день начала предоставления услуг
#  traf		- ссылка на хеш с трафиком
#
# Выход: сылка на хеш с ключами:
#  money	- сумма эквивалентная трафику и пакету
#  money_over	- переработка сверх пакета (0 - если нет)
#  block_cod	- если не = 0, то причина по которой необходимо заблокировать доступ:
#		1 - превышение мегабайт `направления 1` И `цена превышения` = 0,
#		    используется как признак отключения пользователей, которым
#		    запрещена переработка (цена переработки должна быть = 0)
# 	        4 - в данный момент времени суток доступ должен быть запрещен
#  report	- отчет в html-виде, если задан режим отчета = 0
#  service_list	- список услуг и стоимость (одной строкой)
#  traf1,traf2,traf3,traf4 - трафик с учетом перераспределения на `направление 1`

sub Money
{
my ($d)=@_;

my ($paket,$paket3,$r1,$r2,$service,$start_day,$discount,$mode_report);
my ($k,$money,$money_over,$price,$m,$p,$i,$preset,$p_price,$real_start_day)=(1,0,0,0,0,0,0,0,0,0);
my @price_over;		# стоимость переработки каждого направления
my @money_over;		# текущая переработка по $gr
my @mb_over;		# текущая переработка по мб
my @p_mb;		# предоплаченных мегабайт
my @c;			# названия направлений
my @traf;		# трафик направлений

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

# тарифы не загружены
if( !$Tarif_loaded )
{
   $ret->{block_cod}=1;
   $ret->{report}="Сумма оплаты за услуги не подсчитана. Обратитесь к администратору." if $mode_report;
   return $ret;
}

if( $paket<=0 )
{
   $ret->{block_cod}=1;
   $ret->{report}="<b>Ошибка:</b> недействительный тарифный план." if $mode_report;
   return $ret;
}

if( $paket3>0 && !defined $Plans3{$paket3} )
{
   $ret->{block_cod}=1;
   $ret->{report}="<b>Ошибка:</b> недействительный дополнительный тарифный план." if $mode_report;
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
{  # старый метод передачи трафика
   @traf=map{ $d->{"traf$_"}+0 } (0..4);
}

$real_start_day=$start_day;
if( $start_day<0 )
{
   $start_day=localtime()->mday; # текущий день месяца
   # трафик есть - скоро серверная часть установит день начала пользования услугой, а если не успеет,
   # например, конец месяца - тогда мы и так знаем какой день:
   $real_start_day=$start_day if $traf[1]||$traf[2]||$traf[3]||$traf[4];
}

# далее в $ret->{report} надо формировать 5 колонок, а не 2

$r1='row2';
$r2='row1';

{
 $k=1;
 last if $start_day<=0;
 # не с начала месяца начал пользоваться услугами. Вычислим коэффициент понижения трафика и денег
 $k=sprintf("%.2f",(32-$start_day)/31);
 $ret->{report}="<tr class=head><td colspan=5><br>Ув. абонент, вы начали пользоваться услугой с <b>$start_day</b> числа, ".
   " т.е. не полный месяц. Мы уменьшили стоимость тарифного плана и предоплаченный трафик: ".
   " данные тарифного плана умножены на коэффициент <b>$k</b><br><br>".$ret->{report} if $mode_report;
}
 
{
 last if $paket3<=0;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>".
   ($Plan3_Title || 'Дополнительный тарифный план')."</td><$td>$Plans3{$paket3}{name}</td></tr>";
 $_=$k!=1 && "$k * $Plans3{$paket3}{price} = ";
 $m=$k*$Plans3{$paket3}{price};
 $_.="<span class=data2>$m</span>";
 $money+=$m;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>Цена, $gr</td><$td>$_</td></tr>";
 $m=$Plans3{$paket3}{descr};
 $m=~s|&|&amp;|g;
 $m=~s|<|&lt;|g;
 $m=~s|>|&gt;|g;
 $m=~s|'|&#39;|g;
 $m=~s|\n|<br>|g;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>Описание</td><$td>$m</td></tr>" if $m;
}


if( $service )
{  # по крайней мере 1 услуга активирована
   for ($i=1;$i<32;$i++,$service>>=1)
   {
      next unless $service & 1;
      $m=$srv_p[$i];
      $money+=$m;
      $mode_report or next;
      $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=3>";
      $_=$srv_n[$i] || 'без названия';
      s/&/&amp;/g;
      s/</&lt;/g;
      s/>/&gt;/g;
      s/'/&#39;/g;
      $ret->{report}.="Услуга <b>$_</b>, $gr";
      $ret->{service_list}.="$_: $m $gr\n";
      $ret->{report}.="</td><$td colspan=2><span class=data2>$m</span></td></tr>";
   }
}

$preset=$Plan_preset[$paket];
@c=('',&Get_Name_Class($preset));

$i=$m=0;

# перераспределим трафик по направлениям (если переработка==0, то добавляется к основному направлению)
@traf=('',&Chng_traf($traf[1],$traf[2],$traf[3],$traf[4],$paket));
(undef,$ret->{traf1},$ret->{traf2},$ret->{traf3},$ret->{traf4})=@traf;

$p_price=$Plan_price[$paket];
$p_mb[1]=$Plan_mb1[$paket];
$p_mb[2]=$Plan_mb2[$paket];
$p_mb[3]=$Plan_mb3[$paket];
$p_mb[4]=$Plan_mb4[$paket];

if( $start_day>0 )
{  # не с начала месяца начал пользоваться услугами. Вычислим коэффициент понижения трафика и денег
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
{  # превышение пакетных мегабайт `направления 1`
   if( $price_over[1] )
   {
      $money_over+=$price_over[1]*$mb_over[1];
   }else
   {# Указание отключить клиента
      $ret->{block_cod}=1;
   }
}
 else
{
   $mb_over[1]=0; # ! т.к. может быть < 0
}

{
 $p=$k!=1 && "$k * $p_price = ";
 $p_price*=$k;

 $mode_report or last;
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>".($Plan2_Title || 'Тарифный план').'</td>'.
  "<$td>".($Plan_name_short[$paket] || "ВНИМАНИЕ! Обратитесь к администратору. Ошибка в ваших данных: неправильный номер тарифного плана").'</td></tr>';

 $ret->{report}.='<tr class='.&prow($r1,$r2).'><td colspan=5><b>Комментарий:</b> '.
   ($p_mb[1]? "При превышении предоплаченного трафика категории &#171;$c[1]&#187;, произойдет автоматическое блокирование интернета до конца месяца." :
   "&#171;$c[1]&#187; трафик не предоставляется.").'</td></tr>' if $price_over[1]==0 && $p_mb[1]<$unlim_mb;

 $p.="<span class=data2>$p_price</span>";
 $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4>Цена, $gr</td><$td>$p</td></tr>";

 last if $Plan_start_hour[$paket]==$Plan_end_hour[$paket];

 $k=$Plan_k[$paket];
 # > 0 - коэффициент, на который умножается траф в данный интервал времени
 # < 0 - ограничение по времени суток
 # ==1 - перераспределение трафика
 $ret->{report}.='<tr class='.&prow($r1,$r2).'><td colspan=5><b>Комментарий:</b> ';
 $p="с $Plan_start_hour[$paket] до $Plan_end_hour[$paket] часов";

 if ($Plan_flags[$paket]=~/n/)
 {
    $ret->{report}.="Скорость удваивается $p<br><br>";
 }

 if ($k<0)
 {
    $ret->{report}.="доступ в интернет открыт только $p";
 }
  elsif ($k==1)
 {
    $ret->{report}.="В промежуток времени $p <b>$c[1]</b> трафик будет засчитан как ";
    $ret->{report}.=$Traf_change_dir?
       "<b>$c[2]</b>".($Plan_over2[$paket]!=0 && ", а <b>$c[3]</b> - как <b>$c[4]</b>") :
       "<b>$c[3]</b>".($Plan_over2[$paket]!=0 && ", а <b>$c[2]</b> - как <b>$c[4]</b>");
 }
  elsif ($k>0)
 {
    $ret->{report}.="$p трафик считается с коэффициентом $Plan_k[$paket]";
 }
 $ret->{report}.='</td></tr>';
}

$money+=$p_price;

$_=$traf[2]-$p_mb[2];
$mb_over[2]=$_<0? 0 : $_;

# Если в пакете указано, что трафик направления_2 при недоработке направления_1
# нужно считать трафиком направления_1 в соотношении $Plan_m2_to_m1[$paket]
if ($Plan_m2_to_m1[$paket] && $mb_over[2] && $traf[1]<$p_mb[1])
{  # столько мегабайт направл_2 есть до заполнения направл_1
   $p=($p_mb[1]-$traf[1])*$Plan_m2_to_m1[$paket];
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=5>Тарифный план предусматривает, что если вы не выработали все мегабайты трафика $c[1], то".
      " $c[2] трафик может быть засчитан как $c[1] в соотношении:<br>".
      " $c[2] <b>$Plan_m2_to_m1[$paket]</b> Мб = <b>1</b> Мб $c[1].</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>Невыработанный $c[1] трафик</td>".
      "<$td>".sprintf("%.2f",$p_mb[1]-$traf[1])." Мб</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>$c[2] эквивалент</td>".
      "<$td>".sprintf("%.2f",$p)." Мб</td><td>&nbsp;</td></tr>" if $mode_report;
   $p=$mb_over[2] if $p>$mb_over[2];
   $mb_over[2]-=$p;
   $traf[2]-=$p;      # траф направления 2 условно стал меньше
   $traf[1]+=$p/$Plan_m2_to_m1[$paket]; # внешний условно стал больше
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=3>$c[2] засчитан как $c[1]</td>".
      "<$td>".sprintf("%.2f",$p)." Мб</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>Итого $c[2] трафик будет составлять</td>".
      "<$td>".sprintf("%.2f",$traf[2])." Мб</td><td>&nbsp;</td></tr>".
      "<tr class=".&prow($r1,$r2)."><td colspan=3>Соответственно $c[1]</td>".
      "<$td>".sprintf("%.2f",$traf[1])." Мб</td><td>&nbsp;</td></tr>" if $mode_report;
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
 $ret->{report}.="<tr class=head><$tc>Тип трафика</td><$tc>Оплачено, Мб</td><$tc>Использовано, Мб</td><$tc>Превышение, Мб</td><$tc>Стоимость превышения, $gr</td></tr>";
 foreach $i (1..4)
 {
    if ($i==1 || $price_over[$i]!=0)
    {
       $m=sprintf("%.2f",$traf[$i]);
       $m=$m>=0? $m : '0&nbsp;&nbsp;<br>резерв '.abs($m);
       $ret->{report}.="<tr class=".&prow($r1,$r2)."><td>&nbsp;&nbsp;$c[$i]</td><$td>".
         ($p_mb[$i]<$unlim_mb || $mb_over[$i]? $p_mb[$i].'&nbsp;&nbsp;</td>'.
           "<$td>$m&nbsp;&nbsp;</td>".
           "<$td>".sprintf("%.2f",$mb_over[$i])."&nbsp;&nbsp;</td>".
           "<$td nowrap>&nbsp;&nbsp;".(!$price_over[$i]? '0' : $price_over[$i]<0.001? sprintf("%.5f",$price_over[$i]) : sprintf("%.3f",$price_over[$i]) )." $gr/Мб * ".sprintf("%.2f",$mb_over[$i])." Мб = <span class=data2>".sprintf("%.2f",$price_over[$i]*$mb_over[$i])."</span></td></tr>" :
         "<b>Безлимитный</b></td><$td>$m&nbsp;&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>");
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
      $ret->{report}.=sprintf("<tr class=".&prow($r1,$r2)."><td colspan=4>Итоговая стоимость тарифного плана, $gr</td><$td><span class=data2>%.2f</span></td></tr>",$m).
        "<tr class=".&prow($r1,$r2)."><td colspan=4><span class=data1>Скидка, %</span></td><$td><span class=data1>$discount</span></td></tr>".
        "<tr class=".&prow($r1,$r2)."><td colspan=4><span class=data1>Скидка, $gr</span></td><$td><span class=data1>$i</span></td></tr>";
   }
   $ret->{report}.="<tr class=".&prow($r1,$r2)."><td colspan=4><b>Итого к оплате</b>, $gr</td><$td><span class=data2>$money</span></td></tr>";
   $ret->{report}="<table class='tbg1 width100'>$ret->{report}</table>";
}

if ($real_start_day<0)
{
   $ret->{report}.="<div class=rowsv>Вы еще не начали пользоваться услугой, со счета не снимаются деньги.</div>" if $mode_report;
   return $ret;
}

$ret->{money}=$money;
$ret->{money_over}=$money_over;
return $ret;
}

# Вход: входящий трафик, исходящий трафик, режим:
#  0 - входящий, 1 - исходящий, 2 - сумма,  3 - наибольшая составляющая
# Выход: трафик
sub Get_need_traf
{
 my ($mb_in,$mb_out,$mod)=(@_);
 return($mb_in) unless $mod;
 return($mb_out) if $mod==1;
 return($mb_in + $mb_out) if $mod==2;
 return($mb_in > $mb_out? $mb_in : $mb_out) if $mod==3;
 return (0);
}

# Расшифровка составляющих оплачиваемого трафика
sub Get_name_traf
{
 return (!$_[0]? 'входящий' : $_[0]==1? 'исходящий' : $_[0]==2? 'вход+выход' : $_[0]==3? 'наибольшая составляющая' : '???');
}

# Расшифровка кода переработки
sub Get_text_block_cod
{
 return((
   '',
   'превышен лимит трафика',
   'превышен лимит денежной задолженности',
   '',
   'в данное время суток доступ заблокирован по условию тарифного плана'
  )[$_[0]]||'-');
}

# Получение названий трафика для соответствующего пресета
# Вход: № пресета
# Возврат: массив названий направлений от 1 до 9
sub Get_Name_Class
{
 my ($p)=(@_);
 return($PresetName{$p}{1}||"'Направление 1'",$PresetName{$p}{2}||"'Направление 2'",$PresetName{$p}{3}||"'Направление 3'",$PresetName{$p}{4}||"'Направление 4'",
        $PresetName{$p}{5}||"'Направление 5'",$PresetName{$p}{6}||"'Направление 6'",$PresetName{$p}{7}||"'Направление 7'",$PresetName{$p}{8}||"'Направление 8'",'Межсегментный');
}

$unlim_mb=999000000; # количество мб, начиная с которых считаем, что это анлим

1;
