#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> '������ ��������',
	'tbl'		=> 'user_grp',
	'field_id'	=> 'grp_id',
	'priv_show'	=> $pr_main_tunes,
	'priv_edit'	=> $pr_edt_main_tunes,
	'allow_copy'	=> 1,
};

sub o_menu
{
 return &ahref($scrpt,'������ �����').
	($pr_edt_main_tunes && &ahref("$scrpt&op=new",'����� ������')).
	&ahref("$scrpt&act=usr_pack",'�����������');
}

sub o_list
{
 $out='';
 $order_by=('grp_name','grp_id','clients DESC')[int $F{sort}]||'grp_name';
 $sth=&sql($dbh,"SELECT g.*,COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp GROUP BY g.grp_id ORDER BY $order_by");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$clients,$grp_admins,$grp_name)=&Get_fields('grp_id','clients','grp_admins','grp_name');
    $out.=&RRow('*nav3','clccccc',
       $id,
       '&nbsp;&nbsp;'.&Filtr($grp_name),
       ($grp_admins=~s/,/,/g)-1,
       $clients,
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       $pr_edt_main_tunes && &ahref("$scrpt&op=copy&id=$id",'�����'),
       $pr_edt_main_tunes && !$clients && &ahref("$scrpt&op=del&id=$id",'�')
    );
   }

 !$out && &Error('� ���� ������ ��� �� ����� ������ ��������.'.$br2.&ahref("$scrpt&op=new",'�������'),$tend);

 $OUT.=&Table('tbg1 width100',
   &RRow('head','7',&bold_br('������ ��������')).
   &RRow('tablebg','cccc3',
     &ahref("$scrpt&sort=1",'Id ������'),
     &ahref($scrpt,'��������'),
     '������ ���������������<br>(����������)',
     &ahref("$scrpt&sort=2",'�������� � ������'),
     '��������').
   $out);
}

