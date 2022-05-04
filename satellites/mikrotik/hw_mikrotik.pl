#!/usr/bin/perl

use Time::HiRes qw( clock_gettime CLOCK_MONOTONIC gettimeofday tv_interval usleep );
use IO::Socket;
use Digest::MD5;

use strict;

my $HW_nas_ip='172.17.17.88';
my $HW_nas_port=8728;
my $HW_nas_user='nodeny';
my $HW_nas_pass='33';

# === Технические детали ===
my $HW_nas_connect_t_out=2;	# таймаут на создание соединение с NAS
my $HW_nas_reconnect_t=10;	# если коннект с NAS отвалится, то пересоединяться не чаще этих секунд

# ===

my $HW_error='';
my $sock='';
my $HW_error_t=0;
my $HW_tag=0;
my %HW_list_id;
my $HW_list_id=0;
our($v,$NF_verbose);

sub hw_time_now
{
 return(int clock_gettime(CLOCK_MONOTONIC));
}

sub hw_debug
{
 ($v or $NF_verbose) && print "\033[1m[hw_mikrotik]\033[0m $_[0]\n";
 return 1;
}

# === API Mikrotik start =======================================================

# === SEND ===

sub set_len
{
  my($len,$bytes,$str)=($_[0],'','');
  $bytes=$len < 0x80? 1 : $len < 0x4000? 2 : $len < 0x200000? 3 : $len < 0x10000000? 4 : 5;
  $len|=(0x0F >> (5-$bytes)) << ($bytes*8-$bytes+1);
  while( $bytes-- )
  {
     $str.=chr($len & 0xFF);
     $len>>=8;
  }
  return $str;
}

sub hw_send_word
{
  my($sock,$word)=@_;
  my $len=&set_len(length($word));
  print $sock $len.$word;
}

sub hw_send_all
{
  my($sock,$sentence_ref)=@_;
  foreach my $word (@$sentence_ref)
  {
     &hw_debug("[ ->] $word");
     &hw_send_word($sock,$word);
  }
  &hw_send_word($sock,'');
  return 1;
}

#=== RECIVE ===

sub hw_recv_data
{
  my($sock,$data_ref,$len)=@_;
  my $t_out=&hw_time_now()+2;
  $$data_ref='';
  while( &hw_time_now()<$t_out )
  {
     defined(sysread($sock,$$data_ref,$len)) && return length($$data_ref);
     usleep(1000); # sleep 0.001 sec
  }
  $HW_error="hw_recv_data: reciving error";
  return 0;
}

sub get_len
{
  my($sock)=@_;
  my($len,$c,$bytes);
  unless( &hw_recv_data($sock,\$c,1) )
  {
     $HW_error.=" while getting firts symbol of a len";
     return -1;
  }
  $c=ord($c);
  $c<0x80 && return $c;
  $bytes=$c<0xC0? 1 : $c<0xE0? 2 : $c<0xF0? 3 : 4;
  $len=$c & (0xFF >> $bytes);
  while( $bytes-- )
  {
     unless( &hw_recv_data($sock,\$c,1) )
     {
        $HW_error.=" while getting a len";
        return -1;
     }
     $len=($len << 8) + ord($c);
  }
  if( $len>10**6 )
  {  # let length > 1Mb is error length
     &hw_recv_data($sock,\$c,10**6);
     $len=-1;
  }
  return $len;
}

sub hw_recv_word
{
  my($sock,$word_href)=@_;
  my($len,$recv_len,$buf);
  $$word_href='';
  $len=&get_len($sock);
  $len or return 1;
  if( $len<0 )
  {
     $HW_error="hw_recv_word[1]: $HW_error";
     return 0;
  }
  while(1)
  {
      $buf='';
      $recv_len=&hw_recv_data($sock,\$buf,$len);
      if( $recv_len<=0 )
      {
         $HW_error="hw_recv_word[2]: $HW_error";
         return 0;
      }
      $$word_href.=$buf;
      last if $recv_len>=$len;
      $len-=$recv_len;
  }
  &hw_debug("[<- ] $$word_href");
  return 1;
}

sub hw_recv_all
{
  my ($sock,$reply_ref)=@_;
  my $word;
  @$reply_ref=();
  while(1)
  {  
     unless( &hw_recv_word($sock,\$word) )
     {
       $HW_error="hw_recv_all: $HW_error";
       return 0;
     }
     ($word eq '') && last;
     push @$reply_ref,$word;
  }
  return 1;
}

sub hw_dialog
{# юзать только, если заранее известно, что не будет попадаться одинаковых имен атрибутов!!
  my($sock,$cmd_ref,$reply_ref,$attr_ref)=@_;
  %$attr_ref=();
  &hw_send_all($sock,$cmd_ref) or return 0;
  &hw_recv_all($sock,$reply_ref) or return 0;
  foreach (@$reply_ref)
  {
     /^=([^=]+)=(.*)$/ && ($attr_ref->{$1}=$2);
  }
  return 1;
}

sub hw_connect
{
  my($md5);
  my(@cmd,@reply,%attr);
  $HW_error='';
  $sock='';
  &hw_debug('start connecting to the mikrotik');
  $sock=new IO::Socket::INET(PeerAddr=>$HW_nas_ip, PeerPort=>$HW_nas_port, Proto=>'tcp', Timeout=>$HW_nas_connect_t_out);
  if( !$sock )
  {
     $HW_error=$!;
     return 0;
  }
  $sock->blocking(0);
  @cmd=('/login');
  &hw_dialog($sock,\@cmd,\@reply,\%attr);
  exists $attr{ret} or return 0;
  $md5=new Digest::MD5;
  $md5->add(chr(0));
  $md5->add($HW_nas_pass);
  $md5->add(pack("H*",$attr{ret}));
  @cmd=('/login','=name='.$HW_nas_user,'=response=00'.$md5->hexdigest);
  &hw_dialog($sock,\@cmd,\@reply,\%attr) or return 0;
  return ($reply[0] eq '!done');
}

