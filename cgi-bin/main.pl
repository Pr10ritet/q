#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

&LoadMoneyMod;

!$Tarif_loaded && $pr_SuperAdmin && $Admin_id && ($OUT.=&error('Внимание!','Произошла ошибка при загрузке тарифов. '.
  'Возможно вы не ввели ни одного тарифа либо указали неправильно название таблицы с тарифами в настройках'));

if( !$Admin_id )
{
   $OUT.=&Mess3('row2 nav2',
     &ahref("$scrpt0&a=admin",'Привилегии администраторов').$br.
     &ahref("$scrpt0&a=tune",'НАСТРОЙКИ')
   );
   &Exit;
} 

$OUT.="<table cellpadding=3 cellspacing=4><tr><$tc valign=top>";

$list_year=&Set_year_in_list($year_now);
($mon_list,$mon_name)=&Set_mon_in_list($mon_now);

$out='';
$out.=&ahref("$scrpt0&a=mytune",'Личные настройки').$spc if $Admin_id && !$PR{108};
$out.=&ahref("$scrpt0&a=adduser",'Новый клиент').$spc if $PR{88};
#$out.=&ahref("$scrpt0&a=multipays",'Мультиплатежи') if $pr_pays_create && $Allow_grp;
#$out.=&ahref("$scrpt0&a=multipays&act=old",'Дооформить') if $pr_pays_create && $Allow_grp;
$out.=&ahref("$scrpt0&a=oper&act=points",'Топология сети').$spc if $pr_topology;
$out.=&ahref("$scrpt0&a=oper&act=contacts",'Контакты').$spc if $pr_contacts;
$out.=&ahref("$scrpt0&a=check",'Проверка').$spc if $pr_show_fio;
$out.=&ahref("$scrpt0&a=report",'Фин. отчет').$spc if $pr_fin_report;
$out.=&ahref("$scrpt0&a=oper&act=workers",'Работники').$spc if $pr_workers;
$out.=&ahref("$scrpt0&a=job&act=setjob",'Задания по сети').$spc.
      &ahref("$scrpt0&a=job&act=grafik",'Подготовленные задания').$spc if $pr_workers_work;
$out.=&ahref("$scrpt0&a=dopdata&parent_type=1",'Оборудование').$spc if $PR{103};
$out.=&ahref("$scrpt0&a=tarif",'Тарифы').$spc if $pr_tarifs;
$out.=&ahref("$scrpt0&a=monitoring",'Мониторинг').$spc if $pr_monitoring;
$out.=&ahref("$scrpt0&a=cards",'Карточки пополнения счета').$spc if $pr_cards;
$out.=&ahref("$scrpt0&a=superoper&act=add_chngpkt",'Массовое изменение пакета').$spc if $pr_SuperAdmin;
foreach (values %PluginsAdm)
{
   ($cod,$name)=split /-/,$_;
   $out.=&ahref("$scrpt0&a=$cod",$name).$spc if $name;
}
$out.=&ahref("$scrpt0&a=admin",'Привилегии администраторов').$spc if $pr_edt_adm;
$out.=&ahref("$scrpt0&a=tune&i=8",'Настройки').$spc if $pr_main_tunes;
$OUT.=&Mess3('row2',&div('nav2',$out));
$out='';

# Пройдемся по группам в базе т.к. админ мог наложить ограничения на %UGrp_allow
$out='';
$sth=&sql($dbh,"SELECT * FROM user_grp ORDER BY grp_name");
while ($p=$sth->fetchrow_hashref)
{
   ($grp_id,$grp_admins)=&Get_fields('grp_id','grp_admins');
   $grp_admins=~/,$Admin_id,/ or next;
   $out.=&div('row2',"<input type=checkbox value=1 name=g$grp_id ".($Atemp_block_grp=~/,$grp_id,/ && ' checked').'> '.&Filtr_out($p->{grp_name}));
}
if( $out )
{
   $out=&form('!'=>1,'a'=>'operations','act'=>'set_temp_block',
     "Отметьте группы, которые вы хотите временно исключить из работы:".$br2.
     "<div id=grp>$out</div>".$br.
     &ahref('#','Отметить все',qq{onclick="SetAllCheckbox('grp',1); return false;"}).$br.
     &ahref('#','Убрать все',qq{onclick="SetAllCheckbox('grp',0); return false;"}).$br.
     &submit_a('Выполнить'));
   $OUT.=&Mess3('tablebg',$out);
   $out='';
}

