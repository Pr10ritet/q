#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$PR{106} or &Error('Доступ запрещен.');

$Fact=$F{act};

# Порядок вызова: 1я подпрограмма, 2я
%subs=(
 'sat_list'	=> \&sub_zero,	# Список сателлитов с общей таблицей мониторинга
 'sat_stat'	=> \&sub_zero,	# Статистика по конкретному агенту
 'sat_dstat'	=> \&sub_zero,	# Детальная статистики за срез по конкретному агенту
 'sat_help'	=> \&sub_zero,
 'kernel_stat'	=> \&sub_zero,	# Статистика ядра NoDeny
);


sub ShowMenu
{
 $OUT.="<table class='width100 pddng'><tr><td valign=top class=nav2 width=16%>".&Mess3('row2',
  &ahref("$scrpt&act=sat_list",'Мониторинг').
  &ahref("$scrpt&act=kernel_stat",'Ядро. Статистика трафика').
  &ahref("$scrpt&act=kernel_stat&mode=1",'Ядро. Тюнинг sql').
  &ahref("$scrpt&act=sat_help",'Помощь')).
 "</td><$tc valign=top><br>";
}

$tend='</td></tr></table>'.$br2;


$Sat_t_monitor=int $Sat_t_monitor; # Период времени в часах, в течение которого будут сохраняться данные по мониторингу сателлитов
$Sat_t_monitor=8 if $Sat_t_monitor<1; 
$Sat_t_monitor*=3600; # переведем в секунды

$Sat_t_no_ping=((int $Sat_t_no_ping)||11)*60; # переведем в секунды время, свыше которого если не будет данных по мониторингу, то соответствующего агента выделим красным цветом

$height_line=6; # высота в пикселях картинки, отображающей процесс мониторинга

$Fact='sat_list' unless defined $subs{$Fact};
&ShowMenu;
&{$Fact};
&{ $subs{$Fact} };
$OUT.=$tend;
&Exit;


# ---------------------
#    Статистика ядра
# ---------------------

