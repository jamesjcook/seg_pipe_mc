#!/usr/local/pipeline-link/perl

# skull_strip_all.pm
# 2013/07/30 james cook, modified skull strip calls to allow more , 
#            functions through
# 2012/05/10 james cook, added function to use a ported labelset
#            that registeres the atlas mask to the generated mask. 
# 2012/03/27 james cook, fixed up variables to match new convetion, 
#            now skull strips arbitrary number of channel stored in 
#            comma chanel list
# slg made this up based on abb 11/11/09 v of mask_Ts_aug5.m 
# created 2009/11/12 Sally Gewalt CIVM 

my $VERSION = "20130730";
my $NAME = "Alex Badea skull strip Method";
my $DESC = "matlab and ants";
my $ggo = 1;
my $SKULL_MASK_MFUNCTION =  "strip_mask";  # an mfile function in matlab directory, but no .m here
my $PM = "skull_strip_all.pm";
my $debug_val = 5;


use strict;
use vars qw($PID $nchannels);

# ------------------
sub skull_strip_all {
# ------------------
  my ($go, $Hf) = @_;
  my @channel_array=split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1=$channel_array[0];
  $ggo = $go;

  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");



  ####if skull mask does not exist
  my $mask_path_tmp ;    #tmp because we will make sane mask, and then normalize, in the future normalize wont be used(maybe)
  my $norm_mask_path;
  my $nii_less_path = remove_dot_suffix($Hf->get_value("${channel1}-nii-path"));
  $mask_path_tmp = "${nii_less_path}_manual_mask\.nii";
  if ( $Hf->get_value('use_existing_mask')) {

    if ( ! -e $mask_path_tmp ) { 
      error_out(" Did not find manual mask \"$mask_path_tmp\"");
    } 
    log_info ("------- Manual Masking Used:$mask_path_tmp");    
    #$Hf-get_value('manual_mask_path')
  } else {
    $mask_path_tmp  = make_skull_mask ("${channel1}-nii-path", 2,  $Hf);
    log_info ("------- Made skull mask:$mask_path_tmp");    
    ### if using existing mask
    # norm_mask_path = $bla?runno_mask_manual.nii
  }
  log_info ("------- reconcile headers: make_sane_mask start");
  make_sane_mask($ggo, $mask_path_tmp,"${channel1}-nii-path", $Hf);
  $norm_mask_path = normalize_skull_mask ($ggo, $mask_path_tmp, $channel1.'norm_mask', $Hf);
  
  ##### should insert transform whs mask to specimen here.
  # think i want a ... port whs function, might call rigid transform function from registration pm
  if ($Hf->get_value('port_atlas_mask')) { 
      $mask_path_tmp  = port_atlas_mask($ggo,$norm_mask_path, "${channel1}", $Hf); 
      $norm_mask_path = normalize_skull_mask ($ggo, $mask_path_tmp, 'whs_ported_mask', $Hf);
  }
  $Hf->set_value('skull-norm-mask-path', $norm_mask_path);  # save mask to aid labelling
  my $result_path;
  $result_path = apply_skull_mask(   "${channel1}-nii-path", $norm_mask_path, 'strip', $Hf);

# --- store result file paths for masked results under these ids
  $Hf->set_value (   "${channel1}-strip-path",     $result_path  );
  if ($#channel_array>=1) { 
      #for my $ch_id (@channel_array[1,$#channel_array]) {
      for(my $chnum=1;$chnum<=$#channel_array;$chnum=$chnum+1) {
	  #my $ch_id (@channel_array[1,$#channel_array]) {
	  my $ch_id = @channel_array[$chnum];
	  $result_path = apply_skull_mask("${ch_id}-reg2-${channel1}-path", $norm_mask_path, 'strip', $Hf);
     # --- store result file paths for masked results under these ids
	  $Hf->set_value (   "${ch_id}-strip-path",     $result_path);
      }
  }

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
  my ($go, $in_image_path, $out_image_suffix, $Hf) = @_;
  $ggo=$go;
  my $ants_app_dir  = $Hf->get_value('engine-app-ants-dir');
#  if ($ants_app_dir eq 'NO_KEY') {
#      $ants_app_dir  = $Hf->get_value('engine_app_ants_dir');
#  }
  my $work_dir      = $Hf->get_value('dir-work');
  my $out_image_path    = "$work_dir/$out_image_suffix\.nii";
#  if ($ants_app_dir eq '' || $ants_app_dir eq 'NO_KEY' || $ants_app_dir eq 'UNDEFINED') {
#      error_out( 'bad ants_dir in normalize_skull_mask'); }

#  print("normalize_skull_mask: \n\tantsdir:$ants_app_dir,\n\tin_image:  $in_image_path\n\tout_suffix:$out_image_suffix\n\tout_image_path:$out_image_path\n\twork_dir:$work_dir\n") if ($debug_val>=35);
  if ($ggo) {
    im_normalize($ggo, $in_image_path, $out_image_path, $ants_app_dir);
  }

  return($out_image_path);
}

