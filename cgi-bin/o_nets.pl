#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> '�����������',
	'tbl'		=> 'nets',
	'field_id'	=> 'id',
	'priv_show'	=> $pr_main_tunes,
	'priv_edit'	=> $pr_edt_main_tunes,
};

sub o_menu
{
 my $out=join '',map{ &ahref("$scrpt&preset=$_"," ������ $_: ".$Presets{$_}) } (sort {$a <=> $b} keys %Presets);
 my $Fpreset=int $F{preset};
 return	&ahref("$scrpt&op=new&preset=$Fpreset",'����� �����������').
	&ahref("$scrpt&op=new&p=1&preset=$Fpreset",'����� ��������').$br. 
	&ahref("$scrpt&preset=-1",'��� �������').
	&ahref($scrpt,' ������: �������').
	$out.$br.
	&ahref("$scrpt0&a=operations&act=help&theme=nets_help",'�������');
}

sub o_list
{
 $colspan=7;
 $Fpreset=int $F{preset};
 $where=$Fpreset>=0 && "WHERE preset=$Fpreset";
 $title_row=&RRow('tablebg','ccccccc','���������','����','����','�����������','�����������','��������','�������');
 $old_preset=-1;
 $title_row_now='';
 $out='';
 $sth=&sql($dbh,"SELECT * FROM nets $where ORDER BY preset,priority,class");
 while ($p=$sth->fetchrow_hashref)
 {
    $preset=$p->{preset};
    $preset_name=$preset? $Presets{$preset} || '<span class=error>�����������</span>' : '�������';
    if( $old_preset!=$preset )
    {
       $out.=&RRow('head',$colspan,$br."������ �<b>$preset<b>:&nbsp;&nbsp;&nbsp;<b>$preset_name</b>".$br2);
       $title_row_now=$title_row;
       %traf_name=();
    }
    $old_preset=$preset;
    ($id,$class,$port,$priority)=&Get_fields('id','class','port','priority');
    $comment=&Filtr_out($p->{comment});
    $comment=~s|\n|<br>|g;
    if( $pr_edt_main_tunes )
    {
       $button_edit=&CenterA("$scrpt&op=edit&id=$id",'���');
       $button_del=&CenterA("$scrpt&op=del&id=$id",'�');
    }else
    {
       $button_edit=$button_del='';
    } 
    if( $priority )
    {
       $name_traf=$class? $traf_name{$class}||$class : '<span class=disabled>�������������</span>';
       $out.=$title_row_now.&RRow('*','cllllll',$priority,&Filtr_out($p->{net}),$port,$name_traf,$comment,$button_edit,$button_del);
       $title_row_now='';
    }
     else 
    {
       $traf_name{$class}=$comment;
       $out.=&RRow('*','cr3ll',"����������� <b>$class</b>","<span class=data1>$comment</span> ������",($port? '������� ipfw: '.&bold($port):''),$button_edit,$button_del);
    } 
 }

 $out or &Error($Fpreset>=0? "� ���� ������ ��� �� ����� ������ � $Fpreset-� ������� �����������." : '� ���� ������ ��� �� ����� ������ � ������������',$tend);

 $OUT.=&Table('tbg1 width100 nav',$out);
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM nets WHERE id=$Fid LIMIT 1");
 $p or &Error($d->{when_deleted} || "������ ��������� ������ ����������� id=$Fid.",$tend);
 $preset=$p->{preset};
 $priority=$p->{priority};
 $net=&Filtr($p->{net});
 $port=$p->{port};
 $class=$p->{class};
 $comment=&Filtr($p->{comment});
 $d->{old_data}=$priority? "������: $preset, ���������: $priority, ����: $net, ����: $port, �����: $class" :
    "������: $preset, �����: $class, ������� ipfw: $port, �������� �����������: ".&commas($comment);
}

sub o_new
{
 $preset=int $F{preset};
 $preset=0 if $preset<0;
 $class=0;
 $net=$port=$comment='';
 $priority=$F{p}? 0:100;
 $d->{name_action}=$priority? '�������� �����������' : '�������� �������� �����������';
}

sub o_show
{
 $AdminTrust or &Error($Mess_UntrustAdmin,$tend);
 $show_presets='<select name=preset size=1>';
 $show_presets.='<option value=0>������� ������</option>';
 $show_presets.="<option value=$_>$Presets{$_}</option>" foreach (sort {$a <=> $b} keys %Presets);
 $show_presets.="<option value=$preset selected>� $preset</option>" unless $show_presets=~s/<option value=$preset>/<option value=$preset selected>/;
 $show_presets.='</select>';

 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','����� �������',$show_presets).
     &RRow('*','ll','����� �����������',&input_t('class',$class,5,30)).
     ($priority?
       &RRow('*','ll','���������',&input_t('priority',$priority,5,30)).
       &RRow('*','ll','����',&input_t('net',$net,40,255)).
       &RRow('*','ll','����',&input_t('port',$port,5,10)).
       &RRow('*','ll','�����������',&input_t('comment',$comment,40,255)) :

       &RRow('*','ll','�������� �����������',&input_t('comment',$comment,40,128).' ������').
       &RRow('*','ll','����� ������� ��������',&input_t('port',$port,4,30)).
       &RRow('*',' l','','�����������: � ��������� ������� ipfw �� ��������� ����� �������� ��� ���� ������� ����������� � �������. '.
            '� ipfw ������ ����� 128. � 0 �� 29 ��������������� NoDeny. �� ������ ������������ 30..126 � ������ ������ ��������!<br>0 - ��������� ������ � �������')
     ).
     ($pr_edt_main_tunes && &RRow('head','C',&submit_a('���������')))
   )
 );
}

sub o_save
{
 $AdminTrust or &Error($Mess_UntrustAdmin,$tend);
 $Fnet=$F{net};
 $Fnet=~s|\s+||g;
 $Fpriority=int $F{priority};
 $Fpriority && $Fnet!~/^(file:.+|\d+\.\d+\.\d+\.\d+(\/\d+)?)$/ && &Error('�������� ����������� �� ��������� �.� '.
   '���� ������ �������! ���� ������ ���� ������ � ���� <b>xx.xx.xx.xx/yy</b>, <b>xx.xx.xx.xx</b> ���� <b>file:��� �����</b>',$go_back.$tend);

 $Fcomment=&Filtr($F{comment});
 $Fpreset=int $F{preset};
 $Fclass=int $F{class};
 $Fport=int $F{port};
 $d->{sql}="preset=$Fpreset,priority=$Fpriority,net='$Fnet',port=$Fport,class=$Fclass,comment='$Fcomment'";
 $d->{new_data}=$Fpriority? "������: $Fpreset, ���������: $Fpriority, ����: $Fnet, ����: $Fport, �����: $Fclass" :
    "������: $Fpreset, �����: $Fclass, ������� ipfw: $Fport, �������� �����������: ".&commas($Fcomment);

 $scrpt.="&preset=$Fpreset"; # ��� ������ `����������`
}

1;
