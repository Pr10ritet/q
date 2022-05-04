#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> '������ ���������',
	'tbl'		=> 'j_workers',
	'field_id'	=> 'worker',
	'priv_show'	=> $pr_workers,
	'priv_edit'	=> $pr_workers_edit,
};

sub o_menu
{
 &LoadJobMod;
 $W=&Get_workers();		# ������ ����������
 &nJob_present_workers($W);	# ������� ���, ��� ����� �� ������
 $out=&ahref($scrpt,'��� ���������');
 $out.=&ahref("$scrpt&op=new",'����� ��������') if $pr_workers_edit;
 $out.=&ahref("$scrpt0&a=job&act=showjob&mod=-1",'������� �������');
 $out.=&ahref("$scrpt0&a=job&act=setjob",'������ �������') if $pr_workers_work;
 $out.=&ahref("$scrpt0&a=job&act=grafik",'������');

 $out.=$br.&div('tablebg',&form('act'=>$Fact,&input_t('text',$F{text},20,80).' '.&submit('�����'))).$br;
 if ($pr_oo)
   {# ���� ����� �� ������ � ������ ��������
    $Foffice=int $F{office};
    $out.=&div('tablebg',&form('act'=>$Fact,&Get_Office_List($Foffice||$Admin_office).' '.&submit('�����'))).$br;
   }

 return $out;
}

sub o_list
{
 $out='';
 $url=$scrpt;
 $Foffice=int $F{office};
 $txt=$F{text};
 $txt2=$txt;
 $txt2=~tr/qwertyuiop[]asdfghjkl;'zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>/����������������������������������������������������������������/;
 $txt=&Filtr_mysql($txt);
 $txt2=&Filtr_mysql($txt2);
 $sql="SELECT * FROM j_workers WHERE 1";
 if ($txt) 
   {
    $url.='&text='.&URLEncode($F{text});
    $sql.=" AND (name_worker LIKE '%$txt%' OR contacts LIKE '%$txt%' OR name_worker LIKE '%$txt2%' OR contacts LIKE '%$txt2%')";
   }
 # ��� ����� �� ������ � ������ ��������?
 $sql.=!$pr_oo? " AND office=$Admin_office" : defined $F{office}? " AND office=$Foffice" : '';
 $sql.=" ORDER BY office,state,name_worker";
 $url.="&office=$Foffice" if $pr_oo && defined $F{office}; 
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,50,$url);
 while ($p=$sth->fetchrow_hashref)
   {
    ($state,$id,$office,$name_worker)=&Get_fields('state','worker','office','name_worker');
    ($post)=&Get_filtr_fields('post');
    $uvolen=($state==3);
    $worker_come= !$pr_worker_come? '' :
                $W->{$id}{present}? &ahref("$scrpt0&a=job&act=come&direction=1&id=$id",'���������') :
                                    &ahref("$scrpt0&a=job&act=come&id=$id",'������');
    $has_job=$W->{$id}{has_jobs} && &ahref("$scrpt0&a=job&act=showjob&id=-$id",'�� �������').
      ($W->{$id}{has_jobs}>1 && $br.'<span class=error>������ ������ �������</span>');

    $out.=&RRow($uvolen? 'rowoff':'*','cclcclccc',
       $W->{$id}{present} && &div('rowsv pddng2','������������'),
       $worker_come,
       $name_worker,
       $has_job,
       $post,
       $uvolen? '<span class=disabled>������</span>' :
         $state==2? '<span class=data2>� �������</span>' :
         $state==1? '<span class=data1>�����������</span>' : '',
       $Offices{$office},
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       ($pr_workers_edit && &ahref("$scrpt&op=del&id=$id",'X'))
    );
   }

 &Error('� ���� ������ ��� �� ������ ���������.'.$br2.&ahref("$scrpt&op=new",'������'),$tend) if !$out && !$txt && !(defined $F{office});
 $out or &Error('�� ��������� ������� ��������� �� �������.',$tend);

 $page_buttons&&=&RRow('head','9',$page_buttons);

 $OUT.=&Table('tbg3 width100',
     $page_buttons.
     &RRow('tablebg','ccccccccL','���������','��������'.$br.'����','���','�������','���������','������','�����','').
     $out.
     $page_buttons);
}

