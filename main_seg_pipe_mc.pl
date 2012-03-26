#!/usr/local/pipeline-link/perl
# main_seg_pipe.pl
# created 2009/10/27 Sally Gewalt CIVM
#
# Main for segmentation pipeline.  
# This should only set up and check environment, 
# and then call another perl module to do real segmentation specific work.
#
# 2009/12/14 slg use "do bits" to toggle steps on and off.
# 2010/03/04 Alex iteration adjustments, ANTS update, more images in -results dir.
# 2010/11/02 updates for handling voxel size info from header 
# 2011/01/21 slg command line options to change default locations: dir_whs_labels_default, dir_whs_images_default

#package seg_pipe_mc;

use strict;
#require Exporter; 
require command_line_mc;
use Env qw(PIPELINE_SCRIPT_DIR);
use lib "$PIPELINE_SCRIPT_DIR/utility_pms";
require Headfile;
require pipeline_utilities;
require retrieve_archive_dir;
require label_brain_pipe;
use seg_pipe;
# these variables are defined in seg_pipe.pm
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $g_engine_ants_app_dir $g_engine_matlab_app);

#@EXPORT_OK = qw(PIPELINE_VERSION PIPELINE_NAME PIPELINE_DESC);

#my $g_engine_ants_app_dir,$g_engine_matlab_app;

# ---- main ------------

# --- required inputs
my ($runno_t1_set, $runno_t2w_set, $runno_t2star_set, 
    $subproject_source_runnos, $subproject_segmentation_result, 
    $flip_y, $flip_z, $pull_source_images, $extra_runno_suffix, $do_bit_mask, 
    $canon_labels_dir, $canon_images_dir)  
       = command_line_mc(@ARGV);
#, $test_mode
print 
("Command line info provided to main:
    $runno_t1_set, $runno_t2w_set, $runno_t2star_set, 
    subproj source: $subproject_source_runnos, subproj result: $subproject_segmentation_result, 
    pull=$pull_source_images, suffix=$extra_runno_suffix, flip_y=$flip_y, flip_z=$flip_z, domask=$do_bit_mask
    canon_labels_dir=$canon_labels_dir, canon_images_dir=$canon_images_dir\n") if 1; # always print this... kinda a wierd way to set that up.

my $nominal_runno = "xxx"; 
if ($extra_runno_suffix eq "--NONE") {
  $nominal_runno = $runno_t1_set;  # the "nominal runno" is used to id this segmentation
} else {
  print "Extra runno suffix info provided = $extra_runno_suffix\n";
  $nominal_runno = $runno_t1_set . $extra_runno_suffix; 
}

print "Base name that will be used to ID this segmentation: $nominal_runno\n";

set_environment($nominal_runno); # opens headfile, log file


## this might be unecessarily confusing. 
my $dirl = $canon_labels_dir;
if ($canon_labels_dir eq "DEFAULT") {
  $dirl = $HfResult->get_value('dir_whs_labels_default');
}
$HfResult->set_value('dir_whs_labels', $dirl);




my $diri = $canon_images_dir;
if ($canon_images_dir eq "DEFAULT") {
  $diri = $HfResult->get_value('dir_whs_images_default');
}
$HfResult->set_value('dir_whs_images', $diri);

log_info("  Using canonical labels dir = $dirl"); 
log_info("        canonical images dir = $diri"); 
if (! -e $dirl) { error_out ("unable to find canonical labels directory $dirl");  } 
if (! -e $diri) { error_out ("unable to find canonical images directory $diri");  } 

$HfResult->set_value('T1_runno'       , $runno_t1_set);
$HfResult->set_value('T2W_runno'      , $runno_t2w_set);
$HfResult->set_value('T2star_runno'   , $runno_t2star_set);
$HfResult->set_value('subproject_source_runnos', $subproject_source_runnos);
$HfResult->set_value('subproject'              , $subproject_segmentation_result);

#get specid from data headfiles?
$HfResult->set_value('specid'  , "NOT_HANDLED_YET");

# --- get source images
my $dest_dir = $HfResult->get_value('dir_input'); # for retrieved images
if (! -e $dest_dir) { mkdir $dest_dir; }
if (! -e $dest_dir) { error_out ("no dest dir! $dest_dir"); }
locate_data($pull_source_images, "T1"     , $HfResult);
locate_data($pull_source_images, "T2W"    , $HfResult);
locate_data($pull_source_images, "T2star" , $HfResult);

label_brain_pipe($do_bit_mask, $flip_y, $flip_z, $HfResult);  # --- pipeline work is here

# --- done
my $dest    = $HfResult->get_value('dir_result');
my $hf_path = $HfResult->get_value('headfile_dest_path');

# prepare (via a headfile?) for archive of results

log_info  ("Pipeline successful");
close_log ($HfResult); # also writes log to headfile;

$HfResult->write_headfile($hf_path);

print STDERR "results in $dest\n";
exit $GOODEXIT;

#--------subroutines-------