$OUT.="</td><$tc valign=top>";

$sp2="<img src='$spc_pic' width=1 height=5>";
%f=('#'=>1,'a'=>'listuser','f'=>'n');
$find=' '.&submit('Найти');
$out.=&div('row2',$sp2.&form(%f,'Поиск по имени:'.$br.&input_t('name','',20,64).$find).$sp2).$spc if $pr_show_fio;
$out.=&div('row2',$sp2.&form(%f,'what_search'=>'login','Поиск по логину:'.$br.&input_t('name','',20,64).$find).$sp2).$spc;
$out.=&div('row2',$sp2.&form(%f,'what_search'=>'ip','Поиск по ip:'.$br.&input_t('name','',20,64).$find).$sp2).$spc;
$out.=&div('row2',$sp2.&form(%f,'what_search'=>'contract',"Поиск по контракту:".$br.&input_t('name','',20,64).$find).$sp2).$spc;
$out.=&div('row2',$sp2.&form('#'=>1,'a'=>'listuser','f'=>'8','what_search'=>'contract',"Клиентов, заключивших договор:$br$mon_list $list_year $find").$sp2).$spc;
$out.=&div('row2',$sp2.&form('a'=>'operations','act'=>'searchmail',"Поиск по email:".$br.&input_t('email','',20,64).$find).$sp2).$spc if $mail_enable && $pr_mail;
$out.=&div('row2',$sp2.&form('#'=>1,'a'=>'listuser','f'=>'9','Точка подключения:'.$br.&input_t('box','',7,7).$find).$sp2).$spc;
$out.=&div('row2',$sp2.&form('#'=>1,'a'=>'user','ID клиентской записи:'.$br.&input_t('mid','',7,7).$find).$sp2).$spc;

$OUT.=&Mess3('tablebg',&div('cntr',$out)) if $Allow_grp;
$out='';

