#!/usr/local/pipeline-link/perl
# register_all_to_channel1.pm 
# modified 2012/03/27 james cook, changed to register an arbitrary number of 
#  channels stored in the head file to the first channel. List should be in 
#  the output headfile at runno_ch_commalist,
#  a comma- separated list of contrast channels (T1,T2W,T2star,fa,adc,dwi,e1)
# created 2009/10/28 Sally Gewalt CIVM 
# will register a list of possible channels, 
#  with values for the input nii stored at ${ch_id}-nii-path stored in the output headfile
#
#
#



my $PM = "Register_all_to_channel1.pm";
my $VERSION = "$PM 2012/03/27";
my $NAME = "Original data set rigid registration ABB Method";
my $DESC = "ants";
my $ggo = 1;
my $debug_val = 5;
use strict;
use warnings;
#use label_brain_pipe;
#use vars qw($test_mode);

my %xformed_runno_and_path=();
my $reg_ch_runno;
my %runno_channel_hash = ();

# ------------------
sub register_all_to_channel1 {
# ------------------
  my ($go, $Hf) = @_;
  $ggo = $go;
  %runno_channel_hash = make_runno_ch_hash($Hf);
  if ($Hf->get_value('registration_channel') eq "NO_KEY") {
      $Hf->set_value('registration_channel',"0");
  }
  my ($channel_N,$registration_channel)=set_channel($Hf);
  my @runno_list = split(',',$Hf->get_value('runno_commalist'));
  $xformed_runno_and_path{$runno_list[$registration_channel]} =  "0" ; # Setting this to zero will tell script to skip registration.

  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");

  my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
 

  if ($#channel_array>=1) {
      my $xform_path;
      my $dummy;
      my $start_channel = 1;
      if ($registration_channel) { # Default should be 1, so first channel won't be processed.
	  $start_channel = 0; # If the reg_channel is not the first element, the first element should be processed.
      }
      for (my $chnum=$start_channel;$chnum<=$#channel_array; $chnum++) {
	  my $ch_id = $channel_array[$chnum];
	  print ("\n\n\t$PM now working on ch_id:$ch_id\n\n\n") if ($debug_val>=35);
	  ($dummy,$xform_path)=register_rigid_to_channel_N("${ch_id}-nii-path", $Hf);
      }
  }
}

# ------------------
sub register_rigid_to_channel1 {
# ------------------
# It is generally assumed that all other channels will be registered to Channel 1.
# This wrapper retains the previous functionality of register_rigid_to_channel1
# while using a more general function of registering to an arbitrary Channel N underneath. 
    my ($to_deform_path_id, $Hf) = @_;
    my ($result_path, $xform_path);
    $Hf->set_value('registration_channel',0);
    ($result_path,$xform_path) = register_rigid_to_channel_N($to_deform_path_id, $Hf);
    return($result_path,$xform_path);
}

# ------------------
sub register_rigid_to_channel_N {
# ------------------
  # register to channel_N:
  my ($to_deform_path_id, $Hf) = @_;
  my ($channel_N,$registration_channel)=set_channel($Hf);
  my $warp_domain_path  = $Hf->get_value ("${channel_N}-nii-path");
  my $to_deform_path    = $Hf->get_value ("$to_deform_path_id");
  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $reg_ch_num = $registration_channel + 1;
  my $xform_path;
  my $dot_less_deform_path = remove_dot_suffix($to_deform_path);
  
  if (! $registration_channel) {
      print("register_rigid_to_channel1:\n\tengine_ants_path:$ants_app_dir\n\tmoving: $to_deform_path_id\n\t mpath: $to_deform_path\n\t fixed: $channel_N\n\t fpath:$warp_domain_path\n") if ($debug_val >=25);
  } else {
      print("register_rigid_to_channel_N (N = ${reg_ch_num} :\n\tengine_ants_path:$ants_app_dir\n\tmoving: $to_deform_path_id\n\t mpath: $to_deform_path\n\t fixed: $channel_N\n\t fpath:$warp_domain_path\n") if ($debug_val >=25);
  }

  my @temp_path = split('-',$to_deform_path_id);
  my  $current_channel = shift(@temp_path);
  my  $current_runno = $runno_channel_hash{$current_channel};
  
  if (! exists $xformed_runno_and_path{$current_runno}) {
      $xform_path = make_transform_path($to_deform_path_id, $Hf);
      $xformed_runno_and_path{$current_runno}= $xform_path;

      apply_transform_path($to_deform_path_id, $xform_path, $Hf);
      
      print STDOUT "  Rigid transform created for runno $current_runno (channel: $current_channel). \n "; 
  } else {
      $xform_path = $xformed_runno_and_path{$current_runno};
      if ($xform_path) {
	  apply_transform_path($to_deform_path_id, $xform_path, $Hf);
	  print STDOUT "  Using rigid registration $xform_path for current channel $current_channel (both from runno $current_runno). \n   No new rigid transformation created.";
      } else {
	  print STDOUT "  No rigid transform needed for channel $current_channel (runno: $current_runno). \n";
      }
  }
 

 # apply_transform_path($to_deform_path_id, $xform_path, $Hf);
 
  my $result_suffix = "reg2_${channel_N}";
  my $result_suffix_id = "reg2-${channel_N}";
  my $result_path = "${dot_less_deform_path}_${result_suffix}.nii"; # ants wants .nii on result_path

  # -- put result registered image's path in headfile
  #    first make registered result id: remove _nii_path suffix, leave prefix (eg T2star, T2W)
  my @parts = split "-", $to_deform_path_id; 
  my $deform_id_prefix = shift @parts;
  my $reg_id ="${deform_id_prefix}-${result_suffix_id}-path";
  $Hf->set_value($reg_id, $result_path);

  if ($ggo) {
  #   unlink($xform_path);  # delete transform, but could keep to combine transforms

      print "** Rigid registration to ${channel_N} created or linked: id $reg_id = $result_path\n";
  }
  return($result_path,$xform_path);
}

