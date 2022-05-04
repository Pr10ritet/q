#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> '��������������� ����',
	'tbl'		=> 'dopfields',
	'field_id'	=> 'id',
	'priv_show'	=> $pr_main_tunes,
	'priv_edit'	=> $pr_edt_main_tunes,
};

@Parent_types=(
 '�������',
 '������������',
);

@Field_types=(
 '�����',			# 0
 '����� �������������',		# 1
 '������������',		# 2
 '������������ �������������',	# 3
 '��������� ������������',	# 4
 '��������� �������������',	# 5
 '��/���',			# 6
 '�������� � �������',		# 7
 '���������� ������',		# 8
 '������',			# 9
);

%Fields_flags=(
 'a' => '����������� ������ ��������',
 'b' => '������� ������� � ������',
 'c' => '������� ������� � �����',
 'd' => '������������� � ������� ��������',
 'e' => '������������� � ��������� �������',
 'f' => '������� ��� �������',
 'q' => '��������� ���� (��������� ��� ������)',
 'h' => '����������',
);

sub o_menu
{
 my $menu=&ahref($scrpt,'������ ���.�����');
 $menu.=&ahref("$scrpt&op=new",'������� �����') if $pr_edt_main_tunes;
 my $tmpls=join '',map{ &ahref("$scrpt&tmpl=$_", (split /-/,$Dopfields_tmpl{$_})[0]) } sort{$a <=> $b} keys %Dopfields_tmpl;
 $menu.=$br.'�������:'.$br.$tmpls if $tmpls;
 $menu.=$br.&ahref("$scrpt0&a=operations&act=help&theme=dopfields",'�������');
 return	$menu;
}

sub o_list
{
 $out='';
 $Ftmpl=int $F{tmpl};
 $where=$Ftmpl? "WHERE template_num=$Ftmpl" : '';
 $sth=&sql($dbh,"SELECT * FROM dopfields $where ORDER BY parent_type,template_num,field_name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($id,$template_num,$parent_type,$field_type,$field_name,$comment,$field_flags)=&Get_fields qw(
      id  template_num  parent_type  field_type  field_name  comment  field_flags );
    $h=&Filtr_out($Dopfields_tmpl_name{$template_num});
    $h||=!!$template_num && "<span class=error>$template_num</span>";
    $out.=&RRow('*','ccclcccc',
       $id,
       &Printf('&nbsp;&nbsp;[span disabled]',$Parent_types[$parent_type]||'?'),
       '&nbsp;&nbsp;'.$h,
       &Printf('&nbsp;&nbsp;[filtrfull]',$field_name),
       $Field_types[$field_type] || '<span class=error>�������� ���</span>',
       $field_flags=~/q/? '��' : '',
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       ($pr_edt_main_tunes && &ahref("$scrpt&op=del&id=$id",'X'))
    );
 }

 $out or &Error(($Ftmpl? '� ��������� �������' : '� ���� ������').' ���� �� ������� �������������� ����.'.$br2.&CenterA("$scrpt&op=new&tmpl=$Ftmpl",'������� &rarr;'),$tend);

 $OUT.=&Table('tbg3 nav3 width100',
   &RRow('head','8',&bold_br('������ �������������� �����')).
   &RRow('tablebg','cccccccc','id','������','������','�������� ����','���','���������','','�������').$out);
}

sub o_new
{
 $template_num=int $F{tmpl};
 $parent_type=$field_type=0;
 $field_name=$field_alias=$comment=$field_flags=$field_template='';
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM dopfields WHERE id=$Fid");
 $p or &Error($d->{when_deleted} || "������ ��������� ������ ��������������� ���� ����� $Fid",$tend);
 ($template_num,$parent_type,$field_type,$field_name,$field_alias,$comment,$field_flags,$field_template)=&Get_fields qw(
   template_num  parent_type  field_type  field_name  field_alias  comment  field_flags  field_template );
 $field_name=&Filtr($field_name);
 $d->{name}='��������������� ���� '.&commas($field_name);
}