# Пройдемся по группам
foreach (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
{
   $UGrp_allow{$_} or next; # доступ к этой группе полностью заблокирован
   $out.=&ahref("$scrpt0&a=listuser&f=&grp=$_",$UGrp_name{$_});
}

$OUT.=&Mess3('tablebg',&div('nav3',$out)) if $Allow_grp;

$OUT.="</td><$tc valign=top>";

%tarifs=();
foreach $i (1..$m_tarif)
{
   next if !$Plan_name[$i] || !$Plan_allow_show[$i];
   $tarifs{$i}=$Plan_name[$i];
} 
  
$out='';
foreach $i (sort {$tarifs{$a} cmp $tarifs{$b}} keys %tarifs)
{
   $h=$Plan_mb1[$i]<$unlim_mb? $Plan_mb1[$i]:'безлимитный';
   $out.=&RRow('*','ll',&ahref("$scrpt0&a=listuser&f=h&p=$i",$Plan_name_short[$i]),'&nbsp;&nbsp;&nbsp;'.$Plan_price[$i]);
}

$OUT.=$out && &MessX(&Table('tbg width100',&RRow('head','cc','Название',"Цена, $gr").$out)).$spc;
$out='';

foreach $i (sort {$Plans3{$a} cmp $Plans3{$b}} keys %Plans3)
{
   $out.=&RRow('*','ll',&ahref("$scrpt0&a=listuser&f=r&p=$i",$Plans3{$i}{name_short}),'&nbsp;&nbsp;&nbsp;'.$Plans3{$i}{price});
}
$OUT.=$out && &MessX(&Table('tbg width100',&RRow('head','cc','Название',"Цена, $gr").$out)).$spc;
$out='';

$OUT.="</td><$tc valign=top>";

# === 4й столбец ===
sub show_cid
{
 my ($start_cid,$len,$money)=@_;
 my $end_cid=$start_cid+$len-1;
 my $str="$start_cid .. $end_cid";
 
    $outc.=&RRow('*','lll',$money,$str,$len);
    return;
 
 if (length($start_cid) != length($end_cid))
 {
    $outc.=&RRow('*','lll',$money,$str,$len);
    return;
 }
 my $i=0;  
 while ($start_cid>0 && $start_cid!=$end_cid)
 {
    $start_cid=int($start_cid/10);
    $end_cid=int($end_cid/10);
    $i++;
 }
 $start_cid='' unless $start_cid;
 $outc.=&RRow('*','lll',$money,"<a href='#' OnClick='javascript: ShowCardId($end_cid,$i);'>$str</a>",$len);
}

$p=&sql_select_line($dbh,"SELECT COUNT(*) FROM cards WHERE r=$Admin_id",'Количество карточек пополнения счета на руках админа');
if ($p && $p->{'COUNT(*)'}>0)
{
   $out.=&form('!'=>1,'a'=>'operations','act'=>'cardsail',
      &bold($p->{'COUNT(*)'}).' карточек пополнения счета.'.$br2.
      &Table('table1 width100',&RRow('row2','rl','Карточку № '.&input_t('cardid','',15,32,'id=cardid'),&submit_a('Продать')))
   );
   $i=$last_money=$start_cid=0;
   $outc='';
   $sth=&sql($dbh,"SELECT cid,money FROM cards WHERE admin_sell=0 AND r=$Admin_id ORDER BY cid");
   while ($p=$sth->fetchrow_hashref)
   {
      ($cid,$money)=&Get_fields('cid','money');
      $start_cid||=$cid;
      $last_money||=$money;
      next if $cid==($start_cid+$i) && $money==$last_money;
      &show_cid($start_cid,$i,$last_money);
      $last_money=$money;
      $start_cid=$cid;
      $i=0;
   }
    continue
   {
      $i++;
   } 
   &show_cid($start_cid,$i,$money) if $start_cid;
   $out.="<br><div id=carddiv></div>Доступные карточки:".$br2.
         "<table class=width100>".&RRow('head','ccc','Номинал','Диапазон','Штук')."$outc</table>" if $outc;
   $out.=$br.&div('nav2 cntr',&ahref("$scrpt0&a=operations&act=cards_oper",'Операции &rarr;'));
   $OUT.=&MessX($out).$spc;
   $DOC->{header}.="<script language='javascript' type='text/javascript'>\n".
        "function ShowCardId(CardId,n) {\n".
        "document.getElementById('cardid').value=CardId;\n".
        "document.getElementById('carddiv').innerHTML='<span class=data1>Дополните '+n+' цифрами</span><br><br>';\n".
        "document.getElementById('cardid').focus();\n".
        "}\n</script>\n";
}
{
 $Allow_grp or last;
 $out='Клиенты:'.$br2;

 $out.=&div('nav2',&ahref("$scrpt0&a=listuser&f=w",'На подключении').&ahref("$scrpt0&a=listuser&f=c&cs=-1"," C состоянием не 'Все Ок'"));

 $out.=$br2.'Подготовленные задания:'.$br2;
 $i=0;
 foreach (@jobs) {$out.=&ahref("$scrpt0&a=listuser&f=j&job=".$i++,$_).$br}

 $out.=$br2.'Состояние:'.$br2;
 foreach (sort {$cstates{$a} cmp $cstates{$b}} keys %cstates)
 {
    next if !$_ || $_==9;
    $out.=&ahref("$scrpt0&a=listuser&f=c&cs=$_",$cstates{$_}).$br;
 }

 $out.=$br2.'Фильтр:'.$br2;

 $a="$scrpt0&a=listuser";
 $out.=&ahref("$a&f=2",'Авторизованные сейчас').$br;
 $out.=&ahref("$a&f=1",'С балансом &lt;0 без услуг').$br.
      &ahref("$a&f=7",'С балансом &lt;0 с услугами').$br.
      &ahref("$a&f=e",'Нулевой трафик').$br if $pr_show_traf;
 $out.=&ahref("$a&f=3",'Кому запрещен интернет').$br;
 $out.=&ahref("$a&f=6",'Без установленого лимита').$br;
 $out.=&ahref("$a&f=a",'Имеющие алиасы').$br;
 $out.=&ahref("$a&f=b",'Не указана точка подключения').$br;
 $out.=&ahref("$a&f=g",'Без авторизации').$br;
 $out.=&ahref("$a&f=f",'У кого заказана смена пакета').$br;
 $out.=&ahref("$a&f=5",'С активированными услугами').$br;
 $out.=&ahref("$a&f=p",'Работают не с начала месяца').$br;

 if( $pr_topology )
 {  # карты
    $out2=$br2.'Карты:'.$br2;
    foreach (0..10)
    {
       next if ${"MP_name$_"} eq '';
       $mName=${"MP_name$_"};
       $out2.=&ahref("$scrpt0&a=map&i=$_",$mName);
    }
    $out.=&div('nav2',$out2);
 } 

 $OUT.=&MessX($out).$spc;
 $out='';
}

$OUT.='</td></tr></table>';    

1;
