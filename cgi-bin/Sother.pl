#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub SO_contacts
{
 $h=&sql_select_line($dbh,"SELECT grp_adm_contacts FROM user_grp WHERE grp_id=$grp");
 $h or return;
 $grp_adm_contacts=&trim($h->{grp_adm_contacts});
 $grp_adm_contacts or return;
 $OUT.=&div('message','��������:'.$br2.&div('lft',&Show_all($grp_adm_contacts)),1);
}

# ===================================================
# ��������� �������� `� ������ ���������� ����������`
sub SO_MessRead
{
 $idz=int $F{idz};
 # ������ �� id ������ - ������ �� ��������!!
 $rows=&sql_do($dbh,"UPDATE pays SET category=493 WHERE id=$idz AND mid=$Mid AND type=30 AND category=490 LIMIT 1");
 &OkMess("���������� �� ��, ��� ������������ � ���������� �������������.".$br2.&ahref("$scrpt&a=101",'������� �������� ����������'));
}

# ===================================================
# Help �� ������������� ���������� ����
sub SO_PPC_Help
{
 &OkMess(&bold('������������ ��������� ���').' ������������� ��� ���������� ����� ����� ������� ��������� �������, ��������, ��������� ���������, ������� '.
   '��������� ���������� � ��������� �� �� ��� ���� � ����� �������. ������������ ��������� ��� �� �������� ���������, �� ������������ ��� ��������� '.
   '���������� �������� - ����� ��� �� ����� ���� ��������� �� ����� �������� �� ������ ���������� ����������. �������� ��������� ������, � ������� '.
   '�� ������ ������������ ������� � �������������� ���������� ����, ����� ������� �� ������� �����.');
}

sub SO_OptPay_Help
{
 &OkMess('��������� ������� (�����) ��������� �������� ��������� �������������� ��������� ����� �� ������������ ������ �������. ���� � ����� ������ ������������ '.
  '����������� ��������, �� ��������� ����� ������������ ����� ���������� �������� � ������������ ��������. ���� �� � ����� ������ ����������� �� �������, '.
  '�� ��������� ����� ������������ ����� ������ � ������������ �������� ����������.'.$br2.
  '�������� ��������, ��� ��������� ������� ����� ���� ��������.'.$go_back);
}

1;      
