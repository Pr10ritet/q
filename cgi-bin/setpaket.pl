#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});
(!$pr_edt_usr || !$PR{76}) && &Error('Нет прав');

&LoadMoneyMod;

$Fid=int $F{mid};
$Fact=$F{act};
$Fpaket=int $F{paket};

$OUT.=$br;

$U=&Get_users($Fid);
defined($U->{$Fid}{grp}) || &Error("Учетная запись клиента id=$Fid не существует.$go_back");
$Fid=$U->{$Fid}{mid} || $Fid;

$UGrp_allow{$U->{$Fid}{grp}}<2 && &Error("Запись клиента id=$Fid в группе, доступ к которой вам запрещен.$go_back");

%tarifs=();
foreach $i (1..$m_tarif)
{
   next if !$Plan_name[$i] || !$Plan_allow_show[$i];
   # основной тариф в начало списка
   $tarifs{$i}=($Plan_flags[$i]=~/e/ && ' &nbsp;&nbsp;').$Plan_name[$i];
} 

$pakets='<select name=paket size=1>';
$pakets.="<option value=$_".($Fpaket==$_ && ' selected').">".&Del_Sort_Prefix($tarifs{$_})."</option>" foreach (sort {$tarifs{$a} cmp $tarifs{$b}} keys %tarifs);
$pakets.='</select>';

$year=$year_now+1900;
$day=$mon=0;
&show_form unless $Fact;

$F{date}=~s|\s||g;
$F{date}!~/^(\d+).(\d+)\.(\d+)$/ && &show_err('дата задана неверно. Задайте в виде '.&commas('день.месяц.год'));
($day,$mon,$year)=(int $1,int $2,int $3); # уберем нули!
($mon<1 || $mon>12) && &show_err('месяц задан неверно.');
$year+2000 if $year<1900;
$max_day=&GetMaxDayInMonth($mon,$year-1900);
$day<1 && &show_err('день задан неверно.');
$day>$max_day && &show_err("день задан неверно: в $year году в $mon-м месяце $max_day ".($max_day==31? 'день':'дней'));

$set_time=timelocal(0,0,0,$day,$mon-1,$year-1900);
$set_time<$t && &show_err("дата $day.$mon.$year уже в прошлом. Необходимо указать будущее время.");

(!$Plan_name[$Fpaket] || !$Plan_allow_show[$Fpaket]) && &show_err('не задан пакет тарификации.');

$p=&sql_select_line($dbh,"SELECT * FROM pays WHERE mid=$Fid AND type=50 AND category=431 AND reason LIKE '$day.$mon.$year:%'");
$p && &Center_Mess("Предупреждение: на $day.$mon.$year уже заказана смена пакета, перезаписываю");

$rows=&sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,type=50,category=431,reason='$day.$mon.$year:$Fpaket',time=unix_timestamp()");
&Error('Внутрення ошибка.') if $rows<0;
&OkMess("$day.$mon.$year произойдет смена тарифного плана на ".&commas($Plan_name_short[$Fpaket]).$br2.
   &CenterA("$scrpt0&a=user&id=$Fid",'Данные клиента'));

&Exit;

sub show_err
{
 $OUT.=&error('Внимание: ',$_[0],1);
 &show_form;
}

sub show_form
{
 $OUT.=&MessX(&div('cntr',
   &form('!'=>1,'act'=>1,'mid'=>$Fid,"Выберите пакет: $pakets и дату: ".&input_t('date',"$day.$mon.$year",12,12).
    "$br$br$br в 0 часов 0 минут будет произведена смена пакета на указанный$br$br$br".
    &submit_a('Выполнить')
   )
 ));
 &Exit;
}

1;