# === API Mikrotik end =========================================================

sub HW_connect
{# соединяемся не чаще $HW_nas_reconnect_t сек
 $sock='';
 $HW_error_t>&hw_time_now() && &hw_debug('Need wait before connect.') && return 0;
 &hw_connect() && return 1;
 $sock='';
 &hw_debug('error connecting');
 $HW_error_t=&hw_time_now() + $HW_nas_reconnect_t;
 return 0;
}

sub HW_get_ip_list
{
 # Получает от MT acces-list-ы и возвращает в виде хеша:
 # { 
 #   '10.0.0.1' => { speed_in => 640000, speed_out => 128000, list => ['goodboys','allboys'] },
 #   '10.0.0.2' => { speed_in => 256000, speed_out => 256000, list => [] }
 # };
 # 10.0.0.1 присутствует в access листах goodboys и allboys
 # 10.0.0.2 отстутствует в access листах, но в queue есть
 
 my ($p)=$_[0]->{list_ptr};
 my ($ip,$ips,$list,$speed,$speed_in,$speed_out,$word);
 my (@cmd);
 my $lines=0;
 $sock or &HW_connect() or return 0;

 while(&hw_recv_word($sock,\$word)) {$lines++}; # опустошим буфер приема
 &hw_send_all($sock,['/ip/firewall/address-list/print']);
 usleep(500000); # Подождем 0.5 сек (это очень редко будет)
 
 $ips=$list='';
 $lines=0;
 while( &hw_recv_word($sock,\$word) )
 {
    $lines++;
    if( $word eq '!re' || $word eq '!done' )
    {
       if( $ip ne '' && $list ne '' )
       {
          &hw_debug("[HW_get_ip_list] found $ip in list: $list");
          push @{$p->{$ip}{list}},$list;
          $p->{$ip}{speed_in}||=0;
          $p->{$ip}{speed_out}||=0;
       }
       $ip=$list='';
       next;
    }
    $word=~/^=([^=]+)=(.*)$/ or next;
    $list=$2 if $1 eq 'list';
    $ip=$2 if $1 eq 'address';
 }

 if( !$lines )
 {
    $sock='';
    return 0;
 }

 &hw_send_all($sock,['/queue/simple/print']);
 usleep(500000); # ждем 0.5 сек

 $ip=$speed='';
 while( &hw_recv_word($sock,\$word) )
 {
    $lines++;
    if( $word eq '!re' || $word eq '!done' )
    {
       if( $ips ne '' && $speed ne '' )
       {
          ($speed_in,$speed_out)=split /\//,$speed;
          foreach $ip (split /,/,$ips)
          {
             $ip=~s|/.*$||;
             &hw_debug("[HW_get_ip_list] $ip. Speed_in: $speed_in, speed_out: $speed_out");
             $p->{$ip}{speed_in}=$speed_in;
             $p->{$ip}{speed_out}=$speed_out;
          }
       }
       $ips=$speed='';
       next;
    }
    $word=~/^=([^=]+)=(.*)$/ or next;
    $speed=$2 if $1 eq 'limit-at';
    $ips=$2 if $1 eq 'target-addresses';
 }
 return $lines;
}

sub HW_set_tag
{
   $HW_tag=1 if $HW_tag++>99999;
}

sub HW_set_ip_list
{
 my($list_id,$list_name,$action,$p)=@{$_[0]}{'list_id','list_name','action','list_ptr'};
 my($ip,$id);
 my(@cmd);
 &hw_debug("[HW_set_ip_list] list_name: $list_name, act: $action");
 $sock or &HW_connect() or return 0;
 $action=$action eq 'add';
 foreach $ip (keys %$p)
 {
    &HW_set_tag();
    $id=$list_id;
    map{ $id=$id*256 + $_ } split /\./,$ip;
    @cmd=$action? (
         "/ip/firewall/address-list/add",
         "=list=$list_name",
         "=address=$ip",
         "=comment=$id",
         "=disabled=no",
         ".tag=$HW_tag"
       ) : (
         "/ip/firewall/address-list/remove",
         "=.id=$id",
         ".tag=$HW_tag"
       );
    &hw_send_all($sock,\@cmd);
 }
 return 1;
}

sub HW_set_queue
{
 my ($p)=@{$_[0]}{'list_ptr'};
 my ($id,$ip,$speed_in,$speed_out);
 $sock or &HW_connect() or return 0;
 foreach $ip (keys %$p)
 {
    $speed_in=$p->{$ip}{speed_in};
    $speed_out=$p->{$ip}{speed_out};
    $id=0;
    map{ $id=$id*256 + $_ } split /\./,$ip;
    &HW_set_tag();
    &hw_send_all($sock,[
      "/queue/simple/add",
      "=name=$id",
      "=target-addresses=$ip",
      "=limit-at=$speed_in/$speed_out",
      "=max-limit=$speed_in/$speed_out",
      "=disabled=no",
      ".tag=$HW_tag"
    ]);
    &HW_set_tag();
    &hw_send_all($sock,[
      "/queue/simple/set",
      "=.id=$id",
      "=limit-at=$speed_in/$speed_out",
      "=max-limit=$speed_in/$speed_out",
      ".tag=$HW_tag"
    ]);

 }
 return 1;
}

1;
