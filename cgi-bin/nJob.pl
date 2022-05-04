#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nJob.pl');

# ������� ���������� - ������ � ������� �������� � ���������� 460 (�����������) ��� 461 (���������).
# ���� coment - ����������� � �������
# ���� reason - �������������� �������: 
#   ���_�������[,id_���������_1,id_���������_2...]
# ���� ����� id ��������� ����� ����� - �������� ������������� �� �������, ����� ���� ��������� �������������
# ���� ������� ���������, �� � ����� ����������� ������ #, ����� ���� ���� �������������� ���������:
#   ����� ���������� ������,����� ��������� �������,������� ���������� ������[,id_���������_1,id_���������_2...]
# id ��������� ������������ ������ ���� ��� ���� ���������
#
# ������: 2,3,-4,5
# �����������: ������� � ����� 2; �������� ��������� 3,4,5; ������������� �������� 4
#
# ���� �� ������ �� ���� �������� - ������� ��������� �������������� �� ������� (����� �������)


# ������������ �������� ������������� �������
# ����: 
# 0 - id
#  undef: ��� ������
#      0: ������ ������� �� ����
#     >0: ������ ��������� � �������� id
#     <0: ������ ��������� � ���������� id
# 1 - ����� 
#  undef: ���
#     -1: �������������
#     -2: ��������������
#    >=0: �������������� ������� ���� �����, �� ������� ��������� ������ �����
sub nJob_ShowJobBlank
{
 my($id,$mod)=@_;
 my($blank,$coment,$form,$h,$job,$out,$p,$pay_id,$sth,$tbl,$tt,$w,$where,$wid);
 my @workers;

 $h=int $id;
 $nJob_W=&Get_workers() unless defined $nJob_W;
 ($nJob_A)=&Get_adms() unless defined $nJob_A;

 $out='';

 if( $h<0 )
 {  # ��� ������� ���������, $mod ���������� �.� �������������� ������� �� ������� � �����������
    $wid='\-?'.(-$h);
    $where="AND (reason REGEXP ',$wid\$' || reason REGEXP ',$wid,')";
 }else
 {
    $job=int $mod;
    $where=defined($id)? "AND mid=$h " : '';
    $where.="AND reason LIKE '%,%'" if $mod==-1;
    $where.="AND reason NOT LIKE '%,%'" if $mod==-2;
    $where.="AND reason='$job'" if defined($mod) && $mod>=0;
 }

 $sth=&sql($dbh,"SELECT * FROM pays WHERE type=50 AND category=460 $where ORDER BY time",'nJob.pl');
 while( $p=$sth->fetchrow_hashref )
 {
    $out.=$br2 if $out;
    ($pay_id,$wid,$coment,$tt)=map {$p->{$_}} qw( id mid coment time );
    $wid=-$wid;
    ($job,@workers)=split /,/,$p->{reason};	# ���_�����, ������ ���������� ����������� ������
    $blank=$#workers<0;				# ����� ������� ��� ������������� �������?
    $tbl=$blank? &RRow('head','C','�������������� �������') : &RRow('rowsv','C','� ������ ������ ������� ������');
    $tbl.="<tr class=row1><td width=20% class=disabled>��� �����</td><td>".($jobs[$job]||'�� ������').'</td></tr>';
    $tbl.=&RRow('row1','ll','<span class=disabled>�����������</span>',&Show_all($coment)) if $coment;
    if( $tt>$t )
    {  # ������� �� �������
       $h=&the_short_time($tt,$t);
       # ���� �� ������ ������� ����� 30 ����� - ����� ������� ������� ������
       $h=($tt-$t)<1800? "<span class='modified title'>$h</span>" : $h;		
       $tbl.=&RRow('row1','ll','<span class=disabled>������������� ��������� �</span>',$h);
    }else
    {
       $tbl.=&RRow('row1','ll','<span class=disabled>����� ���������� �������</span>',&the_time($tt));
    }
    $tbl.=&RRow('row1','ll','<span class=disabled>'.($blank? '� �������':'�����������').'</span>',&the_hh_mm(($t-$tt)/60));
    $tbl.=&RRow('row1','ll','<span class=disabled>�����, �������� �������</span>',$nJob_A->{$wid}{admin}) if defined $nJob_A->{$wid}{admin};
    $h='';
    foreach $w (@workers)
    {
       $wid=abs int $w;				# id ����� ���� � �������, ��� �������� `�������������`
       next unless defined $nJob_W->{$wid}{name};
       $h=!$PR{26} && $nJob_W->{$wid}{office}!=$Admin_office? '<span class=error>�������� ������������ ��� ������</span>':
            $PR{23}? &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$nJob_W->{$wid}{name}) : $nJob_W->{$wid}{name};
       $h.=' <span class=disabled>(�������������)</span>' if $w<0;
       $tbl.=&RRow('row1',' l','',$h);
    }
    if( $PR{25} )
    {
       $form=&form('!'=>1,'#'=>1,'a'=>'job','idjob'=>$pay_id,($blank? 
         &input_h('act'=>'setjob','job'=>int $job,'tjob'=>$coment,'id'=>$id).&submit_a('������/������� �������').$spc : 
         &input_h('act'=>'endjob').&submit_a('��������� �������')).$spc
       );
       $tbl.=&RRow('row1','C',$form);
    }
    $out.=&Table('table1 width100 '.($blank? 'borderblue':'modified'),$tbl);
 }
 return $out;
}

# ����: ������ �� ���-������ ����������
# ��������������� ����� �����:
# $W->{id}{present}		>0, ���� �������� ������������ (� ������� ��������� 48 �����)
# $W->{id}{come_time}		����� ������ �� ������
# $W->{id}{has_jobs}		���������� �����, ������� ����������� ���������� � ������ ������

sub nJob_present_workers
{
 my ($W)=@_;
 my ($p,$sth,$wid);
 my @workers;
 $sth=&sql($dbh,"SELECT mid,category,time FROM pays WHERE type=50 AND category IN (465,466) AND time>(unix_timestamp()-172800) ORDER BY time DESC",
     'nJob.pl: ������/����� � ������');
 while( $p=$sth->fetchrow_hashref )
 {
    $wid=$p->{mid}*-1;
    next if $wid<=0;
    next if defined $W->{$wid}{present};
    $W->{$wid}{present}=$p->{category}==465? 1:0;
    $W->{$wid}{come_time}=$p->{time};
 }
 $sth=&sql($dbh,"SELECT reason FROM pays WHERE type=50 AND category=460 ORDER BY time",'nJob.pl: ������ ������������� �����');
 while( $p=$sth->fetchrow_hashref )
 {
    (undef,@workers)=split /,/,$p->{reason};
    $W->{abs(int $_)}{has_jobs}++ foreach (@workers);
 }
}

1;