# ------------------
sub make_transform_path {
# ------------------

  my ($to_deform_path_id, $Hf) = @_;
  my ($channel_N)=set_channel($Hf);
  my $warp_domain_path  = $Hf->get_value ("${channel_N}-nii-path");
  my $to_deform_path    = $Hf->get_value ("$to_deform_path_id");
  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');

if ($ggo) {
    if (!-e $to_deform_path) {error_out ("$PM register_rigid to ${channel_N}: missing nifti file to deform $to_deform_path, id: $to_deform_path_id\n")}
    if (!-e $warp_domain_path) {error_out ("$PM register_rigid_to_${channel_N}: missing warp_domain nifti file $warp_domain_path, id: '${channel_N}_nii_path'\n")}
  }
  
  # -- make base path
  # base gets a suffix from ants
  my $dot_less_deform_path = remove_dot_suffix($to_deform_path);
 # print STDOUT "~~~dot_less_deform_path = ${$dot_less_deform_path} \n~~~to_deform_path = ${to_deform_path}";
  my $result_transform_path_base = "${dot_less_deform_path}_2_${channel_N}_transform_";

  # -- create transform command
  my $xform_path = 
    create_transform ($ggo, 'rigid1', $to_deform_path, $warp_domain_path, $result_transform_path_base, $ants_app_dir); 
  print "** Rigid transform created for $to_deform_path_id: $xform_path\n";
  return($xform_path);

}

# ------------------
sub apply_transform_path {
# ------------------

  my ($to_deform_path_id, $xform_path, $Hf) = @_;
  my ($channel_N)=set_channel($Hf);
  my $warp_domain_path  = $Hf->get_value ("${channel_N}-nii-path");
  my $to_deform_path    = $Hf->get_value ("$to_deform_path_id");
  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $dot_less_deform_path = remove_dot_suffix($to_deform_path);

  # -- apply the transform to the moving image 
  my $result_suffix = "reg2_${channel_N}"; 
  my $result_suffix_id = "reg2-${channel_N}"; 
  my $result_path = "${dot_less_deform_path}_${result_suffix}.nii"; # ants wants .nii on result_path

  ###apply_transform($ggo, $xform_path, $moving_path, $fixed_path, $result_path, $ants_app_dir); #direct

  my $do_inverse_bool = 1;
  apply_affine_transform ($ggo, $to_deform_path, $result_path, $do_inverse_bool, $xform_path, $warp_domain_path, $ants_app_dir); 

}


# ------------------
sub set_channel {
# ------------------
    my ($Hf) = @_;
    my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
    my $registration_ch = $Hf->get_value('registration_channel');
    my $channel_N=${channel_array[$registration_ch]};
    return($channel_N,$registration_ch);
}

# ------------------
sub make_runno_ch_hash {
# ------------------
    my ($Hf) = @_;
    my @runnos = split(',',$Hf->get_value('runno_commalist'));
    my @channels = split(',',$Hf->get_value('runno_ch_commalist'));
    
    my $run_count = "0";
    my %hash=();
 
    foreach my $ch (@channels) {
	$hash{$ch}=$runnos[$run_count];
	print STDOUT " !!!! $ch -> $hash{$ch}, run_count = ${run_count}. \n ";
	$run_count++;
    }
    return(%hash);
}

1;
