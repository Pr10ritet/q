#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

$FIELD='contract';	# имя поля в таблице users
$ALIAS='_mac';		# алиас в таблице дополнительных данных
$ONLY_MAIN_ID=1;	# 1 - обрабатывать только основные записи (без алиасов)

$pr_SuperAdmin or &Error('Доступ запрещен');

$FIELD=&Filtr($FIELD);
$ALIAS=&Filtr($ALIAS);

$p=&sql_select_line($dbh,"SELECT * FROM dopfields WHERE field_alias='$ALIAS'");
$p or &Error("В таблице дополнительных полей не существует поля с алиасом $ALIAS!");

$dopfield_id=$p->{id};
$template_num=$p->{template_num};

&DEBUGX("id поля: $dopfield_id, шаблон: $template_num");

$out='';
$sth=&sql($dbh,'SELECT * FROM users'.(!!$ONLY_MAIN_ID && ' WHERE mid=0'));
while ($p=$sth->fetchrow_hashref)
{
   ($id,$fio,$name,$field)=&Get_fields('id','fio','name',$FIELD);
   $field=(split/\|/,$field)[1];
   $filtr_field=&Filtr_mysql($field);
   $action='OK';
   $h=&sql_select_line($dbh,"SELECT MAX(revision) AS rev FROM dopdata ".
     "WHERE parent_id=$id AND template_num=$template_num");
   $rev=$h->{rev};
   if( !$rev )
   {
       $existed='данные никогда создавались';
       $h=$dbh->prepare("INSERT INTO dopvalues SET parent_id=0");
       $h->execute;
       $rev=$h->{mysql_insertid} || $h->{insertid};
       if( !$rev )
       {
          $action=&Printf('[error]','Ошибка sql!');
          next;
       }
       $action="Создана ревизия = $rev.".$br;
   }else
   {
      $h=&sql_select_line($dbh,"SELECT line_id,field_value FROM dopvalues ".
        "WHERE revision=$rev AND dopfield_id=$dopfield_id LIMIT 1");
      if( $h )
      {
         $existed=&bold('да: ').&Filtr_out($h->{field_value});
         $rows=&sql_do($dbh,"UPDATE dopvalues SET admin_id=0,field_value='$filtr_field',time=0 ".
           "WHERE line_id=".$h->{line_id}.' LIMIT 1');
         $action=&Printf('[error]','Ошибка sql!') if !$rows;
         next;
      }
      $existed='Данные по шаблону существуют, но целевое поле - нет.';
   }
   $rows=&sql_do($dbh,"INSERT INTO dopvalues (admin_id,parent_id,dopfield_id,field_value,time,revision) ".
     "VALUES (0,$id,$dopfield_id,'$filtr_field',0,$rev)");

   $action.=$rows? 'OK' : &Printf('[error]','Ошибка sql!');
}
 continue
{
    $out.=&RRow('*','clllcl',$id,$name,$fio,$field,$existed,$action);
}

&sql_do($dbh,"DELETE FROM dopvalues WHERE parent_id=0");

$out or &Error('пустая таблица users');
$OUT.=&Table('tbg1',&RRow('head','cccccc','id','Логин','ФИО',"Значения поля $FIELD",'Поле существовало?','Действие').$out);

1;
