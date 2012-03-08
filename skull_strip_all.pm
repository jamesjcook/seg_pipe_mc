#!/usr/local/pipeline-link/perl

# skull_strip_all.pm
# slg made this up based on abb 11/11/09 v of mask_Ts_aug5.m 
# created 2009/11/12 Sally Gewalt CIVM 

my $VERSION = "2009/11/12";
my $NAME = "Alex Badea skull strip Method";
my $DESC = "matlab and ants";
my $ggo = 1;
 
my $SKULL_MASK_MFUNCTION =  "strip_mask";  # an mfile function in matlab directory, but no .m here
my $PM = "skull_strip_all.pm";
use strict;

# ------------------
sub skull_strip_all {
# ------------------
  my ($go, $Hf) = @_;
  $ggo = $go;
  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");
  
  my $mask_path_tmp  = make_skull_mask ('T1_nii_path', 2,  $Hf);
  log_info ("-------reconcile headers: make_sane_mask start");
  make_sane_mask($mask_path_tmp,'T2star_nii_path', $Hf);

  my $norm_mask_path = normalize_skull_mask ($mask_path_tmp, 'norm_mask', $Hf);

   $Hf->set_value('skull_norm_mask_path', $norm_mask_path);  # save mask to aid labelling

   my     $T2_result_path = apply_skull_mask(   'T2W_reg2_T1_path', $norm_mask_path, 'strip', $Hf);
   my $T2star_result_path = apply_skull_mask('T2star_reg2_T1_path', $norm_mask_path, 'strip', $Hf);
   my     $T1_result_path = apply_skull_mask(        'T1_nii_path', $norm_mask_path, 'strip', $Hf);

   # --- store result file paths for masked results under these ids
   $Hf->set_value (   'T2W_strip_path',     $T2_result_path);
   $Hf->set_value ('T2star_strip_path', $T2star_result_path);
   $Hf->set_value (    'T1_strip_path',     $T1_result_path);

   if ($ggo) {
     # you can remove the mask files we have already used
     # but we will keep it so that we can use flag -b 00011, do not redo skull stripping
     # unlink      $mask_path_tmp;
   }

   # result ids: T2W_strip_path, T2star_strip_path, T1_strip_path
}

# ------------------
sub normalize_skull_mask {
# ------------------
  my ($in_image_path, $out_image_suffix, $Hf) = @_;

  my $ants_app_dir  = $Hf->get_value('engine_app_ants_dir');
  my $work_dir      = $Hf->get_value('dir_work');

  my $out_image_path    = "$work_dir/$out_image_suffix\.nii";

  if ($ggo) {
    im_normalize($in_image_path, $out_image_path, $ants_app_dir);
  }

  return($out_image_path);
}

# ------------------
sub apply_skull_mask {
# ------------------
  my ($in_image_path_id, $mask_path, $result_suffix, $Hf) = @_;
  # slg made this up based on abb 11/11/09 v of mask_Ts_aug5.m

  my $in_image_path = $Hf->get_value($in_image_path_id);
  if ($ggo) {
    if (!-e $in_image_path) {error_out("$PM apply_mask: missing image file to mask $in_image_path\n")}
    if (!-e $mask_path)     {error_out("$PM apply_mask: missing mask image file $mask_path\n")}
  }

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $nii_less_path = remove_dot_suffix($in_image_path);
  my $out_nii_path  = "$nii_less_path\_$result_suffix\.nii";

  if ($ggo) {
    im_apply_mask($in_image_path, $mask_path, $out_nii_path, $ants_app_dir);
  }

  return($out_nii_path);
}

# ------------------
sub make_skull_mask {
# ------------------
  my ($template_path_id, $dim_divisor, $Hf) = @_;

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');
  my $work_dir     = $Hf->get_value('dir_work');
  my $template_path= $Hf->get_value($template_path_id);
  if (!-e $template_path)  {error_out("$PM make_skull_mask: missing mask template $template_path\n")}

  my $nii_less_path = remove_dot_suffix($template_path);
  my $mask_path     = "$nii_less_path\mask\.nii";

  my $args = "\'$template_path\', $dim_divisor, \'$mask_path\'";
  my $unique_id = "make_$PID\_";
  my $cmd =  make_matlab_command ($SKULL_MASK_MFUNCTION, $args, $unique_id, $Hf);
  if (! execute($ggo, "make_skull_mask", $cmd) ) {
    error_out("$PM make_skull_mask: Could not create mask $cmd");
  }

  return ($mask_path);
}

