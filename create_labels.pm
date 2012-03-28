#!/usr/local/pipeline-link/perl
# create_labels.pm 

# based on label_brain_0.sh by abb
# 2012/03/28 james cook, modified to chang whs to atlas, since we can use any 
#            atlas, we shouldnt be calling it whs now should we....
# 2012/03/27 james cook, began modifiication to work for arbitrary mc pipe
# 2011/1/20  skull ref maskfound in selected current canonical labels directory.
# 2010/3/02  slg warpImageMultitransform changed with new ANTS version -  regarding gz??
#                Add Byte conversion ants command to warp_label_image routine.
# 2009/12/09 slg diff syn iteration changes from Alex, orig still working after 3 days
# 2009/12/09 slg iteration changes from Alex
# created 2009/10/28 Sally Gewalt CIVM



my $VERSION = "2012/03/28";
my $NAME = "Alex Badea brain label creation Method";
my $DESC = "matlab and ants with ref skull mask (v2)";
my $PM = "create_labels.pm";
my $ggo = 1;
my $PM_stages=5;

use strict;
use label_brain_pipe;
use vars qw($test_mode);

my $nchannels=2; # number of channels to include in metrics, be nice to use all channels, but thats for the future. 

# both create tranforms subs use these:
my $gcurrent_T2W_path;
my $gcurrent_T1_path;
my $gwhs_T2W_path;
my $gwhs_T1_path;

my $DEBUG_GO = 1;
my $debug_val = 35;
my $SYNSETTING=0.5;
#my $METRIC = "MI"; # could be any of the ants supported metrics, defined in main as a global, so bad to do that. should really chage that....



# ------------------
sub create_labels {
# ------------------
  my ($go, $Hf) = @_;
  $ggo = $go; 
  my $atlas_id  = $Hf->get_value('reg-target-atlas-id');

  log_info ("$PM name: $NAME; go=$go");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");

  my $affine_xform  = create_multi_channel_affine_transform ($Hf);

  my ($ds_affine_xform_base, $ds_warp_xform_base, $ds_inverse_warp_xform_base, $ants_transform_prefix) = create_multi_channel_diff_syn_transform ($affine_xform, $SYNSETTING , $Hf); #defines syn_setting as 0.5, we could save this to hf perhaps., or more fun, specify it elsewhere and store in headfile.

  my $label_path      = warp_canonical_labels($ants_transform_prefix, $Hf);

  #####my $warp_label_path = warp_label_image($ds_affine_xform_base, $ds_warp_xform_base, $Hf);
  my $warp_label_path = warp_label_image($ds_affine_xform_base, $ds_inverse_warp_xform_base, $Hf);
  warp_canonical_image($ds_affine_xform_base, $ds_inverse_warp_xform_base, $Hf);
 
  log_info ("Pipeline created result 1: $label_path\n");
  log_info ("Pipeline created result 2: $warp_label_path\n");

}