sub o_new
{
 $contacts=$name_worker=$post='';
 $state=0;
 $menu='&nbsp;';
 $office=$Admin_office; # �� ��������� �����, � ������� �������� ��������, ����� ����� ������ ������
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$Fid LIMIT 1");
 $p or &Error($d->{when_deleted} || "������ ��������� ������ ��������� � id=$Fid",$tend);

 !$pr_oo && $p->{office}!=$Admin_office && &Error("�������� � ������� $id �������� � ������ �������� �� ������. ������ ��������.$go_back",$tend);

 ($name_worker,$contacts,$post)=&Get_filtr_fields('name_worker','contacts','post');
 ($state,$office)=&Get_fields('state','office');
 $menu='';
 $menu.=$W->{$Fid}{present}? &ahref("$scrpt0&a=job&act=come&direction=1&id=$Fid",'��������� ����') :
     &ahref("$scrpt0&a=job&act=come&id=$Fid",'������ ����');
 $menu.=&ahref("$scrpt0&a=payshow&mid=-$Fid",'������� �������').
        &ahref("$scrpt0&a=payshow&nodeny=sworker&mid=-$Fid",'������� �������') if $pr_worker_pays_show;
 $menu.=&ahref("$scrpt0&a=pays&mid=-$Fid",'������ ��������') if $pr_worker_pays_create;
 $menu.=&ahref("$scrpt0&a=job&act=history&id=$Fid",'������� �����/���������');
 
 if ($PR{103})
 {  # ������������
    $h=&sql_select_line($dbh,"SELECT COUNT(parent_id) AS n FROM dopdata WHERE ".
      "WHERE parent_type=1 AND field_type=7 AND field_value='2:$Fid' GROUP BY parent_id",
      '������������, ������� �������� �� ���������');
    $menu.=&ahref("$scrpt0&a=equip&act=find&owner_type=2&owner_id=$Fid",$h->{n}.' ������ ������������').$br if $h && $h->{n};
 }

 $W->{$Fid}{present} && ($d->{no_delete}='�� �������� �������� �� ������.');
 &sql_select_line($dbh,"SELECT * FROM pays WHERE mid=-$Fid AND type=10 LIMIT 1") &&
    ($d->{no_delete}='��� ���������� ��������. ���������� '.&ahref("$scrpt&op=edit&id=$Fid",'���������').' � ��������� `������`.');

 if ($W->{$Fid}{has_jobs})
   {
    $url="$scrpt0&a=job&act=showjob&id=-$Fid";
    $menu.=$br."� ������ ������ ��������� ������ ($W->{$Fid}{has_jobs})".&ahref($url,'��������');
    $d->{no_delete}='�� � ������ ������ '.&ahref($url,'��������� ������');
   }

 $d->{name}='������ ��������� � ������ '.&commas($name_worker);
 $d->{old_data}="�����: ".(defined $Offices{$office}? &commas($Offices{$office}) : '�� ������').
   ', ���������: '.('��������','�����������','� �������','������')[$state].
   ($post && ', ���������: '.&commas($post));
}

sub o_show
{
 $liststate="<select size=1 name=state><option value=0>��������</option><option value=1>�����������</option><option value=2>� �������</option><option value=3>������</option></select>";
 $liststate=~s/<option value=$state>/<option value=$state selected>/;
 if ($pr_oo)
   {# ���� ����� �� ������ � ������ ��������
    $offices=&Get_Office_List($office);
   }else
   {# � ����� ������ � ������� ���� �������� ����� ������ �.� � ������ ������ ����� �� ��������� ������ ����� ���� ����
    $offices=&input_h('office',$office).($Offices{$office} || '��� ������');
   }

 $out=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','�����',$offices).
     &RRow('*','ll','���',&input_t('name_worker',$name_worker,40,200)).
     &RRow('*','ll','���������',&input_t('post',$post,40,200)).
     &RRow('*','ll','���������� ����������',"<textarea rows=8 cols=40 name=contacts>$contacts</textarea>").
     &RRow('*','ll','���������',$liststate).
     &RRow('head','C',$pr_workers_edit? &submit_a('���������') : $go_back.$br2)
   )
 );

 $OUT.=&div('message cntr',$br.&Table('',&RRow('nav2','tt',$out,$menu)));
}

sub o_save
{
 $Fstate=int $F{state};
 $Fstate=0 if $Fstate<0 || $Fstate>3;
 $Foffice=$pr_oo? int $F{office} : $Admin_office;

 $Fcontacts=&Filtr_mysql($F{contacts});
 $Fpost=&Filtr($F{post});

 $Fname_worker=&trim($F{name_worker});
 $Fnew_name_worker=&Filtr($Fname_worker);

 $OUT.=&div('message','�� ����� ��������� ������� ������������ �������.') if $Fnew_name_worker ne $Fname_worker;
 if (length($Fnew_name_worker)<3)
   {
    $Fnew_name_worker="�������� $Fnew_name_worker";
    $OUT.=&div('message','��� ��������� ������ ���� �� ����� ���� ��������. ��������.');
   }

 $d->{sql}="contacts='$Fcontacts',name_worker='$Fnew_name_worker',post='$Fpost',state=$Fstate,office=$Foffice";

 $name_office=(defined $Offices{$Foffice}? &commas($Offices{$Foffice}) : '�� ������');
 $name_state=('��������','�����������','� �������','������')[$Fstate];
 $_=&commas($Fnew_name_worker);
 if ($Fid)
   {# ���������, � �� �������� ���������
    $new_data=$Fnew_name_worker ne $name_worker && "����� ��� ���������: $_";
    $new_data.=($new_data && '. ')."�����: $name_office" if $Foffice!=$office;
    $new_data.=($new_data && '. ')."���������: $name_state" if $Fstate!=$state;
    $new_data.=($new_data && '. ').'���������: '.&commas($Fpost) if $Fpost!=$post;
   }else
   {
    $new_data="���: $_, �����: $name_office, ���������: $name_state, ���������: ".&commas($Fpost);
   }
 $d->{new_data}=$new_data;
}

1;
