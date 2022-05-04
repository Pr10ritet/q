#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

$FIELD='contract';	# ��� ���� � ������� users
$ALIAS='_mac';		# ����� � ������� �������������� ������
$ONLY_MAIN_ID=1;	# 1 - ������������ ������ �������� ������ (��� �������)

$pr_SuperAdmin or &Error('������ ��������');

$FIELD=&Filtr($FIELD);
$ALIAS=&Filtr($ALIAS);

$p=&sql_select_line($dbh,"SELECT * FROM dopfields WHERE field_alias='$ALIAS'");
$p or &Error("� ������� �������������� ����� �� ���������� ���� � ������� $ALIAS!");

$dopfield_id=$p->{id};
$template_num=$p->{template_num};

&DEBUGX("id ����: $dopfield_id, ������: $template_num");

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
       $existed='������ ������� �����������';
       $h=$dbh->prepare("INSERT INTO dopvalues SET parent_id=0");
       $h->execute;
       $rev=$h->{mysql_insertid} || $h->{insertid};
       if( !$rev )
       {
          $action=&Printf('[error]','������ sql!');
          next;
       }
       $action="������� ������� = $rev.".$br;
   }else
   {
      $h=&sql_select_line($dbh,"SELECT line_id,field_value FROM dopvalues ".
        "WHERE revision=$rev AND dopfield_id=$dopfield_id LIMIT 1");
      if( $h )
      {
         $existed=&bold('��: ').&Filtr_out($h->{field_value});
         $rows=&sql_do($dbh,"UPDATE dopvalues SET admin_id=0,field_value='$filtr_field',time=0 ".
           "WHERE line_id=".$h->{line_id}.' LIMIT 1');
         $action=&Printf('[error]','������ sql!') if !$rows;
         next;
      }
      $existed='������ �� ������� ����������, �� ������� ���� - ���.';
   }
   $rows=&sql_do($dbh,"INSERT INTO dopvalues (admin_id,parent_id,dopfield_id,field_value,time,revision) ".
     "VALUES (0,$id,$dopfield_id,'$filtr_field',0,$rev)");

   $action.=$rows? 'OK' : &Printf('[error]','������ sql!');
}
 continue
{
    $out.=&RRow('*','clllcl',$id,$name,$fio,$field,$existed,$action);
}

&sql_do($dbh,"DELETE FROM dopvalues WHERE parent_id=0");

$out or &Error('������ ������� users');
$OUT.=&Table('tbg1',&RRow('head','cccccc','id','�����','���',"�������� ���� $FIELD",'���� ������������?','��������').$out);

1;