# ------------------
sub apply_skull_mask {
# ------------------
# in_image_path_id  headfile var containing path to input image
# mask_path         path to mask
# result_suffix     text string added to result filename before filename extension
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
  my $num_morphs=5;
  my $morph_radius=2;
  
  my $mask_threshold=$Hf->get_value('threshold_code');
                         # -1 use imagej (like evan and his dti pipe)
                         # 0-100 use threshold_zero 0-100, 
                         # 100-inf is set threshold.
  my $status_display_level=0;
                         # 2 show lots of progress nii intermediates, and plot for threshold 0 finding
                         # 1 show just the most relevent nii intermediates, and plot for threshold 0 finding
                         # 0 show no figures.
  my $args = "\'$template_path\', $dim_divisor, $mask_threshold, \'$mask_path\',$num_morphs , $morph_radius,$status_display_level";
  my $unique_id = "make_$PID\_";
  my $cmd =  make_matlab_command ($SKULL_MASK_MFUNCTION, $args, $unique_id, $Hf);
  if (! execute($ggo, "make_skull_mask", $cmd) ) {
    error_out("$PM make_skull_mask: Could not create mask $cmd");
  }
  return ($mask_path);
}

# ------------------
sub port_atlas_mask {
# ------------------
    my ($ggo,$mask_path, $result_suffix, $Hf) =@_;
    # get altas file
    # get 
    my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
    my $atlas_images_dir = $Hf->get_value('dir-atlas-images');
    my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
    my $to_deform_path =  $mask_path;
	
    #my $domain_path = $atlas_images_dir . "/${atlas_id}_maskMD.nii";
    my $domain_path = $atlas_images_dir . "/${atlas_id}_mask.nii";
#    my $warp_domain_path=$domain_path;
    my $interp= '--use-NN';

    my $dot_less_deform_path       = remove_dot_suffix($to_deform_path);
    my ($domain_name,$domain_folder,$domain_suffix) = fileparts($domain_path);
    my ($to_deform_name,$to_deform_folder,$to_deform_suffix) = fileparts($to_deform_path);
    my $result_transform_path_base = "${to_deform_folder}/${to_deform_name}_2_${domain_name}_transform_";
###
# calc transform
    my $transform_path=create_transform ($ggo, 'nonrigid_MSQ', $domain_path, $to_deform_path, $result_transform_path_base, $ants_app_dir);
    
#   my $result_path = "${dot_less_deform_path}_${result_suffix}\.nii"; # ants wants .nii on result_path

    
###
# apply transform
# must now change the deform and domain, we're an inverse
# 
    $to_deform_path=$domain_path; # change to the atlas
    $domain_path=$mask_path;      # change to the input mask
    my ($domain_name,$domain_folder,$domain_suffix) = fileparts($domain_path);
    my ($to_deform_name,$to_deform_folder,$to_deform_suffix) = fileparts($to_deform_path);

    my $result_path="${domain_folder}/${to_deform_name}_2_${domain_name}.nii";	
    my $do_inverse_bool=1;# we want to start exposing this option.
    apply_affine_transform ($ggo, $to_deform_path, $result_path, $do_inverse_bool, $transform_path, $domain_path, $ants_app_dir, $interp); 
    return ($result_path);
}
