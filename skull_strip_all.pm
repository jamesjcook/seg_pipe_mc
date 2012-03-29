#!/usr/local/pipeline-link/perl

# skull_strip_all.pm
# 2012/03/27 james cook, fixed up variables to match new convetion, 
#            now skull strips arbitrary number of channel stored in 
#            comma chanel list
# slg made this up based on abb 11/11/09 v of mask_Ts_aug5.m 
# created 2009/11/12 Sally Gewalt CIVM 

my $VERSION = "2012/03/27";
my $NAME = "Alex Badea skull strip Method";
my $DESC = "matlab and ants";
my $ggo = 1;
my $SKULL_MASK_MFUNCTION =  "strip_mask";  # an mfile function in matlab directory, but no .m here
my $PM = "skull_strip_all.pm";
my $debug_val=30;

use strict;
use vars qw($PID);

# ------------------
sub skull_strip_all {
# ------------------
  my ($go, $Hf) = @_;
  my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1=$channel_array[0];
  my $channel3=$channel_array[2];
  $ggo = $go;
  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");


  log_info ("-------reconcile headers: make_sane_mask start");
  my $mask_path_tmp  = make_skull_mask ("${channel1}-nii-path", 2,  $Hf);
  make_sane_mask($mask_path_tmp,"${channel3}-nii-path", $Hf);
  my $norm_mask_path = normalize_skull_mask ($mask_path_tmp, 'norm_mask', $Hf);
  $Hf->set_value('skull-norm-mask-path', $norm_mask_path);  # save mask to aid labelling
  my $result_path;

  $result_path = apply_skull_mask(   "${channel1}-nii-path", $norm_mask_path, 'strip', $Hf);
# --- store result file paths for masked results under these ids
  $Hf->set_value (   "${channel1}-strip-path",     $result_path  );
  for my $ch_id (@channel_array[1,$#channel_array]) {
      $result_path = apply_skull_mask("${ch_id}-reg2-${channel1}-path", $norm_mask_path, 'strip', $Hf);
# --- store result file paths for masked results under these ids
      $Hf->set_value (   "${ch_id}-strip-path",     $result_path);
  }
### commented old non-looping version
#    my     $T2_result_path = apply_skull_mask(   'T2W_reg2_T1_path', $norm_mask_path, 'strip', $Hf);
#    my $T2star_result_path = apply_skull_mask('T2star_reg2_T1_path', $norm_mask_path, 'strip', $Hf);
#    my     $T1_result_path = apply_skull_mask(        'T1_nii_path', $norm_mask_path, 'strip', $Hf);
#    # --- store result file paths for masked results under these ids
#    $Hf->set_value (   'T2W_strip_path',     $T2_result_path);
#    $Hf->set_value ('T2star_strip_path', $T2star_result_path);
#    $Hf->set_value (    'T1_strip_path',     $T1_result_path);

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

  my $ants_app_dir  = $Hf->get_value('engine-app-ants-dir');
  my $work_dir      = $Hf->get_value('dir-work');

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
  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  if ($ants_app_dir eq 'NO_KEY'){ $ants_app_dir = $Hf->get_value('engine_app_ants_dir'); }
  my $in_image_path = $Hf->get_value($in_image_path_id);
#  if ($in_image_path eq 'NO_KEY') { error_out("could not find registered image for ch_id $in_image_path_id"); }
  print("apply_skull_mask:\n\tengine_ants_path:$ants_app_dir\n\tin_image_path:$in_image_path\n") if ($debug_val>=25);
  if ($ggo) {
    if (!-e $in_image_path) {error_out("$PM apply_mask: missing image file to mask $in_image_path\n")}
    if (!-e $mask_path)     {error_out("$PM apply_mask: missing mask image file $mask_path\n")}
  }



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

  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $work_dir     = $Hf->get_value('dir-work');
  my $template_path= $Hf->get_value($template_path_id);
  if (!-e $template_path)  {error_out("$PM make_skull_mask: missing mask template $template_path\n")}

  my $nii_less_path = remove_dot_suffix($template_path);
  my $mask_path     = "${nii_less_path}_mask\.nii";

  my $args = "\'$template_path\', $dim_divisor, \'$mask_path\'";
  my $unique_id = "make_$PID\_";
  my $cmd =  make_matlab_command ($SKULL_MASK_MFUNCTION, $args, $unique_id, $Hf);
  if (! execute($ggo, "make_skull_mask", $cmd) ) {
    error_out("$PM make_skull_mask: Could not create mask $cmd");
  }

  return ($mask_path);
}