# ------------------
sub create_multi_channel_affine_transform {
# ------------------
#  my ($current_channel2_path_id, $current_channel1_path_id, $Hf) = @_;
# take the two hfkeys to transform to read a path from.
#   this is where we finally check for files existing, i kinda think 
# it'd be good to pull that check out much earlier.
#   i think the metrics should probably be in definition 
# files rather than in the script here. 
# i should work on that. 
# this would change the funtion flow from if metric a, hardcode value b to load metrics, if metric a, value read b .

  my ($Hf) = @_;
  print("\n\n\t$PM stage 1/$PM_stages \"create_multi_channel_affine_transform\" \n\n\n") if ($debug_val >= 35) ;
  my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
  my $atlas_images_dir = $Hf->get_value('dir-atlas-images');
  my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
  my $work_dir         = $Hf->get_value('dir-work');
  my $metric           = $Hf->get_value('ANTS-affine-metric');
  my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1 = ${channel_array[0]};
  my $result_transform_path_base = "$work_dir/${channel1}_label_transform_";
 
# build metrics, only using first two channels for now, i want to change that later. 
  my $metrics='';
  for my $ch_id (@channel_array[0,$nchannels-1]) {
      my $channel_option = $Hf->get_value("affine-${metric}-${ch_id}-weighting");
      if ( $channel_option eq 'NO_KEY' ) { error_out ("could not find metric affine-${metric}-${ch_id}-weighting "); }
      my $channel_path      = $Hf->get_value("${ch_id}-reg2-${atlas_id}-path");
      my $atlas_image_path  = "${atlas_images_dir}/${atlas_id}_${ch_id}.nii"; # $Hf->get_value();
      if ( ! -e $channel_path ) { # crap out on missing file
	  error_out ("$PM create_multi_channel_affine_transform: $channel_path does not exist<${ch_id}-reg2-${atlas_id}-path>");
      } else {
	  $metrics = $metrics . " -m ${metric}[${atlas_image_path},${channel_path},${channel_option}]"; 
      }
  }
# ########
# #for mutual information metric use THIS IS CONTROLed ELSEWHRE NOW< SET THE ANTSAFFINEMETRIC VALUE at the start of main_seg_pipe_mc.pl
#   my $metric0 = "$gwhs_T1_path,$gcurrent_T1_path,0.7,32";
#   my $metric1 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.3,32";
# #####
# #for PR metric use
#   #my $metric0 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.8,2";
#   #my $metric1 = "$gwhs_T1_path,$gcurrent_T1_path,1,2:";
# ######
  my $other_options = "-i 0 --number-of-affine-iterations 3000x3000x3000x3000 --MI-option 32x32000 --use-Histogram-Matching --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001";
  if ( defined($test_mode)) {
      if( $test_mode == 1 ) {
	  $other_options = "-i 0 --number-of-affine-iterations 1x0x0x0 --MI-option 32x32000 --use-Histogram-Matching --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001"; 
      }
  }
#for mutual information metric use 
# my $cmd = "$ants_app_dir/ants 3 -m ${METRIC}[$metric0] -m ${METRIC}[$metric1] -o $result_transform_path_base $other_options";
 my $cmd = "$ants_app_dir/ants 3 $metrics -o $result_transform_path_base $other_options";
#for PR use
 #my $cmd = "$ants_app_dir/ants 3 -m PR[$metric0] -m PR[$metric1] -o $result_transform_path_base $other_options";
 #my $cmd = "$ants_app_dir/ants 3 $metrics -o $result_transform_path_base $other_options";
  if ($DEBUG_GO) { 
      if (! execute($ggo, "create affine transform for labels", $cmd) ) {
	  error_out("$PM create_affine_transform: could not make transform: $cmd\n");
      }
  } 
  my $transform_path = "$result_transform_path_base\Affine.txt";
  # suffix mentioned on: http://picsl.upenn.edu/ANTS/ioants.php, and confirmed by what appears!
  # note: don't have any dots . in the middle of your base path, just one at the end: .nii
  
  if (!-e $transform_path && $ggo) {
      error_out("$PM create_affine_transform: did not find result xform: $transform_path");
  }
  print "** $PM create_multi_channel_affine_transform created $transform_path\n";
  return($transform_path);
}

