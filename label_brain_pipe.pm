#!/usr/local/pipeline-link/perl

# label_brain_pipe.pm 

# created 2009/10/28 Sally Gewalt CIVM
#
# 2010/03/03 save_favorite_intermediates () to move from work to results dir.
# 2010/11/02 slg add flip_z
# nifti conversion knows about voxel size
#

#package label_brain_pipe; # causes trouble when we label this as label_brain_pipe, not sure why, could be that its a same name as function problem.
my $VERSION = "2010/03/03";
my $NAME = "Alex Badea Brain Segmentation Method";
my $DESC = "warps WHS labels";
my $PM = "label_brain_pipe.pm";

use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
require Headfile;
require skull_strip_all;
require register_all_to_T1;
require create_labels;
require convert_all_to_nifti;
require registration;
require image_math;
require register_all_to_whs;

# fancy begin block and use vars to define a world global variable, available to any module used at the same time as this one
BEGIN {
    use Exporter; 
    @label_brain_pipe::ISA = qw(Exporter);
#    @label_brain_pipe::Export = qw();
    @label_brain_pipe::EXPORT_OK = qw($test_mode);
}
use vars qw($test_mode);
#use lib "$PIPELINE_SCRIPT_DIR/utility_pms";
#require pipeline_utilities;

# ------------------
sub label_brain_pipe {
# ------------------
  my ($do_bits, $flip_y, $flip_z, $Hf_out) = @_;
  log_info ("$PM name: $NAME");
  log_info ("$PM desc: $DESC");
  log_info ("$PM version: $VERSION");

  my ($nifti, $register, $strip, $whs, $label) =  split('', $do_bits);

  log_info ("pipeline step do bits: nifti:$nifti, register:$register, strip:$strip, whs:$whs, label:$label\n");

  convert_all_to_nifti($nifti, $flip_y, $flip_z, $Hf_out); 

  register_all_to_T1  ($register, $Hf_out);

  skull_strip_all($strip, $Hf_out);

  register_all_to_whs($whs, $Hf_out);

  create_labels($label, $Hf_out);

  #save_favorite_intermediates ($whs, $Hf_out);
  save_favorite_intermediates (1, $Hf_out);
}

# ------------------
sub save_favorite_intermediates {
# ------------------
# Save selected intermediate results into the results directory.
# NOTE: some other results may be stored by the step subroutine itself (e.g. labels)
  my ($do_save, $Hf_out) = @_;

  my $ants_app_dir  = $Hf_out->get_value('engine_app_ants_dir');

  # ---- copy the whs aligned images for posterity to the result dir
  # do not move them in case we are debugging and need intermediate results in work dir

  log_info ("$PM copying whs aligned images to results dir");
  my $results_dir = $Hf_out->get_value("dir_result");

  my @list =();
  my @list2 =();
  push @list, $Hf_out->get_value("T2star_reg2_whs_path");
  push @list, $Hf_out->get_value("T2W_reg2_whs_path");
  push @list, $Hf_out->get_value("T1_reg2_whs_path");
  push @list2, $Hf_out->get_value("T2star_reg2_whs_file");
  push @list2, $Hf_out->get_value("T2W_reg2_whs_file");
  push @list2, $Hf_out->get_value("T1_reg2_whs_file");

  foreach my $p (@list) {   # path to 32 bit whs result file
    my $cmd = "cp $p $results_dir";
    my $ok = execute($do_save, "copy whs result image set", $cmd);
    if (! $ok) {
      error_out("Could not copy whs images: $cmd\n");
    }

    # -- also convert  whs images into Byte format for easier QA in Avizo, and move to results:
    my $whs_file = shift @list2;
    my $byte_path = "$results_dir/$whs_file\_Byte\.nii"; 
    my $cmd2 = "$ants_app_dir/ImageMath 3 $byte_path Byte $p";  # output first
    my $ok = execute($do_save, "convert whs image set to byte", $cmd2);
    if (! $ok) {
        error_out("Could not convert whs to byte: $cmd2\n");
     }
  }

}

1;
