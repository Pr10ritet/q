$VER_cfg+=0;

if( !$VER_cfg )
{
  $Dopfields_tmpl{1}||='Технические данные-';
  $Kern_t_to_deny||=$time_to_deny || 150;
  $Kern_t_chk_auth||=$Period_check_auth || 5;
  $Kern_t_traf||=$Period_traf || 30 unless defined $Kern_t_traf;
  $Kern_t_usr_reload||=$interval_oprosa_state || 60;
  $Kern_login_days_keep||=$login_log_day	|| 31;
  $Kern_Dtraf_days_keep||=$Dtraf_days_keep || 31;
  $Plan_got_money_day||=$day_got_money || 1;
  $Traf_zero_flush||=$flush_ifzerotraf;
  $Max_list_users||=$max_users_in_list;
  $Max_list_pays||=$max_pays_in_list;
  $Max_line_chanal||=$max_line_chanal;
  $Bold_out_traf||=$bold_if_out;
  $Block_bonus_pay||=$block_bonus_pay;
  %Regions=%regions;
}

$VER_cmp=$VER_cfg<50? $VER_cfg : $VER_cfg<51? $VER_cfg-1 : $VER_cfg;

if( $VER_cmp<49.11 )
{
  $Nodeny_dir='/usr/local/nodeny';
}

if( $VER_cmp<49.14 )
{
  $Log_file=$log;
}

if( $VER_cmp<49.20 )
{
  $UsrList_cols_template_max=3;
}

if( $VER_cmp<49.21 )
{
  $Dopfields_tmpl{2}='Адрес-adress';
}

if( $VER_cmp<49.33 )
{
  push @Plugins,'Sdogovor';
}

1;