# ------------------
sub create_two_channel_affine_transform {
# ------------------
  my ($current_T2W_path_id, $current_T1_path_id, $Hf) = @_;

  # --- find all the image files 
  $gcurrent_T2W_path = $Hf->get_value($current_T2W_path_id);
  $gcurrent_T1_path  = $Hf->get_value($current_T1_path_id);
  my @list;
  push @list, $gcurrent_T2W_path;
  push @list, $gcurrent_T1_path;

  my $whs_image_dir    = $Hf->get_value('dir-whs-images');
  $gwhs_T2W_path = "$whs_image_dir/whs_T2W_ln.nii";
  $gwhs_T1_path  = "$whs_image_dir/whs_T1_ln.nii";
  push @list, $gwhs_T2W_path;
  push @list, $gwhs_T1_path;

  foreach my $f (@list) {
    if (!-e $f) { error_out ("$PM register_affine: $f does not exist") };
  }

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $work_dir = $Hf->get_value('dir_work');
  my $result_transform_path_base = "$work_dir/T1_label_transform_";


########
#for mutual information metric use 

my $metric0 = "$gwhs_T1_path,$gcurrent_T1_path,0.7,32";
my $metric1 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.3,32";

#####
#for PR metric use
  #my $metric0 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.8,2";
  #my $metric1 = "$gwhs_T1_path,$gcurrent_T1_path,1,2:";
######


  my $other_options = "-i 0 --number-of-affine-iterations 3000x3000x3000x3000 --MI-option 32x32000 --use-Histogram-Matching --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001";
  if ( defined($test_mode)) {
      if( $test_mode == 1 ) {
	  $other_options = "-i 0 --number-of-affine-iterations 1x0x0x0 --MI-option 32x32000 --use-Histogram-Matching --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001"; 
      }
  }
  

 
#for mutual information metric use 
 my $cmd = "$ants_app_dir/ants 3 -m MI[$metric0] -m MI[$metric1] -o $result_transform_path_base $other_options";

#for PR use
 #my $cmd = "$ants_app_dir/ants 3 -m PR[$metric0] -m PR[$metric1] -o $result_transform_path_base $other_options";

  if ($DEBUG_GO) { 
  if (! execute($ggo, "create affine transform for labels", $cmd) ) {
    error_out("$PM create_affine_transform: could not make transform: $cmd\n");
  }
  } 
  my $transform_path = "$result_transform_path_base\Affine.txt";
  # suffix mentioned on: http://picsl.upenn.edu/ANTS/ioants.php, and confirmed by what appears!
  # note: don't have any dots . in the middle of your base path, just one at the end: .nii

  if (!-e $transform_path && $ggo) {
    error_out("$PM create_affine_transform: did not find result xform: $transform_path");
  }
  print "** $PM create_affine_transform created $transform_path\n";
  return($transform_path);
}

