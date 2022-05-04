#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Fact=$F{act};
$Fop=$F{op};
$Ftime=int $F{time};
$Fid=int $F{id};

%subs=(
 'contacts'	=> 2,
 'c_grp'	=> 2,
 'dopfields'	=> 2,
# 'equip'	=> 2,
# 'eqtype'	=> 2,
 'nets'		=> 2,
 'newuser'	=> 2,
 'of'		=> 2,
 'plans3'	=> 2,
 'str'		=> 2,
 'sat'		=> 2,
 'usr_grp'	=> 2,
 'usr_pack'	=> 2,
 'workers'	=> 2,
 'points'	=> 2,
);

exists($subs{$Fact}) or &Error(&Printf('Неизвестная команда act=[filtr]',$Fact).$go_back);
$fname="$Nodeny_dir_web/o_$Fact.pl";
(-e $fname) or &Error(($pr_SuperAdmin? &Printf('Не найден файл [bold]',$fname) : 'модуль не найден.').$go_back);
$Mess_UntrustAdmin='Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.';
$scrpt.="&act=$Fact";
require $fname;
$VER==$VER_chk or &VerWrong($fname);

# name		- имя сущности в родительном падеже, например, 'данных клиента'
# tbl		- таблица
# field_id	- название ключевого поля, по которому происходит выборка уникального значения, например, 'id'

$menu=&o_menu.($PR{2} && $br.&ahref("$scrpt0&a=tune",'Главные настройки'));

$OUT.="<table class='width100 pddng'><tr>".
  "<td valign=top class=nav2 width=16%><br>".&Mess3('row2',$menu)."</td><$tc valign=top><br>";
$tend='</td></tr></table>';

$d->{form_header}={'!'=>1,'act'=>$Fact,'op'=>'save','time'=>$t,'rand'=>int(rand 2**32)};
$d->{button}=$d->{priv_edit}? 'Изменить' : 'Смотреть';

$then_url=$br2.&CenterA("$scrpt&op=list",'Далее &rarr;');

# Привилегии проверяем не раньше &o_getdata! - там они могут измениться

if( $Fop eq 'new' )
{
   &check_edit_priv($d->{priv_edit});
   $d->{name_action}='Создание '.$d->{name};
   $d->{form_header}{id}=0;
   &o_new;
   &o_show;
}
 elsif( $Fop eq 'edit' )
{
   &check_edit_priv($d->{priv_show});
   $d->{name_action}=($d->{priv_edit}? 'Изменение ':'Просмотр ').$d->{name};
   $d->{form_header}{id}=$Fid;
   &oper_getdata;
   &o_show;
}
 elsif( $Fop eq 'copy' )
{
   &check_edit_priv($d->{priv_edit});
   $d->{allow_copy} or &Error("Создание копии $d->{name} не предусмотрено.$go_back",$tend);
   $d->{name_action}='Создание копии '.$d->{name};
   &oper_getdata;
   $Fid=0;
   $d->{form_header}{id}=0;
   &o_show;
}
 elsif( $Fop eq 'save' )
{
   $Fid && &oper_getdata;
   &o_save;
   &check_edit_priv($d->{priv_edit});
   $sql=$d->{sql};
   $_=Digest::MD5->new;
   $param_hash=$_->add($sql)->b64digest;
   if( $Fid ) {&run_update} else {&run_insert}
}
 elsif( $Fop eq 'del' )
{
   &oper_getdata;
   &check_edit_priv($d->{priv_edit});
   &run_delete;
}
 elsif( $Fop && defined($d->{"addsub_$Fop"}) )
{
   &{ $d->{"addsub_$Fop"} };
}
 else
{
   &check_edit_priv($d->{priv_show});
   &o_list;
}

$OUT.=$tend;
&Exit;

sub check_edit_priv
{
 $_[0] or &Error("Для доступа недостаточно привилегий (act=$Fact, op=$Fop).$go_back");
}

sub oper_getdata
{
 $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='$d->{tbl}' AND act=2 AND fid=$Fid",'удалена ли запись');
 if ($p)
 {  # была удалена, однако не выводим сообщение! возможно запись присутствует (ручное создание и т.д.)
    # &the_short_time($p->{time},$t,1) - здесь единица указыват вставлять слово `сегодня`, если надо
    $d->{when_deleted}=&the_short_time($p->{time},$t,1)." запись № $Fid $d->{name} была удалена.".$then_url;
 }
 &o_getdata;
}

