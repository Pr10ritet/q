#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nSql');

package nSql;
use strict;
use Time::HiRes qw( gettimeofday tv_interval );

# =============================================
# ������ 1:
#  $nsql=nSql->new({
#       dbh	=> $dbh,
#       sql	=> "SELECT * FROM users",
#  });
#  while( %h=%{ $nsql->get_line } ) { $OUT.="$h{id} = $h{name}".$br }
#
# ������ 2:
#  $nsql=nSql->new({
#       dbh	=> $dbh,
#       sql	=> "SELECT * FROM users",
#	show	=> 'line',
#	comment	=> '��� �������'
#  });
# %fields=( name => \$name, fio => \$fio );
# while( $nsql->get_line(\%fields) ) { $OUT.="$name = $fio".$br }
#
# ������ 3:
# $nsql=nSql->new({
#     dbh	=> $dbh,
#     sql	=> "SELECT name FROM users WHERE id=5",
#     ret	=> { name => \$name, fio => \$fio }
# });
# $OUT.='�����: '.( $nsql->{ok}? $name : '������!' );
#
# ������ 4:
# if( nSql->new({ dbh=>$dbh, sql=>"SELECT name FROM users WHERE id=1", hash=>\%h }) )
# {
#      $OUT.="�����: $h{name}";
# }
#
# show		����� ����������� � Debug-�������
#	full	- ������������ �����������. � �����
#       short	- �����������. � �����
#	line	- ��� � ���� ������. ��� �����
#	mem	- ����, �� �������� � ���������� $Debug

sub new
{
 my($self,$dbh,$comment,$data,$ok,$p,$rows,$show,$sth,$sql,$t_sql,$line_exists);
 my $self={};
 shift;

 $data=shift;
 $dbh=$data->{dbh};
 $self->{dbh}=$dbh;
 $sql=$data->{sql};
 $comment=$data->{comment};
 $show=$data->{show};

 $t_sql=[gettimeofday];
 $sth=$dbh->prepare($sql);
 $ok=$sth->execute;
 $t_sql=tv_interval($t_sql);
 $main::T_sql+=$t_sql;
 $self->{rows}=$rows=$sth->rows;
 $self->{sth}=$sth;
 $self->{ok}=$ok;
 if( defined($data->{ret}) || defined($data->{hash}))
 {
    $line_exists=$ok && ($p=$sth->fetchrow_hashref);

    if( substr(ref $data->{ret},0,4) eq 'HASH' )
    {
       map{ ${$data->{ret}{$_} }=$line_exists? $p->{$_} : '' } keys %{ $data->{ret} };
    }
     elsif( defined $data->{ret} )
    {
      $comment='<b>������: �������� ret ������ ���� ������� �� ���!</b> '.$comment;
    }

    if( substr(ref $data->{hash},0,4) eq 'HASH' )
    {
       %{$data->{hash}} = defined $p? %{$p} : ();
    }
     elsif( defined $data->{hash} )
    {
       $comment='<b>������: �������� hash ������ ���� ������� �� ���!</b> '.$comment;
    }
 }

 bless $self;
 $main::Ashowsql or return $self;

 my $time=($t_sql>0.00009? sprintf("%.4f",$t_sql) : '0').' ���';

 $ok=!$ok && '. <b>������ �� ��������</b>: '.$DBI::errstr;
 if( $show eq 'line' || $show eq 'mem' )                                                  
 {
    $comment="<small>$comment: </small>" if $comment;
    $comment.="<small>$sql <span class=disabled>($rows �����, $time)</span></small>$ok<br>";
 }else
 {
    $p=$show eq 'short'? ' ' : '<br>';
    $comment="<span class=data2>$comment</span>$p" if $comment;
    $comment=&main::MessX($comment.$sql.$p."<span class=disabled>�����:</span> $rows. <span class=disabled>����� ���������� sql:</span> $time$ok",0,0);
 }

 if( $show eq 'mem' )
 {
     $main::Debug.=$comment;
 }else
 {
     $main::DOC->{admin_area}.=$comment;
 }
 return $self;
}

sub get_line
{
 my($self,$ref)=@_;
 my $p=$self->{sth}->fetchrow_hashref;
 if( $p && defined($ref) )
 {
    if( substr(ref $ref,0,4) eq 'HASH')
    {
       map{ ref $ref->{$_} eq 'SCALAR'? ${$ref->{$_}}=$p->{$_} : $self->__error_to_adm(1,"������: �������� ����� $_ �� �������� ������� �� ������") } keys %$ref;
    }
     else
    {
       $self->__error_to_adm(1,'������: �������� �� �������� ������� �� ���');
    }
 }
 $self->{row}=$p;
 return $p;
}

sub __error_to_adm
{
   $main::Ashowsql or return;
   my($self,$level,$error)=@_;					# level - ���������� ������ ��������� ������������ �� $level ������� �����
   my(undef,$filename,$line,$subroutine)=caller($level);	# � ����� ������������ �����
   $filename=~s/^.*\///;
   $filename="$filename:$line|";
   $filename.="->$subroutine()" if $level;
   $error=&main::Filtr_out("[$filename] $error");
   $main::DOC->{admin_area}.="<span class=error>*</span> $error<br>";
}

1;