# ------------------
sub create_multi_channel_diff_syn_transform {
# ------------------
  my ($affine_xform, $syn_setting, $Hf) = @_;

  print("\n\n\t$PM stage 2/$PM_stages \"create_multi_channel_diff_syn_transform\" \n\n\n") if ($debug_val >= 35) ;

  my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
  my $atlas_images_dir = $Hf->get_value('dir-atlas-images');
  my $ants_app_dir     = $Hf->get_value('engine-app-ants-dir');
  my $work_dir         = $Hf->get_value('dir-work');

  my $metric           = $Hf->get_value('ANTS-diff-SyN-metric');
  my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1 = ${channel_array[0]};
  my $result_transform_path_base = "$work_dir/${channel1}_label_DIFF_SYN_transform_";

  #/////// define options for transform ////////// 
# build metrics, only using first two channels for now, i want to change that later. 
  my $metrics='';
  for my $ch_id (@channel_array[0,$nchannels-1]) {
      my $channel_option = $Hf->get_value("diff-SyN-${metric}-${ch_id}-weighting");
      if ( $channel_option eq 'NO_KEY' ) { error_out ("could not find metric diff-SyN-${metric}-${ch_id}-weighting "); }
      my $channel_path      = $Hf->get_value("${ch_id}-reg2-${atlas_id}-path");
      my $atlas_image_path  = "${atlas_images_dir}/${atlas_id}_${ch_id}.nii"; # $Hf->get_value();
      if ( ! -e $channel_path ) { # crap out on missing file
	  error_out ("$PM create_multi_channel_affine_transform: $channel_path does not exist<${ch_id}-reg2-${atlas_id}-path>");
      } else {
	  $metrics = $metrics . " -m ${metric}[${atlas_image_path},${channel_path},${channel_option}]"; 
      }
  }

# #for MI
#   my $metric0 = "$gwhs_T1_path,$gcurrent_T1_path,0.7,4"; 
#   my $metric1 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.3,4";
# #for PR
#  # my $metric0 = "$gcurrent_T1_path,$gwhs_T1_path,1,4"; # 1.6 is different
#  # my $metric1 = "$gcurrent_T2W_path,$gwhs_T2W_path,0.8,4";

  my $other_options ="";
  $other_options = "--number-of-affine-iterations 3000x3000x3000x3000 --MI-option 32x16000 --use-Histogram-Matching";

    if (defined $test_mode) {
	if ($test_mode == 1) {
	    $other_options = "--number-of-affine-iterations 1x0x0x0 --MI-option 32x16000 --use-Histogram-Matching";
	}
    }

   ###my $skull_mask   = $Hf->get_value('skull_norm_mask_path');  #### but we don't want to use this current mask for -x

  my $canon_image_dir    = $Hf->get_value('dir-atlas-images');
  my $ref_skull_mask   = "$canon_image_dir/ref_mask.nii"; # a canonical reference mask
  if (! -e $ref_skull_mask) {
    error_out ("$PM create_diff_syn_transfrom: Reference skull mask $ref_skull_mask does not exist for -x option") ;
  }

  my $my_options ="";
  $my_options= "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[3,0] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.8x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x3000 -t SyN[$syn_setting] -r Gauss[1,0.5] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";


  if (defined $test_mode) {
      if ($test_mode == 1) {
	  $my_options = "-i 1x0x0x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";
      }
  }

  #/////// define ants transform command including all options ///////
#  THIS IS CONTROLED ELSEWHRE NOW< SET THE ANTSDIFFSyNMETRIC VALUE at the start of main_seg_pipe_mc.pl
#   ##for MI
#   # my $cmd = "$ants_app_dir/ants 3 -m MI[$metric0] -m MI[$metric1] -o $result_transform_path_base $other_options $my_options";
#   ##for PR
#   #my $cmd = "$ants_app_dir/ants 3 -m PR[$metric0] -m PR[$metric1] -o $result_transform_path_base $other_options $my_options";

#   ##for CC
#    my $cmd = "$ants_app_dir/ants 3 -m CC[$metric0] -m CC[$metric1] -o $result_transform_path_base $other_options $my_options";


   my $cmd = "$ants_app_dir/ants 3 $metrics -o $result_transform_path_base $other_options $my_options";

  if ($DEBUG_GO) { 
  if (! execute($ggo, "create affine diff syn transform for labels 3/2012\n\n\n", $cmd) ) {
    error_out("$PM create_diff_syn_transform: could not make transform: $cmd\n");
  }
  } 

  my $transform_path = "$result_transform_path_base\Affine.txt"; # one of result files

  if (!-e $transform_path && $ggo) {
    error_out("$PM create_diff_syn_transform: did not find result xform: $transform_path");
  }
  print "** $PM create_diff_syn_transform created $transform_path, etc\n";

  my $affine_xform_base         = $result_transform_path_base . "Affine";
  my $diff_syn_xform_base         = $result_transform_path_base . "Warp";
  my $diff_syn_inverse_xform_base = $result_transform_path_base . "InverseWarp";
  my $ants_transform_prefix = $result_transform_path_base;
  return($affine_xform_base, $diff_syn_xform_base, $diff_syn_inverse_xform_base, $ants_transform_prefix);
}


