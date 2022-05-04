#!/usr/bin/perl

sub Flush
{
 print "flush all my rules\n";
}

sub Allow
{
 my $p=$_[0];
 print 'ON: '.$p->{ip}.
       ' num: '.$p->{num}.
       ' auth: '.$p->{auth}.
       ' packet: '.$p->{paket}.
       "\n";
}

sub Deny
{
 my $p=$_[0];
 print 'OFF: '.$p->{ip}."\n";
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

