#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nEquip.pl');

sub nEq_owner
{
  my $owner_type=int $_[0];
  my $owner_id=int $_[1];

  {
    !$owner_type or last;
    $owner_id or return '����� ������';
    my $U=&Get_users($owner_id);
    $U->{$owner_id}{name} or return '';
    return '������ '.&ShowClient($owner_id,$U->{$owner_id}{name});
  }
  
  {
    $owner_type==1 or last;
    $owner_id or return '����� �������������';
    ($eq_A,$eq_Asort)=&Get_adms() unless defined $eq_A;
    $eq_A->{$owner_id}{admin} or return '';
    return "����� $eq_A->{$owner_id}{admin}".($owner_id==$Admin_id && &bold(' (��)'));
  }
  
  {
    $owner_type==2 or last;
    $owner_id or return '����� ��������';
    $eq_W=&Get_workers() unless defined $eq_W;
    defined $eq_W->{$owner_id}{name} or return '';
    my $worker=$eq_W->{$owner_id}{name};
    return $pr_workers? &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$owner_id",$worker) : $worker;
  }
  
  {
    $owner_type==3 or last;
    $owner_id or return '����� ���� � ���������';
    return &ahref("$scrpt0&a=oper&act=contacts&op=edit&id=$owner_id",'������ ���� � ���������');
  }
  
  {
    $owner_type==4 or last;
    $owner_id or return '����� ����� ���������';
    return &ahref("$scrpt0&a=oper&act=points&op=edit&id=$owner_id","����� ��������� � $owner_id");
  }
    
  return '����������� �������� (�������� ��� ���� ���������)';
}
1;
