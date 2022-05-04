#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

my %h;
$Str_field=nSql->new({
   dbh		=> $dbh,
   sql		=> "SELECT field_name FROM dopfields WHERE field_alias='p_street:street:name_street'",
   show		=> 'full',
   hash		=> \%h,
   comment	=> '�������� ���� `�����`'
})? &Del_Sort_Prefix($h{field_name}) : '�����';

$d={
	'name'		=> "������ ������� $Str_field",
	'tbl'		=> 'p_street',
	'field_id'	=> 'street',
	'priv_show'	=> 1,
	'priv_edit'	=> $pr_edt_streets,
};

sub o_menu
{
 return	&bold_br("������ ���� $Str_field").
   &ahref($scrpt,"������").
   ($pr_edt_streets && &ahref("$scrpt&op=new",'����� ������'));
}

sub o_list
{
 $out='';
 $sth=&sql($dbh,"SELECT street,name_street,region FROM p_street ORDER BY region,name_street");
 while( $p=$sth->fetchrow_hashref )
 {
    ($id,$region,$name_street)=&Get_filtr_fields('street','region','name_street');
    $region=(split /-/,$Regions{$region})[0] || $Regions{$region};
    $out.=&RRow('*','llcc',$name_street,$region,&ahref("$scrpt&op=edit&id=$id'",$d->{button}),
      !!$pr_edt_streets && &ahref("$scrpt&op=del&id=$id'",'X'));
 }

 $out or &Error("� ���� ������ ��� �� ����� ������ `$Str_field`.".$br2.&ahref("$scrpt&op=new",'�������'),$tend);

 $OUT.=&Table('tbg1 nav3 width100',
   &RRow('tablebg','ccC','��������','�����','��������').$out);
}

sub o_show
{
 foreach (sort {$Regions{$a} cmp $Regions{$b}} keys %Regions)
 {
   $regions.="<option value=$_".($_==$region && ' selected').'>'.
     ((split /-/,$Regions{$_})[0] || $Regions{$_}).'</option>';
 }

 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg1i',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','��������',&input_t('name_street',$name_street,50,127)).
     &RRow('*','ll','�����',"<select name=region><option value=0>-</option>$regions</select>").
     (!!$pr_edt_streets && &RRow('head','C',&submit_a('���������')))
   )
 );
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM p_street WHERE street=$Fid LIMIT 1");
 $p or &Error($d->{when_deleted} || "������ ��������� ������ ����� ����� $Fid",$tend);
 ($name_street,$region)=&Get_filtr_fields('name_street','region');
 #$d->{no_delete}='���������� ���������� ������� ������, � ������� ������� ������� �����.' if &sql_select_line($dbh,"SELECT * FROM users WHERE street=$Fid LIMIT 1");
 $d->{name}='����� '.&commas($name_street);
}

sub o_new
{
 $name_street='';
 $region=0;
}

sub o_save
{
 $Fname_street=&trim(&Filtr($F{name_street}));
 ($Fname_street eq '') && &Error("�� �� ������� ��������.$go_back",$tend);
 $Fregion=int $F{region};
 $Fregion=0 unless defined $Regions{$Fregion};
 $d->{sql}="name_street='".&Filtr_mysql($Fname_street)."',region=$Fregion";
 $_=&commas($Fname_street);
 if( $Fid )
 {
    $new_data=($Fname_street ne $name_street) && "$Str_field. ����� �������� $_";
    $new_data.=($new_data && ', ')."����� ������: $Fregion" if $Fregion!=$region;
 }else
 {
    $new_data="�������� $_, ����� ������: $Fregion";
 }
 $d->{new_data}=$new_data;
}

1;