# ------------------
sub create_diff_syn_transform {
# ------------------
  my ($affine_xform, $syn_setting, $Hf) = @_;

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');

  my $work_dir = $Hf->get_value('dir_work');
  my $result_transform_path_base = "$work_dir/T1_label_DIFF_SYN_transform_";

  #/////// define options for transform //////////

#for MI
  my $metric0 = "$gwhs_T1_path,$gcurrent_T1_path,0.7,4"; 
  my $metric1 = "$gwhs_T2W_path,$gcurrent_T2W_path,0.3,4";


#for PR
 # my $metric0 = "$gcurrent_T1_path,$gwhs_T1_path,1,4"; # 1.6 is different
 # my $metric1 = "$gcurrent_T2W_path,$gwhs_T2W_path,0.8,4";

  my $other_options ="";
  $other_options = "--number-of-affine-iterations 3000x3000x3000x3000 --MI-option 32x16000 --use-Histogram-Matching";

    if (defined $test_mode) {
	if ($test_mode == 1) {
	    $other_options = "--number-of-affine-iterations 1x0x0x0 --MI-option 32x16000 --use-Histogram-Matching";
	}
    }

   ###my $skull_mask   = $Hf->get_value('skull_norm_mask_path');  #### but we don't want to use this current mask for -x

  my $canon_image_dir    = $Hf->get_value('dir-atlas-images');
  my $ref_skull_mask   = "$canon_image_dir/ref_mask.nii"; # a canonical reference mask
  if (! -e $ref_skull_mask) {
    error_out ("$PM create_diff_syn_transfrom: Reference skull mask $ref_skull_mask does not exist for -x option") ;
  }

  my $my_options ="";
  $my_options= "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[3,0] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.8x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x3000 -t SyN[$syn_setting] -r Gauss[1,0.5] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.2x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform -x $ref_skull_mask --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";
  $my_options = "-i 3000x3000x3000x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";


  if (defined $test_mode) {
      if ($test_mode == 1) {
	  $my_options = "-i 1x0x0x0 -t SyN[$syn_setting] -r Gauss[1,0.05] --continue-affine true -a $affine_xform --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001";
      }
  }

  #/////// define ants transform command including all options ///////

  ##for MI
  # my $cmd = "$ants_app_dir/ants 3 -m MI[$metric0] -m MI[$metric1] -o $result_transform_path_base $other_options $my_options";
  ##for PR
  #my $cmd = "$ants_app_dir/ants 3 -m PR[$metric0] -m PR[$metric1] -o $result_transform_path_base $other_options $my_options";

  ##for CC
   my $cmd = "$ants_app_dir/ants 3 -m CC[$metric0] -m CC[$metric1] -o $result_transform_path_base $other_options $my_options";

  if ($DEBUG_GO) { 
  if (! execute($ggo, "create affine diff syn transform for labels 3/2012\n\n\n", $cmd) ) {
    error_out("$PM create_diff_syn_transform: could not make transform: $cmd\n");
  }
  } 

  my $transform_path = "$result_transform_path_base\Affine.txt"; # one of result files

  if (!-e $transform_path && $ggo) {
    error_out("$PM create_diff_syn_transform: did not find result xform: $transform_path");
  }
  print "** $PM create_diff_syn_transform created $transform_path, etc\n";

  my $affine_xform_base         = $result_transform_path_base . "Affine";
  my $diff_syn_xform_base         = $result_transform_path_base . "Warp";
  my $diff_syn_inverse_xform_base = $result_transform_path_base . "InverseWarp";
  my $ants_transform_prefix = $result_transform_path_base;
  return($affine_xform_base, $diff_syn_xform_base, $diff_syn_inverse_xform_base, $ants_transform_prefix);
}

# ------------------
sub warp_canonical_labels {
# ------------------
  my ($ants_transform_prefix, $Hf) = @_;
  print("\n\n\t$PM stage 3/$PM_stages \"warp_canonical_labels\" \n\n\n") if ($debug_val >= 35) ;
  # $ants_transform_prefix is the base part of all the xforms made by the prior diff syn step

  my $label_dir = $Hf->get_value('dir-atlas-labels');
  my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
  my $to_deform = $label_dir . "/${atlas_id}_labels.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_atlas_image: did not find canonical labels: $to_deform");
  }
  my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1 = ${channel_array[0]};

  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $result_dir = $Hf->get_value('dir-result');
  my $channel1_runno   = $Hf->get_value("${channel1}-runno");
  my $result_path_base = "$result_dir/${channel1}_labels_${channel1_runno}";
  my $result_path = "$result_path_base\.nii";
  #print ("result path $result_path_base, $T1_runno, $result_dir --------\n");

  my $warp_domain_path = $to_deform;

  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix";
  # gz change 1
 # my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix.gz";

 my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix.gz";
 print("warp_canonical_labeles: $cmd\n");