sub o_show
{
 $i=0;
 $parent_types=join '',map {"<option value=$i".($parent_type==$i++ && ' selected').">$_</option>"} @Parent_types;
 $i=0;
 $field_types=join '',map {"<option value=$i".($field_type==$i++ && ' selected').">$_</option>"} @Field_types;
 $tmpl_list=join '',map {"<option value=$_".($template_num==$_ && ' selected').'>'.
    ( (split /-/,$Dopfields_tmpl{$_})[0] ||$Dopfields_tmpl{$_}).'</option>'}  sort {$a <=> $b} keys %Dopfields_tmpl;

 $flags=join $br,map{ "<input type=checkbox name=flag$_ value=1".($field_flags=~/$_/ && ' checked').'> '.$Fields_flags{$_} } sort {$a cmp $b} keys %Fields_flags;
 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     #&RRow('*','ll','��� ���� ���������',"<select name=parent_type size=1>$parent_types</select>").
     &RRow('*','ll','������',"<select name=template_num size=1><option value=0>&nbsp;</option>$tmpl_list</select>").
     &RRow('*','ll','�������� ����',&input_t('field_name',$field_name,48,127)).
     &RRow('*','ll','�����',&input_t('field_alias',$field_alias,48,127)).
     &RRow('*','ll','��� ����',"<select name=field_type size=1>$field_types</select>").
     &RRow('*','ll','���������',$flags).
     &RRow('*','ll','���������� ���������',&input_t('field_template',$field_template,48,127)).
     &RRow('*','ll','�����������',&input_ta('comment',$comment,30,5)).
     ($pr_edt_main_tunes && &RRow('head','C',&submit_a('���������')))
   )
 );
 $h=0;
 $OUT.=$br2.&MessX(&bold('��������!').' �������������� ���������� ��������� ������ ���� ������������ � ���������� ����������.'.$br.
  '� NoDeny �� �������� �������� � ���.����� ���������� ����������, ������� ��� ������������ ������.'.$br2.
  '�� ������ ������������ ������������ �������:'.$br2.'<ul>'.
  '<li>'.&input_t($h++,'^.+$',15,100).' - ��������� ������ ������� �� ����� ������ �������. �.�. ������ �������� ������� �� �����������</li>'.
  '<li>'.&input_t($h++,'^.{5,100}$',15,100).' - ��������� ������ ������� �� 5 �� 100 ��������</li>'.
  '<li>'.&input_t($h++,'^\d$',15,100).' - ��������� ������ � ���� ����� �����, �.� ����������� ������ ����� �� 0 �� 9</li>'.
  '<li>'.&input_t($h++,'^-?\d{1,3}$',15,100).' - ����������� ������ ����� �� -999 �� 999</li>'.
  '<li>'.&input_t($h++,'^[^!]+$',15,100).' - ����������� ������� ��������������� ����</li>'.
  '<li>'.&input_t($h++,'^[^ ,.]+$',15,100).' - �� ����������� ������������ �������, �������, �����</li>'.
  '<li>'.&input_t($h++,'!$',15,100).' - �������� ��������� ������ ������������ ��������������� ������</li>'.
  '<li>'.&input_t($h++,'^\d+\.\d+\.\d+\.\d+$',15,100).' - ������ ��� ip, �� ��������� ������ �� 255 �����!</li>'.
  '<li>'.&input_t($h++,'^[A-Za-z]+$',15,100).' - ����������� ������� ����� ������ ���������� �������, ����� ������ �������, ������� ������� ���������</li>'.
  '</ul>',1);
}

sub o_save
{
 $Ffield_name=&Printf('[filtr|trim]',$F{field_name});
 if( $Ffield_name eq '' )
 {
    $OUT.=&MessX(&Printf('[bold] []','��������!','�� ������ �������� ����. ������������ � �������� `�������������� ����`'),0,1);
    $Ffield_name='�������������� ����';
 }
 $Ffield_alias=&Printf('[filtr|trim]',$F{field_alias});
 $Ffield_type=int $F{field_type};
 $Ffield_type=0 if $Ffield_type<0 || !$Field_types[$Ffield_type];
 $Ffield_template=&Filtr_mysql($F{field_template});
 $Ftemplate_num=int $F{template_num};
 $Ftemplate_num=0 if $Ftemplate_num<0 || !defined($Dopfields_tmpl{$Ftemplate_num});
 $Fparent_type=int($Ftemplate_num/100);
 # ���������� ����� ��� �������� ��������� ���� ������!
 $Ffield_flags=join '',map{ $F{"flag$_"} && $_} sort {$a cmp $b} keys %Fields_flags;
 $Fcomment=&Filtr_mysql($F{comment});

 $d->{sql}="field_name='$Ffield_name',field_alias='$Ffield_alias',comment='$Fcomment',field_template='$Ffield_template',".
    "field_flags='$Ffield_flags',parent_type=$Fparent_type,field_type=$Ffield_type,template_num=$Ftemplate_num";

 $h=split /-/,$Dopfields_tmpl{$Ftemplate_num}[0] || $Dopfields_tmpl{$Ftemplate_num} || '�� ������';
 $_=&commas($Ffield_name);
 if( $Fid )
 {  # ���������, � �� �������� ������
    $new_data=$Ffield_name ne $field_name && "����� �������� $_";
    $new_data.=($new_data && ', ').($Ffield_alias ne ''? '�����: '.&commas($Ffield_alias) : '����� ������') if $Ffield_alias ne $field_alias;
    $new_data.=($new_data && ', ')."��� ���� ������: $Parent_types[$Fparent_type]" if $Fparent_type != $parent_type;
    $new_data.=($new_data && ', ')."������: $h" if $Ftemplate_num != $template_num;
    $new_data.=($new_data && ', ')."��� ����: $Field_types[$Ffield_type]" if $Ffield_type != $field_type;
    $new_data.=($new_data && ', ').'�������� ���.���������' if &Filtr_mysql($field_template) ne $Ffield_template;
    $new_data.=($new_data && ', ').'������� �����������' if &Filtr_mysql($comment) ne $Fcomment;
    $new_data.=($new_data && ', ')."�����: ".($Ffield_flags || '-') if $Ffield_flags ne $field_flags;
 }else
 {
    $new_data="�������� $_, �����: $Ffield_alias, ��� $Parent_types[$Fparent_type], ���: $Field_types[$Ffield_type], ���.���������: $h, �����: ".($Ffield_flags || '-');
 }
 $d->{new_data}=$new_data;
}

1;
