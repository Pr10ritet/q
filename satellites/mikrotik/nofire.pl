#!/usr/bin/perl
# ==============================================================================
#
#		NoDeny - ������������ ���������� ��������� NAS
#
# ==============================================================================
#
# ���� ���������� ��������� ip �� ��������� NAS �������� � ����, ��� ����������
# ����������� ��������� ���� ������� ip �� ������������ ������� NAS. ������
# ��� ������ ���������� access-list (cisco) ��� address-list (mikrotik).
# 
# ����������, ���������� ��������� ����� �������, � �������, � ��������� goodboys.
# ��� ip, ������� ��������� � ������ goodboys ����� ����� ������ � ��������, �
# ��������� ������, ��� ���� ip ����� �������������.
#
# NoDeny ����� ������������ ������� ���������� �������, ��� � ��������� �������
# ����� ���� ������ ����������. ��������, ����������� ��������, ����� ����������
# ��������� NAS, � ������� ���������� �������. ������ A �� NAS1 �������� �����
# ������� � �� NAS2. ��� ���� ������ � ��������� � ��������������� ���������.
# ��������� ip ������� A ��������� � ������ goodboys, �� ����� ����� ��������
# � ������ � ����������� ������� �. �� NAS2 �� ����� ������������, ������, �����
# NAS1 �� ��� ���� ������� � ����� �������� ������� A ��� ��������� ������
# (���� ��� �� ���� �������� - ��������� �� ��������������, ��� ����� �����
# ����������� ����� ������ �� NAS1). 
#
# (����� ��� ������ � ��� � ������ ����� ������������ ���� ��� �������� �����
# ������� -  � ���������, �� ���������. ������ ���������� ������������ ����������
# ���� ������ � ����� ���������� �������� �������� �������� �����������)
#
# ����, ���� ������� �������:
#  - �������� � ������ `xxxboys` ���, ��� ������ ���� � ���� ������;
#  - ������� ���, ��� �� ������.
#
# ����� � �������� ������� ������� ������ goodboys. ���������� 2 �������:
#  %NF_goodboys	- �������� ip ��� ��������, ������� ������ ���� � ������ goodboys
#  %NF_goodboys_sync   - �������� ip ��� ��������, ������� ��� � ������ goodboys
#
# ���� ���������� �������� ip � ������, �� ������ �� �������� � %NF_goodboys, ����
# ���������� ������� - ��������� �� ����� ����. ��� �������� �������������� 
# &Allow, &Deny � �������.
#
# ����� ���� ����������� �� ����� � ���������������� ������� NAS �������� ��� �������
# ip �� ������. ���� � ���, ��� ������ ���������� ������� ������� �� NAS ��������� ������
# �����, ��� ���� ��� ����� ��������� ������� ������� ��� �� �����. � �������, ���� ��
# ����������� �������� ��������� �������� ����� ������ � ������� ������� ipfw, �� ���
# ����������� ������� ������� ��������� ����� ���� ��� ����� �������. ���� �� �������
# ������ ������ � ���� �����, �� ������ ���������� ����������� ���������.
#
# ������ �� ����� ������������ ����� �������� - ������ ������������� � �����������
# � �������� ������� - �������� ����������� �������������.
#
# ����� �������� ���������� � ������������ Run_Ipfw_Rules.
# ����� ����������������� ����������/�������� ip �� NAS, ���������� ����������� %NF_goodboys_sync.
# ������������� %NF_goodboys_sync - ��� ��������� ����, ����� ip ������� � ������ �� NAS.
# ������, ��������� ����� ��������� ����������������, ��������, � ���������� ������ ����� ����
# ������������ NAS ���� ���� �����, ����� ���������, ��� %NF_goodboys_sync ��� �� �����
# �������� �������������� ��������, �.�. ����� � ������ ������ ip, ���� � ��� ����� �������������
# ����������� ip.
#
# ������� ����� �� ������� ���������� ������������� ������� � �������� $NF_t_check.
# ���� NAS �� ����� ������������ ������ ip, �� ������������� �� ����� ������������, �.�.
# ����� ���������, ��� ������ ���������������� ������.
#
# �� ������� �������� $NF_t_check ������� ��������� ��� ��������� ������� �� ����. ��-������
# ��� ������ ������ �����, ��-������, �� ���������, ��� � ������ ���������� ������ �� ����
# ip - ��� ����� ������� � ��� ����� �� ��� ��������.

$NF_hw_module='hw_mikrotik.pl';

