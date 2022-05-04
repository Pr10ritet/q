#!/usr/bin/perl
# ==============================================================================#
#										#
#		NoDeny - ������������ ����������/���������� �������		#
#										#
# ==============================================================================#
#
# ���������� cisco �� rsh. ����:
# �� cisco ������ ���� ������ extened access-list � ������� 199 � � ��� ������
# �������� � ������ GOODBOYS (� ������ ������):
#   (config)#ip access-list extended 199
#   (config-ext-nacl)#dynamic GOODBOYS permit ip any any
#   (config-ext-nacl)#exit
# ������ access-list 199 ����� `�������` ip, ������� �������� ������
#
# ��� ��������, � ������� ������� NoDeny ����������:
# rsh -l sysuser cisco_ip access-template 199 GOODBOYS host 10.1.2.3 any
# rsh -l sysuser cisco_ip show access-list 199
#  ������ ����������� �������� ���������:
#    Extended IP access list 199
#    10 permit ip any any
#    20 Dynamic GOODBOYS permit ip any any
#       permit ip host 10.1.2.3 any
#
# rsh -l sysuser 91.209.226.11 clear access-template 199 GOODBOYS host 10.1.2.3 any
#
# ���������� $NF_t_check - ������ � �������� � ������� ��������� ���������������� �� ������
# � cisco. ��� ������ �� ������ ������������ cisco

$NF_verbose=0;	# 1 - �������� �������� `�� �����`, 2 - ����� ��������

$NF_cisco_ip='10.1.2.3';
$NF_rsh_user='nodeny';
$NF_rsh_tmout=3;
$NF_accs_list=199;
$NF_accs_tmpl='GOODBOYS';
$NF_t_check=10;
$NF_t_limit=3;	# ����������� �� ������� �� ���������� Run_Ipfw_Rules, ������ �� �������������� rsh ���
		# ���������� ������� � cisco

$NF_rsh_cmd=`which rsh` || '/usr/bin/rsh';
chomp $NF_rsh_cmd;
$NF_rsh_cmd.=" -n -l $NF_rsh_user -t $NF_rsh_tmout $NF_cisco_ip";
$NF_title='[NOFIRE]';

$NF_t_sync=0;

sub NF_log
{
 ($v or $NF_verbose) && print "$NF_title $_[0]\n";
}

sub NF_com
{
 my ($ip,$com)=@_;
 $com="$NF_rsh_cmd $com access-template $NF_accs_list $NF_accs_tmpl host $ip any 2>/dev/null";
 &NF_log($com);
 $com=`$com`;
 chomp $com;
 $com && &NF_log($com);
}

sub NF_allow
{
 my $ip=$_[0];
 &NF_com($ip,'');
}

sub NF_deny
{
 my $ip=$_[0];
 &NF_com($ip,'clear');
}

#--- ���������� �� noserver ---

sub Flush
{
 %NF_on=();	# ������ ip, ������� ������ �������������� � access-list cisco
 %NF_old=();
}

sub Deny
{
 my $p=$_[0];
 delete $NF_on{$p->{ip}};
}

sub Allow
{
 my $p=$_[0];
 $NF_on{$p->{ip}}=1;
}

sub Run_Ipfw_Rules
{
 my ($com,$ip,$line,$p,$t_limit);
 $t_limit=&TimeNow()+$NF_t_limit;

 if( &TimeNow()>$NF_t_sync )
 {
    &NF_log('Synchronization');
    $p=$NF_t_sync;
    $NF_t_sync=&TimeNow()+$NF_t_check;
    $com="$NF_rsh_cmd show access-list $NF_accs_list 2>/dev/null";
    &NF_log($com);
    $com=`$com`;
    $NF_verbose>1 && &NF_log($com);
    &TimeNow()<$t_limit or return;
    if ($com=~/list/io)
    {  # ������ �������. ��������������, ��� � ������ cisco ����� ������ `Extended IP access list...`
       %NF_old=();
       foreach $line (split /\n/,$com)
       {
          $NF_old{$1}=1 if $line=~/(\d+\.\d+\.\d+\.\d+)/o;
       }
    }
    $p or return; # ��� ������� ��� �� ����������� ���� ��������� ������ ��� ���������
 }

 foreach $ip (grep{ !$NF_old{$_} } keys %NF_on)
 {
    &TimeNow()<$t_limit or last;
    &NF_allow($ip); 
 }

 foreach $ip (grep{ !$NF_on{$_} } keys %NF_old)
 {
    &TimeNow()<$t_limit or last;
    &NF_deny($ip); 
 }
 %NF_old=%NF_on;
}

sub Add_To_All_Ip {}
sub Delete_From_All_Ip {}
sub Add_To_Allow_Ip {}
sub Delete_From_Allow_Ip {}
sub Add_To_Table {}
sub Delete_From_Table {}
sub Flush_Table {}


1;
