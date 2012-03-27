#!/usr/local/pipeline-link/perl

# register_all_to_T1.pm 
# created 2009/10/28 Sally Gewalt CIVM 


my $PM = "Register_all_to_channel1.pm";
my $VERSION = "$PM 2012/03/27";
my $NAME = "Original data set rigid registration ABB Method";
my $DESC = "ants";
my $ggo = 1;
my $debug_val=10;
use strict;
#use label_brain_pipe;
#use vars qw($test_mode);

# ------------------
sub register_all_to_channel1 {
# ------------------
  my ($go, $Hf) = @_;
  $ggo = $go;
  my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");


  for my $ch_id (@channel_array[1,2]) {
      register_rigid_to_channel1("$ch_id\-nii-path", $Hf);
  }
#  register_rigid_to_channel1('T2star_nii_path', $Hf);
#  register_rigid_to_channel1('T2W_nii_path'   , $Hf);
 
  # result ids in headfile: T2star_reg2_T1_path, T2W_reg2_T1_path, T1_nii_path

}

# ------------------
sub register_rigid_to_channel1 {
# ------------------
  my ($to_deform_path_id, $Hf) = @_;

  # register to channel1:
  my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1=${channel_array[0]};
  my $warp_domain_path  = $Hf->get_value ("${channel1}-nii-path");
  my $to_deform_path    = $Hf->get_value ($to_deform_path_id);
  print("\tmoving: $to_deform_path_id\n\t mpath: $to_deform_path\n\t fixed: $channel1\n\t fpath:$warp_domain_path\n") if ($debug_val >=10);

  if ($ggo) {
    if (!-e $to_deform_path) {error_out ("$PM register_rigid to ${channel1}: missing nifti file to deform $to_deform_path, id: $to_deform_path_id\n")}
    if (!-e $warp_domain_path) {error_out ("$PM register_rigid_to_${channel1}: missing warp_domain nifti file $warp_domain_path, id: '${channel1}_nii_pathr'\n")}
  }
  
  # -- make base path
  # base gets a suffix from ants
  my $dot_less_deform_path = remove_dot_suffix($to_deform_path);
  my $result_transform_path_base = "$dot_less_deform_path\_2_T1_transform_";

  # -- create transform command

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $xform_path = 
    create_transform ($ggo, 'rigid1', $to_deform_path, $warp_domain_path, $result_transform_path_base, $ants_app_dir); 
  print "** Rigid transform created for $to_deform_path_id: $xform_path\n";

  # -- apply the transform to the moving image 
  my $result_suffix = "reg2_T1"; 
  my $result_path = "$dot_less_deform_path\_$result_suffix\.nii"; # ants wants .nii on result_path

  ###apply_transform($ggo, $xform_path, $moving_path, $fixed_path, $result_path, $ants_app_dir); #direct

  my $do_inverse_bool = 1;
  apply_transform ($ggo, $to_deform_path, $result_path, $do_inverse_bool, $xform_path, $warp_domain_path, $ants_app_dir); 

  # -- put result registered image's path in headfile
  #    first make registered result id: remove _nii_path suffix, leave prefix (eg T2star, T2W)
  my @parts = split "_", $to_deform_path_id; 
  my $deform_id_prefix = shift @parts;
  my $reg_id ="$deform_id_prefix\_$result_suffix\_path";
  $Hf->set_value($reg_id, $result_path);

  if ($ggo) {
    unlink($xform_path);  # delete transform, but could keep to combine transforms
    print "** Rigid registration to T1 created: id $reg_id = $result_path\n";
  }

}