sub kernel_stat
{
 $Fmode=int $F{mode};
 $Fyear=int $F{year} || $year_now;
 $list_year=&Set_year_in_list($Fyear);
 $Fmon=int $F{mon};
 $Fmon=$mon_now if $Fmon<1 || $Fmon>12;
 ($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
 $max_day=&GetMaxDayInMonth($Fmon,$Fyear);		# получим макимально возможное число в запрошенном месяце
 $Fday=int($F{day})||$day_now;
 $Fday=$max_day if $Fday>$max_day || $Fday<1;
 $OUT.=&form_a('#'=>1,'act'=>$Fact,'mode'=>$Fmode)."<select size=1 name=day>";
 $OUT.="<option value=$_".($Fday==$_?' selected':'').">$_</option>" foreach (1..31); # не надо 1..$max_day т.к. месяц может быть выбран один, а админ сменит на другой
 $OUT.="</select> $mon_list $list_year <input type=submit value='Показать'></form>";
 $time1=timelocal(0,0,0,$Fday,$Fmon-1,$Fyear);		# начало дня
 $time2=timelocal(59,59,23,$Fday,$Fmon-1,$Fyear);	# конец дня

 $sql="SELECT * FROM traf_info WHERE time>=$time1 AND time<=$time2 ORDER BY time DESC";
 
 if (!$Fmode)
 {
    $OUT.="* - какой тип трафика уже записан: 1 - поминутный, 2 - по нулевому пресету, 3 - детализация, 4 - неучтенный";
    $header=&RRow('head','ccccccccccc',
     'Время<br>среза<br>статистики',
     'Количество<br>обработанных<br>строк',
     'Объем<br>иформации,<br>полученной от<br>коллекторов,<br>байт',
     'Время<br>обсчета<br>направлений,<br>сек',
     'Время<br>добавления<br>трафика<br>клиентам,<br>сек',
     'Время<br>отключения<br>абонентов<br>превысивших<br>лимиты',
     'Время<br>получения<br>данных<br>трафика<br>для передачи<br>клиентам',
     'Время<br>записи<br>детализации<br>трафика',
     'Количество<br>записей<br>в кеше<br>адресов',
     'Запись<br>статистики<br>трафика,%',
     '*');
     #'Невыполненых<br>sql<br>детализации');
    $colspan=11;  
 }else
 {   
    $colspan=4;
    $header=&RRow('head','cc',
     'Время<br>среза<br>статистики',
     'Статистика выполнения sql-запросов в зависимости от их длины');
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
        {  # каждые 30 строк выводим хедер
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
    {  # объем переданных служебных данных
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
 $OUT.=&Table('tbg width100',"<tr class=head><$tc colspan=$colspan><br><b>Статистика ядра</b>$br2</td></tr>$header$out"); 
 if( $Fmode==1 )
 { # Отобразим справку в 3й колонке
   $OUT.="</td><$tc valign=top>".&MessX('Комментарии:<br><br><p class=story>В данной таблице предоставлены статистические данные, основанные '.
     'на времени выполнения ядром sql-запросов различных длин. Эта таблица предназначена для того, чтобы вы экспериментальным путем '.
     'подобрали наиболее оптимальную длину sql-запросов для максимального ускорения записи ядром статистики в БД.</p><p class=story>'.
     'После обсчета и начисления клиентам значений потребленного трафика, ядро начинает запись статистики трафика, что занимает '.
     'основную часть времени. Во время обсчета трафика, ядро формирует групповые sql-запросы: несколько запросов объединяет в один. '.
     'Как только длина результирующего запроса превысит значение, указанное в настройках ядра, то начинает формироваться новый sql. '.
     'В колонке '.&commas('эффективность').' отображается условный коээфициент, чем он больше тем эффективней расход времени на '.
     'выполнение sql соответствующей длины. Выберите оптимальное значение и перенесите его в настройки биллинга в секцию '.&commas('настройки ядра').
     '.</p><p class=story>По умолчанию тестирование эффективности sql выключено. Для того, начать тест, вам необходимо послать ядру сигнал '.
     &commas('Тюнинг sql').' в разделе '.&commas('Управление').'. Не забудьте послать сигнал отключения тюнинга после экспериментов.</p>');
 }
}


# ======================================================================================================================
#                                                    Мониторинг             
# ======================================================================================================================

# Загрузка конфига запрошенного сателлита
# Вход:
#  1 - № сателлита
# Выход:
#  1 - хеш массив с конфигом
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
   (('ядра','агента L2-авторизации','агента доступа','агента nomake')[$mod_id]||'неизвестного агента');
}

sub ShowAgentMonitor
{# отображение общей статистики по конкретному агенту
 # вход: id сателлита, id агента, имя сателлита, название агента
 my ($sat_id,$mod_id,$sat_name,$mod_name)=@_;
 my ($sth,$p,$tt,$tstart,$tend,$t2);
 my %f;
 my $ping_error=1; # пока установим признак, что данные статистики от агента не получались выше критического времени $Sat_t_no_ping сек

 $tend=$t-$ts*3600;
 $tstart=$tend-3600; # отображаем данные за период времени час
 $sth=$dbh->prepare("SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id AND time>$tstart AND time<$tend ORDER BY time DESC");
 $sth->execute;
 $tt=$tend;
 $t2=$tend-$Sat_t_no_ping; # если после этого значения времени будут данные о статистике, то все ок и $ping_error установим в 0
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
   "<tr class=head><td>&nbsp;</td><td>&nbsp;</td><$tc>Активность за $_[1]</td></tr>".
   "<tr class=tablebg><$tc>Сателлит</td><$tc>Агент</td><td>";
   
 foreach $i (0..11)
   {# в часе 12 периодов по 5 минут
    $OUT.="<img width=74 height=$height_line src='$img_dir/f1.gif'>";
    $OUT.="<img width=1 height=$height_line src='$img_dir/f2.gif'>";
   } 
 $OUT.='</td></tr>';

 &ShowAgentMonitor(0,0,'Ядро NoDeny','&nbsp;');
 
 $sth=&sql($dbh,"SELECT * FROM conf_sat ORDER BY login");
 while ($p=$sth->fetchrow_hashref)
 {
    $id=$p->{id};
    %c=&GetSatConfig($id);
    next unless $c{Noserver_monitor} || $c{L2_auth_monitor}; # ни один агент не мониторится
    &ShowAgentMonitor($id,1,$c{login},"L2-авторизации") if $c{L2_auth_monitor}; # 1 - id агента L2-авторизации
    &ShowAgentMonitor($id,2,$c{login},"доступа") if $c{Noserver_monitor}; # 2 - id агента noserver.pl
    &ShowAgentMonitor($id,3,$c{login},"nomake") if $c{Nomake_monitor}; # 3 - id агента nomake.pl
 }
 $OUT.="</table>";
}

sub sat_list
{
 $OUT.=&MessX(&bold('Мониторинг сателлитов')).$br;
 &ShowSatList(0,"последние 60 минут");
 $OUT.=$br3;
 &ShowSatList(1,"предыдущий час");
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="60; url='$scrpt'">};
}

# Вывод статистики запрошенного агента
sub sat_stat
{
 &GetLoginSat;
 
 $sql="SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id ORDER BY time DESC";
 ($sql,$OUT2,$rows,$sth)=&Show_navigate_list($sql,$start,60,"$scrpt&act=sat_stat&sat_id=$sat_id&mod_id=$mod_id");

 $OUT.="<table class='tbg3 width100'><tr class=head><$tc colspan=2>Статистика сателлита $login</td></tr>";
 $OUT.="<tr class=head><td colspan=2>$OUT2</td></tr>" if $OUT2; 
 $OUT.="<tr class=tablebg><$tc>Время</td><$tc>Информация</td></tr>";
 
 $a="$scrpt&act=sat_dstat&sat_id=$sat_id&mod_id=$mod_id&time=";
 while ($p=$sth->fetchrow_hashref)
 {
   ($time,$mod_id,$sat_id,$error,$info)=&Get_filtr_fields('time','mod_id','sat_id','error','info');
    if( $mod_id==1 )
    {  # агент L2-авторизации
       ($info,$ip_list)=split /\n/,$info;
       ($t_monint,$ips,$packets,$floodpackets,$ban_ip)=split /\|/,$info;
       $ban_ip=&bold($ban_ip) if $ban_ip;
       $info="Обработано пакетов: $packets. Пакетов определенных как флуд: $floodpackets. Уникальных ip, посылавших запросы: $ips. Забаненых ip: $ban_ip."
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
 $OUT.=&PRow."<td>Обработано пакетов</td><$td>".&bold($packets)."</td><td></td></tr>".
       &PRow."<td>Пакетов определенных как флуд</td><$td>".&bold($floodpackets)."</td><td>Количество пакетов, которые решено было игнорировать. Это не обязательно атака, возможно сателлит не справился с обработкой всех пакетов и решил некоторые забанить, либо же какой-нибудь клиент решил часто переключать режим авторизации</td></tr>".
       &PRow."<td>Уникальных ip</td><$td>".&bold($ips)."</td><td>Количество уникальных ip-адресов от которых получен хотябы 1 пакет. В обычных условиях (отсутствии атаки с подменой ip) это число примерно равно количеству клиентов, пытающихся авторизоваться на данном сателлите</td></tr>".
       &PRow."<td>Забаненых ip</td><$td>".&bold($ban_ip)."</td><td>Количество ip, которые забанены на небольшое время как защита от флуда</td></tr>".
       &PRow."<td valign=top>Забаненые ip</td><$td>$ip_list</td><td valign=top>Список ip, которые были забанены. Обратите внимание, что данные ip это не обязательно нарушители. Это могут быть клиенты пытающиеся очень часто менять режим авторизации. Также, возможно, в результате нехватки ресурсов сателлита он не успевает быстро обработать все запросы, поэтому авторизаторы пытаются повторить посылку. В результате, забаненый авторизатор переключится на резервный сателлит тем самым снизив нагрузку на текущий.<br><br>Если список ip большой, то не все ip отображены здесь.</td></tr>";
       
}

# Вывод детальной статистики за срез запрошенного агента
sub sat_dstat
{
 &GetLoginSat;

 $time=int $F{time};
 $tt=&the_time($time);
 $sth=$dbh->prepare("SELECT * FROM sat_log WHERE sat_id=$sat_id AND mod_id=$mod_id AND time=$time LIMIT 1");
 $sth->execute;
 &Error("В указанный срез времени $tt статистика агента $mod_id сателлита $login отсутствует.",$tend) unless $p=$sth->fetchrow_hashref;
 
 ($error,$info)=&Get_filtr_fields('error','info');
 $OUT.="<table class='tbg3 width100'><tr class=head><$tc colspan=3>Информация по сателлиту $login</td></tr>";
 &Show_Mod_1($error,$info) if $mod_id==1;
 $OUT.="</table>";
}



sub sat_help
{
 $OUT.=<<MESS
<div class='message lft'>Помощь<br><br>
<b>Мониторинг сателлитов</b> предназначен для своевременного обнаружения проблемной ситуации, которая может быть обусловлена
неработоспособностью, некоректной работоспособностью или недоступностью какого-либо агента NoDeny, обслуживающего
определенную группу клиентов. Сателлит - это сервер, на котором запускаются агенты, предназназначенные для управления
доступом, авторизации и снятия статистики. Каждый агент через определенные промежутки времени записывает в центральную
базу данных информацию о своем состоянии. Если определенное количество времени информация не поступает, следует
"бить тревогу". Критическое время задается суперадминистратором. Сигналом, что данные от определенного агента не
поступали больше этого критического времени, является подсвечивание красным цветом строки-мониторинга данного агента.<br>
<br>
В таблице мониторинга желтая полоса обозначает ход времени. На этой полосе в зависимости от времени получаения данных
от агента, в определенной позиции ставится пометка зеленого или красного цвета. Зеленая пометка обозначает нормальный
режим работы. Красная означает, что эть важные замечания или проблемы в тот момент времени. Эти замечания вы можете
посмотреть в детальной статистике агента
</div>
MESS
   
}

1;
