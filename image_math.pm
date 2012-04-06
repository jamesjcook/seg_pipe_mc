#!/usr/local/pipeline-link/perl

# created 2009/11/23 Sally Gewalt CIVM 
# routines that call ants ImageMath

my $VERSION = "2012/03/27";
my $NAME = "image_math";
my $DESC = "ants";
my $ggo = 1;
 
my $PM = "image_math.pm";
use strict;
my $debug_val=0;

# ------------------
sub make_sane_mask {
# ------------------
  my ($go, $mask_image_tmp, $in_image_path_tag, $Hf) = @_;
  $ggo=$go;

  my $in_image_path  = $Hf->get_value($in_image_path_tag);
  my $ants_app_dir= $Hf->get_value('engine_app_ants_dir' );
  if ($ants_app_dir eq 'NO_KEY') { $ants_app_dir= $Hf->get_value('engine-app-ants-dir' ); }
  if ((!-e $in_image_path) && $ggo)  {error_out("$PM normalize: missing input image: $in_image_path\n")}
  print("antsdir:$ants_app_dir\nin_image:$in_image_path\n") if($debug_val >= 10);

  #check origins!
  my $cmd = "$ants_app_dir/CopyImageHeaderInformation $in_image_path $mask_image_tmp $mask_image_tmp 1 1 1"; 

  if (! execute($ggo, "$PM make_sane_mask", $cmd) ) {
    error_out("$PM normalize: could not make your mask header the same as input: $cmd\n");
  }
}


# ------------------
sub im_normalize {
# ------------------
  my ($go, $in_image_path, $out_image_path, $ants_app_dir) = @_;
  $ggo=$go;

  if ((!-e $in_image_path) && $ggo)  {error_out("$PM normalize: missing input image: $in_image_path\n")}

  my $cmd = "$ants_app_dir/ImageMath 3 $out_image_path Normalize $in_image_path"; 
  if (! execute($ggo, "$PM im_normalize", $cmd) ) {
     error_out("$PM normalize: could not normalize: $cmd\n");
  }
}

# ------------------
sub im_apply_mask {
# ------------------
  my ($in_image_path, $mask_path, $out_nii_path, $ants_app_dir) = @_;

  if (!-e $in_image_path) {error_out("$PM im_apply_mask: missing image file to mask $in_image_path\n")}
  if (!-e $mask_path)     {error_out("$PM im_apply_mask: missing mask file $mask_path\n")}
  # multiply image with mask
  my $cmd = "$ants_app_dir/ImageMath 3 $out_nii_path m $in_image_path $mask_path"; 
  if (! execute($ggo, "apply mask", $cmd) ) {
    error_out("$PM im_apply_mask: Could not apply skull mask $cmd\n");
  }
  print "** applied mask to create result: $out_nii_path\n";

  return($out_nii_path);
}

1;
