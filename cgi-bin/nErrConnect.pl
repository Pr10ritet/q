#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nErrConnect');

# ����� ���� $UU �����������, �� ��� ��������� ����������� ��� ��������� �������

$out=&bold_br("$Title_net - NoDeny system").'������ (110) ����������� � �������� ���� ������.';
unless ($UU)
  {
   &ErrorMess($out.' ���� ��� ��������� ������������ ��� ������ - ���������� � �������� ��������������. '.
      '���� �� ������� ������������� - ������������ ��� ��������� ������� ����.');
   &Login;
  }

$out.=$br2.&div('borderblue',&Printf('[span disabled] [filtr][br][span disabled] [filtr][br][span disabled] [filtr][br][span disabled] [filtr]',
 '�����:',$user,'������:',$pw,'������:',$db_server,'����:',$db_name));
$out.=($DBI::errstr);

map{ $out.=$br2.&div('borderblue',&bold($_).$br.'<pre>'.`$_`.'</pre>') } ('ps ax | grep mysql','df -H');
&ErrorMess($out);

$Fa='tune'; # ������������� ��������� � ������ ��������
$scrpt="$scrpt0&a=tune";
$FormHash{a}='tune';

$file="$Nodeny_dir_web/tune.pl";
eval{require $file};
$@ && &Error("������ $file �� ������ ���� ��� ���� �� ��� �������� �����������."); # ����������� ������ ����

&Exit;

1;      
