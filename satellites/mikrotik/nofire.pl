#!/usr/bin/perl
# ==============================================================================
#
#		NoDeny - подпрограммы управления удаленным NAS
#
# ==============================================================================
#
# Суть управления доступами ip на удаленном NAS сводится к тому, что необходимо
# динамически добавлять либо удалять ip из определенных списков NAS. Обычно
# эти списки называются access-list (cisco) или address-list (mikrotik).
# 
# Минимально, необходимо управлять одним списком, к примеру, с названием goodboys.
# Все ip, которые находятся в списке goodboys будут иметь доступ в интернет, в
# противном случае, все иные ip будут заблокированы.
#
# NoDeny также поддерживает ведение нескольких списков, что в некоторых случаях
# может быть просто необходимо. Например, представьте ситуацию, когда существует
# несколько NAS, к которым подключены клиенты. Клиент A на NAS1 посылает пакет
# клиенту Б на NAS2. При этом клиент Б находится в заблокированном состоянии.
# Поскольку ip клиента A находится в списке goodboys, то пакет будет разрешен
# и пойдет в направлении клиента Б. На NAS2 он будет заблокирован, однако, через
# NAS1 он все таки пройдет и будет засчитан клиенту A как исходящий трафик
# (даже это не есть проблема - локальный не тарифицируется, все равно лучше
# блокировать такой трафик на NAS1). 
#
# (Читая эти строки у вас в голове могут проскакивать идеи как обойтись одним
# списком -  к сожалению, не получится. Автору приходится неоднократно доказывать
# этот момент и после детального изучения ситуации опоненты соглашаются)
#
# Итак, цель данного скрипта:
#  - добавить в список `xxxboys` тех, кто должен быть в этом списке;
#  - удалить тех, кто не должен.
#
# Далее в качестве примера возьмем список goodboys. Существует 2 массива:
#  %NF_goodboys	- содержит ip тех клиентов, которые должны быть в списке goodboys
#  %NF_goodboys_sync   - содержит ip тех клиентов, которые уже в списке goodboys
#
# Если необходимо записать ip в список, то сперва он попадает в %NF_goodboys, если
# необходимо удалить - удаляется из этого хеша. Это делается подпрограммами 
# &Allow, &Deny и другими.
#
# Вызов этих подпрограмм не ведет к непосредственной команде NAS добавить или удалить
# ip из списка. Дело в том, что обычно существует вариант послать на NAS несколько команд
# сразу, при этом они будут выполнены гораздо быстрее чем по одной. К примеру, если вы
# попытаетесь записать несколько десятков тысяч правил с помощью утилиты ipfw, то при
# однократных вызовах пройдет несколько минут пока все будет создано. Если же послать
# список команд в виде файла, то запись происходит практически мгновенно.
#
# Исходя из этого предусмотрен такой механизм - данные накапливаются и выполняются
# с периодом секунда - довольно минимальная инерционность.
#
# Такой механизм реализован в подпрограмме Run_Ipfw_Rules.
# После непосредственного добавления/удаления ip на NAS, происходит модификация %NF_goodboys_sync.
# Следовательно %NF_goodboys_sync - это отражение того, какие ip реально в списке на NAS.
# Однако, поскольку может произойти рассинхронизация, например, в результате обрыва связи либо
# перезагрузки NAS либо иных лагов, может оказаться, что %NF_goodboys_sync уже не будет
# отражать действительную ситуацию, т.е. иметь в списке лишние ip, либо в нем будут остутствовать
# необходимые ip.
#
# Поэтому время от времени происходит синхронизация списков с периодом $NF_t_check.
# Если NAS не может предоставить списки ip, то синхронизация не будет использована, т.е.
# будет считаться, что списки синхронизированы всегда.
#
# Не следует задавать $NF_t_check слишком маленьким для повышения реакции на лаги. Во-первых
# они обычно крайне редки, во-вторых, не забывайте, что в списке передаются данные по всем
# ip - это объем трафика и это время на его передачу.

$NF_hw_module='hw_mikrotik.pl';

$NF_verbose=0;	# 1 - действия выводить `на экран`, 2 - очень подробно

$NF_allboys_list='allboys';
$NF_goodboys_list='goodboys';

$NF_t_check=30;

$NF_title='[nofire]';

$NF_t_sync=0;

sub NF_Debug
{
 ($v or $NF_verbose) && print "$NF_title $_[0]\n";
}

#--- Вызываются из noserver ---

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
    $old_t_sync or return; # при запуске еще не установлено кому разрешить доступ или запретить
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

 # Шейпы
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
