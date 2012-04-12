#!/usr/local/pipeline-link/perl
# label_brain_pipe.pm 
# given a headfileformed by the right pipeline main script will niftify inputs, 
# and create labels in the inputs space/orientation, will also save some results 
# in an archive ready dirctory.
# 
# CHANGE LOG
# 2012/04/02 james cook, started adding coilbias correction to help support in-vivo scans
# 2012/03/28 james cook, did pile of modifications for using arbitrary atlas and channels
#            have also modified the functions this depends on, work in progress.
# 2010/11/02 slg add flip_z, nifti conversion knows about voxel size
# 2010/03/03 save_favorite_intermediates () to move from work to results dir.
# created 2009/10/28 Sally Gewalt CIVM
 


#package label_brain_pipe; # causes trouble when we label this as label_brain_pipe, not sure why, could be that its a same name as function problem.
my $VERSION = "2012/03/28";
my $NAME = "Alex Badea Brain Segmentation Method";
my $DESC = "warps atlas labels";
my $PM = "label_brain_pipe.pm";

use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
require Headfile;
require image_math;
require registration;

require convert_all_to_nifti;
require apply_coil_bias_to_all;
require apply_noise_reduction_to_all;
require register_all_to_channel1;
require skull_strip_all;
require register_all_to_atlas;
require create_labels;
require calculate_volumes;

my $debug_val = 5;


# fancy begin block and use vars to define a world global variable, available to any module used at the same time as this one
BEGIN {
    use Exporter; 
    @label_brain_pipe::ISA = qw(Exporter);
#    @label_brain_pipe::Export = qw();
    @label_brain_pipe::EXPORT_OK = qw($test_mode);
}
#use vars qw($test_mode); # we dont even use this here, only used in the registration steps
#use lib "$PIPELINE_SCRIPT_DIR/utility_pms";
#require pipeline_utilities;

# ------------------
sub label_brain_pipe {
# ------------------
# $flip_y, $flip_z,
  my ($do_bits, $Hf_out) = @_; # flip_y and flipy_z should be put in the headfile and pulled ou there to match form with the other functions
  log_info ("$PM name: $NAME");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");
  my ($nifti, $noise, $bias, $register, $strip, $atlas, $label, $volumes) =  split('', $do_bits);
  log_info ("pipeline step do bits: nifti:$nifti, noise:$noise, bias:$bias, register:$register, strip:$strip, atlasreg:$atlas, label:$label,volumes:$volumes\n");
#step 1
  convert_all_to_nifti($nifti, $Hf_out);  
  if ($Hf_out->get_value("noise_reduction") eq '--NONE' ) {
      print("$PM Not noise correcting\n") if ($debug_val>=35);
  } else {
#step2
      apply_noise_reduction_to_all($noise,$Hf_out);
  }
#  sleep(15);
  if ($Hf_out->get_value("coil_bias") == 1 ) {
#step3
      apply_coil_bias_to_all($bias, $Hf_out); 
  }
#step4
  register_all_to_channel1($register, $Hf_out);
#step5
  skull_strip_all($strip, $Hf_out);
#step6
  register_all_to_atlas($atlas, $Hf_out);
#step7
  create_labels($label, $Hf_out);
#step8
  calculate_volumes($volumes, $Hf_out);
#put in results
  save_favorite_intermediates (1, $Hf_out);
  return;

}

# ------------------
sub save_favorite_intermediates {
# ------------------
# Save selected intermediate results into the results directory.
# NOTE: some other results may be stored by the step subroutine itself (e.g. labels)
  my ($do_save, $Hf_out) = @_;

  my $ants_app_dir  = $Hf_out->get_value('engine-app-ants-dir');
  my $atlas_id  = $Hf_out->get_value('reg-target-atlas-id');
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));

  # ---- copy the atlas aligned images for posterity to the result dir
  # do not move them in case we are debugging and need intermediate results in work dir

  log_info ("$PM copying atlas aligned images to results dir");
  my $results_dir = $Hf_out->get_value("dir-result");

  my @list =();
  my @list2 =();
  for my $ch_id (@channel_array) {
      push @list, $Hf_out->get_value("${ch_id}-reg2-${atlas_id}-path");
      push @list2, $Hf_out->get_value("${ch_id}-reg2-${atlas_id}-file");
  }

#   push @list, $Hf_out->get_value("T2star-reg2-${atlas_id}-path");
#   push @list, $Hf_out->get_value("T2W-reg2-${atlas_id}-path");
#   push @list, $Hf_out->get_value("T1-reg2-${atlas_id}-path");
#   push @list2, $Hf_out->get_value("T2star-reg2-${atlas_id}-file");
#   push @list2, $Hf_out->get_value("T2W-reg2-${atlas_id}-file");
#   push @list2, $Hf_out->get_value("T1-reg2-${atlas_id}-file");

  foreach my $p (@list) {   # path to 32 bit atlas result file
    my $cmd = "cp $p $results_dir";
    my $ok = execute($do_save, "copy ${atlas_id} result image set", $cmd);
    if (! $ok) {
      error_out("Could not copy ${atlas_id} images: $cmd\n");
    }

    # -- also convert  atlas images into Byte format for easier QA in Avizo, and move to results:
    my $atlas_file = shift @list2;
    my $byte_path = "$results_dir/${atlas_file}_Byte\.nii"; 
    my $cmd2 = "$ants_app_dir/ImageMath 3 $byte_path Byte $p";  # output first
    my $ok = execute($do_save, "convert ${atlas_id} image set to byte", $cmd2);
    if (! $ok) {
        error_out("Could not convert ${atlas_id} to byte: $cmd2\n");
     }
  }

}

1;