$NF_verbose=0;	# 1 - �������� �������� `�� �����`, 2 - ����� ��������

$NF_allboys_list='allboys';
$NF_goodboys_list='goodboys';

$NF_t_check=30;

$NF_title='[nofire]';

$NF_t_sync=0;

sub NF_Debug
{
 ($v or $NF_verbose) && print "$NF_title $_[0]\n";
}

#--- ���������� �� noserver ---

sub Flush
{
 %NF_goodboys=();
 %NF_goodboys_sync=();
 %NF_allboys=();
 %NF_allboys_sync=();
}

sub Allow
{
 my $p=$_[0];
 my $dop_param=$p->{dop_param};
 $NF_goodboys{$p->{ip}}={
   'speed_in'	=> 1000 * ($p->{speed_in} || 8 * $dop_param->{_speed_in}),
   'speed_out'	=> 1000 * ($p->{speed_out} || 8 * $dop_param->{_speed_out})
 };
}

sub Deny
{
 my $p=$_[0];
 delete $NF_goodboys{$p->{ip}};
}

sub Add_To_All_Ip
{
 $NF_allboys{$_[0]}=1;
}

sub Delete_From_All_Ip
{
 delete $NF_allboys{$_[0]};
}

sub Run_Ipfw_Rules
{
 if( &TimeNow()>$NF_t_sync )
 {
    &NF_Debug('Synchronization');
    my $old_t_sync=$NF_t_sync;
    my %ip_list=();
    my ($ip,$list,$p_list);
    $NF_t_sync=&TimeNow()+$NF_t_check;
    if( !&HW_get_ip_list({'list_ptr'=>\%ip_list}) )
    {
       &NF_Debug("Error getting ip lists");
    }
     else
    {
       %NF_allboys_sync=%NF_goodboys_sync=();
       foreach $ip (keys %ip_list)
       {
          $p_list=$ip_list{$ip}->{list};
          defined($p_list) or next;
          foreach $list (@$p_list)
          {
              &NF_Debug("$ip, list $list");
              if( $list eq $NF_goodboys_list )
              {
                 $NF_goodboys_sync{$ip}={
                     'speed_in'=>$ip_list{$ip}->{speed_in},
                     'speed_out'=>$ip_list{$ip}->{speed_out}
                 };
              }
              if( $list eq $NF_allboys_list )
              {
                 $NF_allboys_sync{$ip}=1;
              }
          }
       }
    }
    $old_t_sync or return; # ��� ������� ��� �� ����������� ���� ��������� ������ ��� ���������
 }

 my %list;
 my ($ip,$p,$p1,$p2);
 foreach $p (
    [1,	$NF_allboys_list,	\%NF_allboys_sync,	\%NF_allboys],
    [2,	$NF_goodboys_list,	\%NF_goodboys_sync,	\%NF_goodboys]
 )
 {
    my($list_id,$list_name,$list_sync,$list_now)=@$p;
    %list=();
    map{ $list{$_}=1 } grep{ !$list_sync->{$_} } keys %$list_now;
    keys(%list) && &HW_set_ip_list( {'action'=>'add','list_id'=>$list_id,'list_name'=>$list_name,'list_ptr'=>\%list} );

    %list=();
    map{ $list{$_}=1 } grep{ !$list_now->{$_} } keys %$list_sync;
    keys(%list) && &HW_set_ip_list( {'action'=>'del','list_id'=>$list_id,'list_name'=>$list_name,'list_ptr'=>\%list} );
 }

 # �����
 %list=();
 foreach $ip (keys %NF_goodboys)
 {
     $p1=$NF_goodboys{$ip};
     $p2=$NF_goodboys_sync{$ip};
     if( !defined($p2) || ($p1->{speed_in} ne $p2->{speed_in}) || ($p1->{speed_out} ne $p2->{speed_out}) )
     {
         $list{$ip}={'speed_in'=>$p1->{speed_in},'speed_out'=>$p1->{speed_out}};
     }
 }
 keys(%list) && &HW_set_queue( {'list_ptr'=>\%list} );

 %NF_allboys_sync=%NF_allboys;
 %NF_goodboys_sync=%NF_goodboys;
}


sub Add_To_Allow_Ip {}
sub Delete_From_Allow_Ip {}
sub Add_To_Table {}
sub Delete_From_Table {}
sub Flush_Table {}

eval{require $NF_hw_module};
$@ && die("$NF_hw_module is not found!");

1;
