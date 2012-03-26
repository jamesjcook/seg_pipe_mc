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
require retrieve_archived_data;
require label_brain_pipe;
use seg_pipe;
# these variables are defined in seg_pipe.pm
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT $g_engine_ants_app_dir $g_engine_matlab_app);
my $debug_val=10;
#@EXPORT_OK = qw(PIPELINE_VERSION PIPELINE_NAME PIPELINE_DESC);

#my $g_engine_ants_app_dir,$g_engine_matlab_app;

# ---- main ------------

# pull inputs using the command_line_mc input parser.
my $arg_hash_ref = command_line_mc(@ARGV);
print "command_line_mc return val: $arg_hash_ref\n" if ($debug_val >=45);
my %arghash=%{$arg_hash_ref};
# foreach my $k (keys %arghash) {
#     print "$k: $arghash{$k}\n";
# }
my @runno_array                                                 = split(',',$arghash{runnolist});
my @channel_array                                               = split(',',$arghash{channel_order});
my ($subproject_source_runnos, $subproject_segmentation_result) = split( ',',$arghash{projlist});
my $flip_y = $arghash{flip_y}; 
my $flip_z = $arghash{flip_z};
my $pull_source_images = $arghash{data_pull};
my $extra_runno_suffix = $arghash{extra_runno_suffix};
my $do_bit_mask = $arghash{bit_mask};
my $atlas_labels_dir = $arghash{atlas_labels_dir};
my $atlas_images_dir = $arghash{atlas_images_dir};
my $cmd_line = $arghash{cmd_line};


###
# process the input params abit, print directly after
###
my $nominal_runno = "xxx"; 
if ($extra_runno_suffix eq "--NONE") {
#  $nominal_runno = $runno_channel1_set;  # the "nominal runno" is used to id this segmentation
  $nominal_runno = $runno_array[0];  # the "nominal runno" is used to id this segmentation
} else {
  print "Extra runno suffix info provided = $extra_runno_suffix\n";
  $nominal_runno = $runno_array[0] . $extra_runno_suffix; 
}
set_environment($nominal_runno); # opens headfile, log file
if ($atlas_labels_dir eq "DEFAULT") {
  $atlas_labels_dir = $HfResult->get_value('dir_whs_labels_default');
}
log_info("  Using canonical labels dir = $atlas_labels_dir"); 
if (! -e $atlas_labels_dir) { error_out ("unable to find canonical labels directory $atlas_labels_dir");  } 
$HfResult->set_value('dir_whs_labels', $atlas_labels_dir);
if ($atlas_images_dir eq "DEFAULT") {
  $atlas_images_dir = $HfResult->get_value('dir_whs_images_default');
}
$HfResult->set_value('dir_whs_images', $atlas_images_dir);
log_info("        canonical images dir = $atlas_images_dir"); 
if (! -e $atlas_images_dir) { error_out ("unable to find canonical images directory $atlas_images_dir");  } 


print 
("Command line info provided to main:
    raw opts:  $cmd_line
    ".join(',',@channel_array).",
    ".join(',',@runno_array).",
    subproj source: $subproject_source_runnos, 
    subproj result: $subproject_segmentation_result, 
    pull=$pull_source_images, flip_y=$flip_y, flip_z=$flip_z, 
    suffix=$extra_runno_suffix 
    domask=$do_bit_mask
    atlas_labels_dir=$atlas_labels_dir
    atlas_images_dir=$atlas_images_dir
    Base name that will be used to ID this segmentation: $nominal_runno\n") if ( $debug_val >= 5); # print this most of the time, should modify verbosity flag.

#print "Base name that will be used to ID this segmentation: $nominal_runno\n";

$HfResult->set_value('runno_channels_sid',join(','@channel_array));
$HfResult->set_value('runno_channels',join(',',@runno_array));
$HfResult->set_value('subproject_source_runnos', $subproject_source_runnos);
$HfResult->set_value('subproject'              , $subproject_segmentation_result);
#get specid from data headfiles?
$HfResult->set_value('specid'  , "NOT_HANDLED_YET");
# --- set runno info in HfResult
my $i;
for($i=0;$i<=$#runno_array;$i++) {
    print ("inserting ${channel_array[$i]} info into Hfesult\n") if ($debug_val >=5);
    $HfResult->set_value("${channel_array[$i]}_runno", $runno_array[$i]);
}
# --- get source images, genericified for arbitrary channels
my $dest_dir = $HfResult->get_value('dir_input'); # for retrieved images
if (! -e $dest_dir) { mkdir $dest_dir; }
if (! -e $dest_dir) { error_out ("no dest dir! $dest_dir"); }
#for my $rid split(',',$channel_order) {
for($i=0;$i<=$#channel_array;$i++) {
    print("retrieving archive data for channel ${channel_array[$i]}\n");
    locate_data($pull_source_images, "${channel_array[$i]}" , $HfResult);
}
#locate_data($pull_source_images, "T1"     , $HfResult);
#locate_data($pull_source_images, "T2W"    , $HfResult);
#locate_data($pull_source_images, "T2star" , $HfResult);

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
