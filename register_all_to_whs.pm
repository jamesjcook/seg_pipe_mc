#!/usr/local/pipeline-link/perl

# register_all_to_whs.pm 

# created 2009/11/19 Sally Gewalt CIVM 
# based on rigid_to_canN32083_30jul.sh

my $VERSION = "2009/11/24";
my $NAME = "Alex Badea rigid registering to whs";
my $DESC = "ants";
my $ggo = 1;
my $PM = "register_all_to_whs.pm";

use strict;

# ------------------
sub register_all_to_whs {
# ------------------
  my ($go, $Hf) = @_;
  $ggo = $go;
  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");

  my $whs_xform_path = create_transform_to_whsT1 ('T1_strip_path', $Hf);

  apply_whs_transform ('T2star_strip_path', $whs_xform_path, $Hf);
  apply_whs_transform (   'T2W_strip_path', $whs_xform_path, $Hf);
  apply_whs_transform (    'T1_strip_path', $whs_xform_path, $Hf);

  if ($ggo) {
    unlink($whs_xform_path);  # delete transform, but could keep to combine transforms
  }

  # sets 'T2W_reg2_whs_path', 'T1_reg2_whs_path', 'T2star_reg2_whs_path';
}

# ------------------
sub create_transform_to_whsT1 
# ------------------
{
  my ($to_deform_path_id, $Hf) = @_;

  my $to_deform_path = $Hf->get_value($to_deform_path_id);
  my $domain_dir   = $Hf->get_value ('dir_whs_images');
  my $domain_path  = "$domain_dir/whs_T1_ln.nii";

  if ($ggo) {
    if (!-e $to_deform_path) {error_out ("$PM create_transform_to_whsT1: missing to deform nifti file $to_deform_path\n")}
    if (!-e $domain_path)  {error_out ("$PM create_transform_to_whsT1: missing domain nifti file $domain_path\n")}
  }

  # -- make base path
  # base gets a suffix from ants
  my $dot_less_deform_path       = remove_dot_suffix($to_deform_path);
  my $result_transform_path_base = "$dot_less_deform_path\_2_whsT1_transform_";

  # -- create transform command
  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $xform_path =
     create_transform ($ggo, 'rigid1', $to_deform_path, $domain_path, $result_transform_path_base, $ants_app_dir);
  print "** Rigid WHS transform created for $to_deform_path_id: $xform_path\n";

  return ($xform_path);
}

# ------------------
sub apply_whs_transform 
# ------------------
{
  my ($to_deform_path_id, $xform_path, $Hf) = @_;

  my $result_suffix = "reg2_whs";

  my $to_deform_path = $Hf->get_value($to_deform_path_id); 
  if ($ggo) {
    if (!-e $to_deform_path) {error_out ("$PM apply_whs_transform: missing fixed nifti file $to_deform_path, $to_deform_path_id\n")}
    if (!-e $xform_path) {error_out ("$PM apply_whs_transform: missing xform file $xform_path\n")}
  }
 
  my $domain_dir;
  my $domain_path;
  if (0) { # domain seems to be image itself in rigid_to_can_N32083_30jul.sh...
           # not the whs data as set up here
    $domain_dir   = $Hf->get_value ('dir_whs_images');
    $domain_path  = "$domain_dir/whs_T1_ln.nii";
    if (!-e $domain_path)  {error_out ("$PM apply_whs_transform: missing domain nifti file $domain_path\n")}
  } else {  
    $domain_path = $to_deform_path; 
  }

  # --- set up result nii file path
  my $dot_less_deform_path = remove_dot_suffix($to_deform_path);
  my $result_path = "$dot_less_deform_path\_$result_suffix\.nii"; # ants wants .nii on result_path

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $do_inverse_bool = 1;
  apply_transform($ggo, $to_deform_path, $result_path, $do_inverse_bool, $xform_path, $domain_path, $ants_app_dir);

  # -- store result (registered image's) path in headfile
  #    first make a result_id: remove _strip_path suffix, leave prefix (eg T2star, T2W)
  my @parts = split "_", $to_deform_path_id;
  my $to_deform_id_prefix = shift @parts;

  # save plain filename, too 
  my $result_file_id ="$to_deform_id_prefix\_$result_suffix\_file";
  my $result_path_id ="$to_deform_id_prefix\_$result_suffix\_path";

  my $dot_less_result_path = remove_dot_suffix($result_path);
  my @parts =  split ('/', $dot_less_result_path); 
  my $result_file =  pop @parts; 

  $Hf->set_value($result_path_id, $result_path);
  $Hf->set_value($result_file_id, $result_file);

}