if ($DEBUG_GO) {
  if (! execute($ggo, "warp canonical labels", $cmd) ) {
    error_out("$PM warp_canonical_labels could not warp: $cmd\n");
  }
} 
  if (!-e $result_path) {
    error_out("$PM warp_canonical_labels: did not find result xform: $result_path");
  }






  return ($result_path);

}
# ------------------
sub warp_canonical_labels_old {
# ------------------
  my ($ants_transform_prefix, $Hf) = @_;
  # $ants_transform_prefix is the base part of all the xforms made by the prior diff syn step
print("in warp_canonical_labels\n\n\n");
  my $label_dir = $Hf->get_value('dir-atlas-labels');
  my $atlas_id         = $Hf->get_value('reg-target-atlas-id');
  my $to_deform = $label_dir . "/${atlas_id}_labels.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_atlas_image: did not find canonical labels: $to_deform");
  }


  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');
  my $result_dir = $Hf->get_value('dir_result');
  my $T1_runno   = $Hf->get_value('T1_runno');
  my $result_path_base = "$result_dir/T1_labels_$T1_runno";
  my $result_path = "$result_path_base\.nii";
  #print ("result path $result_path_base, $T1_runno, $result_dir --------\n");

  my $warp_domain_path = $to_deform;

  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix";
  # gz change 1
 # my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix.gz";

 my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN --ANTS-prefix $ants_transform_prefix.gz";
 print("warp_canonical_labeles: $cmd\n");
if ($DEBUG_GO) {
  if (! execute($ggo, "warp canonical labels", $cmd) ) {
    error_out("$PM warp_canonical_labels could not warp: $cmd\n");
  }
} 
  if (!-e $result_path) {
    error_out("$PM warp_canonical_labels: did not find result xform: $result_path");
  }






  return ($result_path);

}

# ------------------
sub warp_label_image {
# ------------------
 # my ($affine_xform, $warp_xform, $Hf) = @_;
  print("\n\n\t$PM stage 4/$PM_stages \"warp_label_image\" \n\n\n") if ($debug_val >= 35) ;
  my ($affine_xform, $inverse_warp_xform, $Hf) = @_;
  my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1 = ${channel_array[0]};
  my $label_dir = $Hf->get_value('dir-atlas-labels');
  my $to_deform = $label_dir . "/canon_labels_ln.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_atlas_image: did not find canonical labels: $to_deform");
  }

  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $result_dir = $Hf->get_value('dir-result');
  my $channel1_runno   = $Hf->get_value("${channel1}-runno");
  my $result_path_base = "$result_dir/${channel1}_labels_warp_${channel1_runno}";
  my $result_path = "$result_path_base\.nii";
  #print ("result path $result_path_base, $T1_runno, $result_dir --------\n");

  my $warp_domain_path = $to_deform;
 
  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN $warp_xform\.nii.gz $affine_xform\.txt";
  my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN  -i $affine_xform\.txt $inverse_warp_xform\.nii.gz";





  if (! execute($ggo, "warp_label_image", $cmd) ) {
    error_out("$PM warp_label_image could not warp: $cmd\n");
  }
 
 if (!-e $result_path) {
    error_out("$PM warp_canon_labels: did not find result xform: $result_path");
  }

  # in place convert to bytes
  my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
  if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
    error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
}

  return ($result_path);
}

# ------------------
sub warp_label_image_OLD {
# ------------------
 # my ($affine_xform, $warp_xform, $Hf) = @_;
 print("in warp_label_image\n\n\n");
  my ($affine_xform, $inverse_warp_xform, $Hf) = @_;
  my $label_dir = $Hf->get_value('dir-atlas-labels');
  my $to_deform = $label_dir . "/canon_labels_ln.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_atlas_image: did not find canonical labels: $to_deform");
  }

  my $ants_app_dir = $Hf->get_value('engine_app_ants_dir');
  my $result_dir = $Hf->get_value('dir_result');
  my $T1_runno   = $Hf->get_value('T1_runno');
  my $result_path_base = "$result_dir/T1_labels_warp_$T1_runno";
  my $result_path = "$result_path_base\.nii";
  #print ("result path $result_path_base, $T1_runno, $result_dir --------\n");

  my $warp_domain_path = $to_deform;
 
  #my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN $warp_xform\.nii.gz $affine_xform\.txt";
  my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path --use-NN  -i $affine_xform\.txt $inverse_warp_xform\.nii.gz";





  if (! execute($ggo, "warp_label_image", $cmd) ) {
    error_out("$PM warp_label_image could not warp: $cmd\n");
  }
 
 if (!-e $result_path) {
    error_out("$PM warp_canon_labels: did not find result xform: $result_path");
  }

  # in place convert to bytes
  my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
  if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
    error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
}

  return ($result_path);
}