sub run_delete
{
 $d->{no_delete} && &Error("Удаление $d->{name} заблокировано системой, поскольку ".$d->{no_delete}.$go_back,$tend);

 $h=$d->{old_data}? 'Текущие данные:'.&div('message',$d->{old_data}) : '';
 $Ftime or &Error("Произвести удаление $d->{name}?".$br2.$h.$br.&CenterA("$scrpt&op=$Fop&id=$Fid&time=$t",'УДАЛИТЬ'),$tend);

 $rows=&sql_do($dbh,"DELETE FROM $d->{tbl} WHERE $d->{field_id}=$Fid LIMIT 1");
 $rows or &Error("Удаление $d->{name} НЕ выполнено.",$tend);

 &sql_do($dbh,"INSERT INTO changes SET tbl='$d->{tbl}',act=2,time=$Ftime,fid=$Fid,adm=$Admin_id","В таблице изменений зафиксируем, что данные с ключевым полем=$Fid, удалены");

 &{ $d->{sub_postdel} } if defined $d->{sub_postdel};
 &OkMess("<span class=big>Удаление $d->{name} выполнено</span>.".$then_url,$tend);

 $h=$d->{old_data} && ", $d->{old_data}";
 &ToLog("! $Admin_UU Удаление $d->{name} ($d->{field_id}=$Fid$h).");
}

sub run_insert
{
 $Frand=int $F{rand};
 $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='$d->{tbl}' AND act=1 AND time=$Ftime AND fid=$Frand AND adm=$Admin_id AND param_hash='$param_hash'",
      'Есть ли в таблице изменений информация о том, что данные уже созданы');
 $p && &Error("Вами послан повторный запрос на создание $d->{name}. Вероятно, вы обновили страницу с повторной посылкой данных. Данные уже были созданы ранее.".$then_url,$tend);

 $rows=&sql_do($dbh,"INSERT INTO $d->{tbl} SET $sql");
 $rows or &Error("Создание $d->{name} <span class=error>не выполнено</span>.".$then_url,$tend);

 &sql_do($dbh,"INSERT INTO changes SET tbl='$d->{tbl}',act=1,time=$Ftime,fid=$Frand,param_hash='$param_hash',adm=$Admin_id");

 $h=!!$d->{new_data} && &div('message',$d->{new_data});
 &OkMess("<span class=big>Создание $d->{name} выполнено</span>.".$h.$br2.&CenterA($scrpt,'Далее &rarr;'),$tend);
 &ToLog("$Admin_UU Создание $d->{name}. $d->{new_data}");
}

sub run_update
{
 $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='$d->{tbl}' AND act=3 AND fid=$Fid AND time=$Ftime AND adm=$Admin_id AND param_hash='$param_hash'");
 $p && &Error("Вами послан запрос изменения $d->{name} с абсолютно теми же данными, которые вы уже посылали. Вероятно, вы обновили страницу с повторной посылкой данных.",$tend);

 $rows=&sql_do($dbh,"UPDATE $d->{tbl} SET $sql WHERE $d->{field_id}=$Fid LIMIT 1");
 $rows or &Error(&Printf('Запрос на изменение [] [error].',$d->{name},'не выполнен'),$tend);

 &sql_do($dbh,"INSERT INTO changes SET tbl='$d->{tbl}',act=3,time=$Ftime,fid=$Fid,param_hash='$param_hash',adm=$Admin_id");

 $h=!!$d->{old_data} && &div('message',$d->{old_data}).' &rarr; ';
 $h=!!$d->{new_data} && $h.&div('message',$d->{new_data});
 &OkMess(&Printf('[span big][][]',"Изменение $d->{name} выполнено успешно.",$h,$then_url),$tend);

 $h=$d->{new_data}? ", $d->{old_data} &rarr; $d->{new_data}" : '';
 &ToLog("$Admin_UU Изменение $d->{name} ($d->{field_id}=$Fid$h)");
}

sub Check_SuperPriv
{
 $pr_SuperAdmin or &Error('Доступ запрещен.',$tend);
 $AdminTrust or &Error($Mess_UntrustAdmin,$tend);
} 


1;
