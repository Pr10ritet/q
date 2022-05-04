#!/usr/bin/perl
# ==============================================================================#
#										#
#		NoDeny - подпрограммы разрешения/блокировки доступа		#
#										#
# ==============================================================================#

$FW='/sbin/ipfw -q ';

sub Flush
{
 system("$FW table 0 flush");
}

sub Deny
{
 my $p=$_[0];
 system("$FW table 0 delete ".$p->{ip});
}
sub Allow
{
 my $p=$_[0];
 system("$FW table 0 add ".$p->{ip});
}

sub Add_To_All_Ip {}
sub Delete_From_All_Ip {}
sub Add_To_Allow_Ip {}
sub Delete_From_Allow_Ip {}
sub Add_To_Table {}
sub Delete_From_Table {}
sub Flush_Table {}
sub Run_Ipfw_Rules {}

1;