# ------------------
sub warp_canonical_image { 
# ------------------
# results are for verification, save to working dir
  my ($affine_xform, $inverse_warp_xform, $Hf) = @_;
  print("\n\n\t$PM stage 5/$PM_stages \"warp_canonical_image\" \n\n\n") if ($debug_val >= 35) ;
  my $label_dir = $Hf->get_value('dir-atlas-images');
  my $atlas_id  = $Hf->get_value('reg-target-atlas-id');
  my @channel_array = split(',',$Hf->get_value('runno_ch_commalist'));
  my $channel1 = ${channel_array[0]};
  my $to_deform = $label_dir . "/${atlas_id}_${channel1}.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_canon_image: did not find canonical ${channel1} image: $to_deform");
  }
  my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
  my $channel1_runno   = $Hf->get_value("${channel1}-runno");
  my $warp_domain_path = $Hf->get_value("${channel1}-reg2-${atlas_id}-path");

  my $result_dir       = $Hf->get_value('dir-work');
  my $result_path_base = "$result_dir/${channel1}-${atlas_id}canon_warp2_${channel1}-${channel1_runno}\_reg2_${atlas_id}";
  my $result_path      = "$result_path_base\.nii";
  #print ("result path $result_path --------\n");
  #changed feb 26 because the warpsare saved as gz

  #alx feb 26
  #need to make labels byte, and save brain in ${atlas_id} space in results dir

 my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path -i $affine_xform\.txt $inverse_warp_xform\.nii.gz";
 my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";

  if (! execute($ggo, "warp_canonical_image", $cmd) ) {
    error_out("$PM warp_canonical_image could not warp: $cmd\n");
    }

  print "** $PM warp_canonical_image created $result_path\n";

if (!-e $result_path) {
    error_out("$PM warp_canon_labels: did not find result xform: $result_path");
  }

  # in place convert to bytes
  my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
  if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
    error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
}

}
# ------------------
sub warp_canonical_image_OLD { 
# ------------------
# results are for verification, save to working dir
  my ($affine_xform, $inverse_warp_xform, $Hf) = @_;

  my $label_dir = $Hf->get_value('dir-atlas-images');
  my $atlas_id  = $Hf->get_value('reg-target-atlas-id');
  my $to_deform = $label_dir . "/${atlas_id}_t1_ln.nii"; 
  if (! -e $to_deform) {
    error_out("$PM warp_canon_image: did not find canonical T1 image: $to_deform");
  }
  my $ants_app_dir     = $Hf->get_value('engine_app_ants_dir');
  my $T1_runno         = $Hf->get_value('T1_runno');
  my $warp_domain_path = $Hf->get_value('T1_reg2_${atlas_id}_path');

  my $result_dir       = $Hf->get_value('dir_work');
  my $result_path_base = "$result_dir/T1-${atlas_id}canon_warp2_T1-$T1_runno\_reg2_${atlas_id}";
  my $result_path      = "$result_path_base\.nii";
  #print ("result path $result_path --------\n");
  #changed feb 26 because the warpsare saved as gz

  #alx feb 26
  #need to make labels byte, and save brain in ${atlas_id} space in results dir

 my $cmd = "$ants_app_dir/WarpImageMultiTransform 3 $to_deform $result_path -R $warp_domain_path -i $affine_xform\.txt $inverse_warp_xform\.nii.gz";
 my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";

  if (! execute($ggo, "warp_canonical_image", $cmd) ) {
    error_out("$PM warp_canonical_image could not warp: $cmd\n");
    }

  print "** $PM warp_canonical_image created $result_path\n";

if (!-e $result_path) {
    error_out("$PM warp_canon_labels: did not find result xform: $result_path");
  }

  # in place convert to bytes
  my $cmd_byte = "$ants_app_dir/ImageMath 3 $result_path Byte $result_path";
  if (! execute($ggo, "in place convert label image to Byte", $cmd_byte) ) {
    error_out("$PM to_byte_label_image could not convert: $cmd_byte\n");
}

}

1;
