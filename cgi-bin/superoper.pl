#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Mess_UntrustAdmin='Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.';

%subs=(
 'add_chngpkt'	=> \&check_priv,	# Массовое изменение пакета
);

$Fact=$F{act};
exists($subs{$Fact}) or &Error('Неизвестная команда act='.&Filtr_out($Fact).$go_back);
$scrpt.="&act=$Fact";

&{ $subs{$Fact} };
&{$Fact};
&Exit;

sub check_priv
{
 $pr_SuperAdmin or &Error('Доступ запрещен.',$tend);
 $AdminTrust or &Error($Mess_UntrustAdmin,$tend);
}

# ==============================================================================
#				Массовое изменение пакета
# ==============================================================================
sub add_chngpkt
{
 $Fpkt1=int $F{pkt1};
 $Fpkt2=int $F{pkt2};
 $Fnext=$F{next}?1:0;
 $pkt1='<select name=pkt1 size=26><option value=-1 selected>Выберите пакет</option>';
 $pkt2='<select name=pkt2 size=26><option value=-1 selected>Выберите пакет</option>';
 %goodpkt=();

 if ($Fnext)
 {
    $field='next_paket';
    $name_zero='ПАКЕТ НЕ ЗАКАЗАН';
    $pkt2.="<option value=0 selected>$name_zero</option>";
    $goodpkt{0}=1;
    $OUT.=&MessX('Массовое изменение <b>заказанных на следующий месяц</b> пакетов тарификации.').'<br>';
 }else
 {
    $field='paket';
    $name_zero="несуществующий пакет № 0";
    $OUT.=&MessX('Массовое изменение <b>текущих пакетов</b> тарификации.').'<br>';
 } 

 $sth=&sql($dbh,"SELECT COUNT(*) AS n,u.$field,p.name FROM users u LEFT JOIN plans2 p ON u.$field=p.id WHERE u.mid=0 GROUP BY p.id ORDER BY p.name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($paket,$name,$n)=&Get_filtr_fields($field,'name','n');
    $n=sprintf("%06d",$n);
    $pkt1.="<option value=$paket>$n - ".($paket? $name || "Несуществующий № $paket" : $name_zero).'</option>';
 }

 $sth=&sql($dbh,"SELECT id,name FROM plans2 WHERE name<>'' ORDER BY name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($id,$name)=&Get_filtr_fields('id','name');
    $goodpkt{$id}=1;
    $pkt2.="<option value=$id>$name</option>";
 }

 unless ($F{ok})
 {
    $OUT.=&Table('tbg3',&form('!'=>1,'act'=>'add_chngpkt','next'=>$Fnext,
        &RRow('head','C','В левой колонке выберите пакет, клиенты которого будут переведены на выбранный в правой колонке пакет.<br>Перед названием пакета указано количество клиентов на данном пакете.').
        &RRow('*','cc',"$pkt1</select>","$pkt2</select>").
        &RRow('*','C',"<br>введите здесь слово 'ok' ".&input_t('ok','',4,4).$br2.&submit_a('Изменить') )));
    &Exit;
 }

 (lc($F{ok}) eq 'ok') or &Error("Вы неправильно ввели кодовое слово подтверждающее ваши намерения.$go_back");
 $goodpkt{$Fpkt2} or &Error("Целевой пакет указан неверно.$go_back");
 $rows=&sql_do($dbh,"UPDATE users SET $field=$Fpkt2 WHERE $field=$Fpkt1");
 &OkMess('Массовое изменение пакета тарификации завершено.'.$br2.'Изменен пакет у '.&bold($rows>0? $rows:0).' клиентов.');
}

1;