sub o_new
{
 $grp_name=$grp_property=$grp_admin_email=$grp_nets=$grp_blank_mess='';
 $grp_maxflow=$grp_maxregflow=0;
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT g.*,COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp WHERE g.grp_id=$Fid GROUP BY g.grp_id");
 !$p && &Error($d->{when_deleted} || "������ ��������� ������ ������������� ������ �������� � id=$Fid",$tend);
 $d->{no_delete}="� ������ �������� $p->{clients} ������� ������� ��������. ���������� �� � ������ ������." if $p->{clients}>0;
 $grp_property=$p->{grp_property};
 $grp_p{$_}=' checked' foreach (split //,$grp_property);
 $grp_admins=$p->{grp_admins};  
 $grp_adm{int $_}=' checked' foreach (split /,/,$grp_admins);
 $grp_admins2=$p->{grp_admins2};  
 $grp_admm{int $_}=' checked' foreach (split /,/,$grp_admins2);
 $grp_maxflow=int $p->{grp_maxflow};
 $grp_maxregflow=int $p->{grp_maxregflow};
 ($grp_name,$grp_admin_email,$grp_blank_mess,$grp_nets,$grp_adm_contacts,$grp_block_limit)=
   &Get_filtr_fields('grp_name','grp_admin_email','grp_blank_mess','grp_nets','grp_adm_contacts','grp_block_limit');
 $d->{old_data}='';
 $d->{name}='������ �������� '.&commas($grp_name);
}

sub o_show
{
 ($A,$Asort)=&Get_adms();
 $out_right='������ �������� ��� ���������������:'.$br;
 $out_right.='<div nowrap>'.
   "<input type=checkbox value=1 name=adm$_$grp_adm{$_}> ".
   "<input type=checkbox value=1 name=admm$_$grp_admm{$_}> ".
     $Offices{$A->{$_}{office}}.' - '.$A->{$_}{admin}.'</div>' foreach (@$Asort);

 $out_right.=$br2."<span class=disabled>�����������:</span> ���� ������� ���� ����������� ������������� ������� � ������ ".
   "(������ �������� ip, ������, ���, ������), ��� ������� - ������ ������ � ������. ���������� ������� - ������ �������� ������";

 $out_left=&Table('',
    &RRow('head','C',&bold_br($d->{name_action})).
    &RRow('*','ll','�������� ������',&input_t('grp_name',$grp_name,26,128)).
    &RRow('*','ll','��� �������� �� ����� ����� �� ����������� ������ �������� �������',"<input type=checkbox value=1 name=grp_p1 $grp_p{1}>").
    #&RRow('*','ll','�� ���������� ������ � ������� ������ �������� (��������, ��� ������ "���������")',"<input type=checkbox value=1 name=grp_p2 $grp_p{2}>").
    &RRow('*','ll','�������� ������ ������ �� ��������� �������������� ���������� ����� �� ��������� �����',"<input type=checkbox value=1 name=grp_p3 $grp_p{3}>").
    &RRow('*','ll','�������� ����������� ������� ��� ���� �������� ������ ������',"<input type=checkbox value=1 name=grp_p4 $grp_p{4}>").
    &RRow('*','ll','������������ ���������� ��������������� ������� ������� ������ ������� �� ���� ������ ����������. ��� ���������� ��� ����� ������, ������ ������� '.
       '����� ������������ (��� �����, ������). 0 - ���������� �����������. ������������� 20000',&input_t('grp_maxflow',$grp_maxflow,26,26)).
    &RRow('*','ll','������������ ���������� ��������������� ������� ������� ������ �������, ������� ����� ���� ���������������� � ���������������� ����������. ��� ������ '.
       '�� ������� �������� �� �� � ������ ��� ���� � �������). 0 - ���������� �����������. ������������� 10000',&input_t('grp_maxregflow',$grp_maxregflow,26,26)).
    &RRow('*','ll','Email-� �������, ������������� �� ������, ����������� 3 ������������� ����� �������',&input_t('grp_admin_email',$grp_admin_email,26,128)).
    &RRow('*','ll','����� ���������� ��� ����������� ������� ������� ��������',&input_t('grp_block_limit',$grp_block_limit,26,16)." $gr").
    &RRow('*','L','����������� ���������� ������� � ������� xx.xx.xx.xx/yy. ���� �� ���� ���� �� ����� �������, �� � ������ ������ ����� ��������� ����� ip.<br>'.
       "<textarea rows=6 name=grp_nets cols=38>$grp_nets</textarea>").
    &RRow('*','L','��� ��������� ����� ����������� � ��������������� ������ ��������. ����� ����������� � ���� �������, ��������� �� ���� �������. �� ������ �������� '.
       "����� � ���� �������: ����������� ������� ������ '|'.<br>\$l - �����<br>\$p - ������<br>\$i - ip �����</br>\$m - ����� �������<br>\$g - ����<br>\$d - ���<br><br> ��������:<br>".
       '<em>��������� �����������<br>������|$p<br>������ �����������|10.0.0.1<br>�� �������� ����������� �� �������� XXX-XXX</em>.<br>'.
       "<textarea rows=8 name=grp_blank_mess cols=38>$grp_blank_mess</textarea>").
    &RRow('*','L',"������� �������� ������������� �/��� ������������. ������ ����� ����� ������������ � ���������� ����������.<br><textarea rows=8 name=grp_adm_contacts cols=38>$grp_adm_contacts</textarea>")        
 );
 
 $out=&RRow('*','^^',$out_left,$out_right);
 $out.=&RRow('*','L',&div('message','��������� ���������� �� ������� �������� �������, ���� ������� ������� ��������� ��� ���������� ������ ��������. ')).
       &RRow('*','C',&submit_a('���������')) if $pr_edt_main_tunes;
 $OUT.=&form(%{$d->{form_header}},&Table('tbg3',$out));
}

sub o_save
{
 $Fgrp_maxflow=int $F{grp_maxflow};
 $Fgrp_maxregflow=int $F{grp_maxregflow};
 $Fgrp_admin_email=&Filtr_mysql($F{grp_admin_email});
 $Fgrp_blank_mess=&Filtr_mysql($F{grp_blank_mess});
 $Fgrp_nets='';
 foreach $net (split/\n/,$F{grp_nets})
   {
    $net=&trim($net);
    next unless $net;
    $Fgrp_nets.="$net\n";
    &ErrorMess('��������������: ���� '.&bold(&Filtr_out($net)).' ������ �������!') if $net!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ || $5>32;
   }
 $Fgrp_adm_contacts=&Filtr_mysql($F{grp_adm_contacts});
 $Fgrp_block_limit=$F{grp_block_limit}+0;
 $Fgrp_name=&trim(&Filtr($F{grp_name})) || "������ � $Fid";

 # � grp_admins ������ ����� ����������� 0 (� ������ � � �����) - ��� ��� ��������� ������� ��������
 $Fgrp_admins=$Fgrp_admins2='0';
 $sth=&sql($dbh,"SELECT id FROM admin ORDER BY id"); # order - ���� �������������� ������ grp_admins ����� ���� ���������� � ����������
 while ($p=$sth->fetchrow_hashref)
   {
    $h=$p->{id};
    $Fgrp_admins.=",$h" if $F{"adm$h"} || $F{"admm$h"};
    $Fgrp_admins2.=",$h" if $F{"adm$h"} && $F{"admm$h"};
   }
 $Fgrp_admins.=',0';
 $Fgrp_admins2.=',0';
 $Fgrp_property='';
 foreach (0..9,'a'..'z')
   {
    $Fgrp_property.="$_," if $F{"grp_p$_"};
   }
 $Fgrp_property.='0';

 $sql="grp_name='$Fgrp_name',grp_maxflow=$Fgrp_maxflow,grp_maxregflow='$Fgrp_maxregflow',grp_admin_email='$Fgrp_admin_email',".
    "grp_nets='$Fgrp_nets',grp_blank_mess='$Fgrp_blank_mess',grp_adm_contacts='$Fgrp_adm_contacts',grp_block_limit=$Fgrp_block_limit,".
    "grp_admins='$Fgrp_admins',grp_admins2='$Fgrp_admins2',grp_property='$Fgrp_property'";

 $d->{sql}=$sql;
 $_=&commas($Fgrp_name);
 if ($Fid)
   {# ���������, � �� �������� ������
    $new_data=$Fgrp_name ne $grp_name && "����� ��� ������: $_";
    $new_data.=($new_data && '. ').'������� ������ �������, ������� ������ � ������' if $Fgrp_admins ne $grp_admins || $Fgrp_admins2 ne $grp_admins2;
    $new_data.=($new_data && '. ').'������� ������ �����, ����������� � ������' if $Fgrp_nets ne $grp_nets;
   }else
   {
    $new_data="���: $_";
   }
 $d->{new_data}=$new_data;
}

1;
