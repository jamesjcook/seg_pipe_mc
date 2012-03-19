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

my $PIPELINE_VERSION = "2011/01/21";
my $PIPELINE_NAME = "Multiple contrast Brain Seg Pipeline"; 
my $PIPELINE_DESC = "CIVM MRI mouse brain image segmentation using multiple contrasts";

my $HfResult = "unset";

use strict;
require command_line;
use Env qw(PIPELINE_SCRIPT_DIR);
use lib "$PIPELINE_SCRIPT_DIR/utility_pms";
require Headfile;
require pipeline_utilities;
require retrieve_archive_dir;
require label_brain_pipe;

my $GOODEXIT = 0;
my $BADEXIT  = 1;

my $g_engine_matlab_app;
my $g_engine_ants_app_dir;

# ---- main ------------

# --- required inputs
my ($runno_t1_set, $runno_t2w_set, $runno_t2star_set, 
    $subproject_source_runnos, $subproject_segmentation_result, 
    $flip_y, $flip_z, $pull_source_images, $extra_runno_suffix, $do_bit_mask, 
    $canon_labels_dir, $canon_images_dir) 
       = command_line(@ARGV);

print 
("Command line info provided to main:
    $runno_t1_set, $runno_t2w_set, $runno_t2star_set, 
    subproj source: $subproject_source_runnos, subproj result: $subproject_segmentation_result, 
    pull=$pull_source_images, suffix=$extra_runno_suffix, flip_y=$flip_y, flip_z=$flip_z, domask=$do_bit_mask
    canon_labels_dir=$canon_labels_dir, canon_images_dir=$canon_images_dir\n") if 1; # always print this... kinda a wierd way to set that up.

my $nominal_runno = "xxx"; 
if ($extra_runno_suffix eq "--NONE") {
  $nominal_runno = $runno_t1_set;  # the "nominal runno" is used to id this segmentation
}
else {
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

# ------------------
sub locate_data {
# ------------------
  # Retrieve a source image set from image subproject on atlasdb
  # Also sets the dest dir for each set in the headfile so
  # you need to call this even if $pull_images is false.

  my ($pull_images, $set, $Hf)=@_;
  # $set should be t1, t2 or t2star (current CIVM MR SOP for seg)

  my $dest       = $Hf->get_value('dir_input');
  my $subproject = $Hf->get_value('subproject_source_runnos');

  my $runno_flavor = "$set\_runno";
  my $runno = $Hf->get_value($runno_flavor);
  if ($runno eq "NO_KEY") { error_out ("ouch $runno $runno_flavor\n"); }
  my $ret_set_dir = retrieve_archive_dir($pull_images, $subproject, $runno, $dest);  
  $Hf->set_value("$set\_dir", $ret_set_dir);

  my $first_image_name = first_image_name($ret_set_dir, $runno);
  my ($image_name, $digits, $suffix) = split '\.', $first_image_name;
  $Hf->set_value("$set\_image_basename"     , $image_name);
  $Hf->set_value("$set\_image_padded_digits", $digits);
  $Hf->set_value("$set\_image_suffix"       , $suffix);
}

# ------------------
sub set_environment {
# ------------------
# gets engine vars using the get_engine_dep script and stores in new headfile $HfResult, 
# HfResult is a global, i dont think i like that convention, better to play pass the hf ref i'd say.
# 
  my ($runno) = @_;
  #print ("runno=$runno\n");
  my ($std_input_dir, $std_work_dir, $std_result_dir, $std_headfile, $std_whs_images_dir, $std_whs_labels_dir) = get_engine_dependencies($runno);

  # --- open log
  open_log($std_result_dir);
  log_info ("Segmentation pipeline name: $PIPELINE_NAME"); 
  log_info ("Segmentation pipeline desc: $PIPELINE_DESC"); 
  log_info ("Segmentation pipeline version: $PIPELINE_VERSION"); 

  # --- open headfile for results
  $HfResult = new Headfile ('rw', $std_headfile); # there is no file by this name yet, so can't check

  $HfResult->set_value('headfile_dest_path', $std_headfile);
  $HfResult->set_value('dir_input' , $std_input_dir);
  $HfResult->set_value('dir_result', $std_result_dir);
  $HfResult->set_value('dir_work'  , $std_work_dir);
  $HfResult->set_value('dir_whs_labels_default', $std_whs_labels_dir);
  $HfResult->set_value('dir_whs_images_default', $std_whs_images_dir);

  $HfResult->set_value('engine_app_matlab'       , $g_engine_matlab_app);
  $HfResult->set_value('engine_app_ants_dir'     , $g_engine_ants_app_dir);
}

# ------------------
sub get_engine_dependencies {
# ------------------
# finds and reads engine dependency file 
  my ($runno) = @_;
  use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME BIGGUS_DISKUS);
  if (! defined($PIPELINE_HOSTNAME)) { error_out ("Environment variable PIPELINE_HOSTNAME must be set."); }
  if (! defined($PIPELINE_HOME)) { error_out ("Environment variable PIPELINE_HOME must be set."); }
  if (! defined($BIGGUS_DISKUS)) { error_out ("Environment variable BIGGUS_DISKUS must be set."); }
  if (!-d $BIGGUS_DISKUS)      { error_out ("unable to find $BIGGUS_DISKUS"); }
  if (!-w $BIGGUS_DISKUS)      { error_out ("unable to write to $BIGGUS_DISKUS"); }
  if (!-d $PIPELINE_HOME)      { error_out ("unable to find $PIPELINE_HOME"); }

  my $engine_constants_dir = "$PIPELINE_HOME/dependencies";
  if (! -e $engine_constants_dir) {
     error_out ("$engine_constants_dir does not exist.");
  }
  my $engine_file = join("_","engine","$PIPELINE_HOSTNAME","pipeline_dependencies");
  my $engine_constants_path = "$engine_constants_dir/$engine_file";

  my $Engine_constants = new Headfile ('ro', $engine_constants_path);
  if (! $Engine_constants->check()) {
    error_out("Unable to open engine constants file $engine_constants_path\n");
  }
  if (! $Engine_constants->read_headfile) {
     error_out("Unable to read engine constants from headfile form file $engine_constants_path\n");
  }
  $g_engine_matlab_app = $Engine_constants->get_value('engine_app_matlab');
  $g_engine_ants_app_dir   = $Engine_constants->get_value('engine_app_ants_dir');
  if (! -e $g_engine_matlab_app)   { error_out ("unable to find $g_engine_matlab_app");} 
  if (! -e $g_engine_ants_app_dir) { error_out ("unable to find $g_engine_ants_app_dir");  } 

  my $engine_whs_labels_dir  = $Engine_constants->get_value('engine_waxholm_labels_dir');
  my $engine_whs_images_dir  = $Engine_constants->get_value('engine_waxholm_canonical_images_dir');
  if (! -e $engine_whs_labels_dir) { error_out ("unable to find standard whs directory $engine_whs_labels_dir");  } 
  if (! -e $engine_whs_images_dir) { error_out ("unable to find standard whs directory $engine_whs_images_dir");  } 

  my $fix = "Labels"; # sets postfix
  my $conventional_input_dir = "$BIGGUS_DISKUS/$runno$fix\-inputs"; # may not exist yet
  
  my $conventional_work_dir  = "$BIGGUS_DISKUS/$runno$fix\-work";
  if (! -e $conventional_work_dir) {
    mkdir $conventional_work_dir;
  }
  my $conventional_result_dir  = "$BIGGUS_DISKUS/$runno$fix\-results";
  if (! -e $conventional_result_dir) {
    mkdir $conventional_result_dir;
  }


  my $conventional_headfile = "$conventional_result_dir/$runno$fix\.headfile"; 
  return($conventional_input_dir, $conventional_work_dir, $conventional_result_dir, $conventional_headfile, 
      $engine_whs_images_dir, $engine_whs_labels_dir);
}

# ------------------
sub usage_message {
# ------------------
  my ($msg) = @_;
  print STDERR "$msg\n";
  print STDERR "$PIPELINE_NAME
  $PIPELINE_DESC
usage:
  seg_pipe \<options\> runno_T1  runno_T2W  runno_T2star  subproj_inputs  subproj_result
    required args:
     runno_T1_set     : runno of the input T1 image set (must be available in the archive). 
     runno_T2W_set    : runno of the input T2W image set.
     runno_T2star_set : runno of the input T2star image set. 
     subproj_inputs   : the subproject the input runnos were collected for (and archived under). 
     subproj_result   : the subproject associated with and for storing (image, label) results of this program. 
   options:
     -e         : if used, the runnos will not be copied from the archive (they must be present).
     -y         : if used, input images will be flipped in y before use
     -z         : if used, input images will be flipped in z before use
     -s  suffix : optional suffix on default result runno (doc test params?). Must be ok for filename embed. 
     -l  dir    : change canonical labels directory from default
     -i  dir    : change canonical images directory from default
     -b do_bit_mask : default: 11111 to do all 5 steps; 01111 to skip first step, etc. Steps: nifti, register, strip, whs, label.
                      Skipping is only from gross testing of commands created and not guaranteed to produce results.

version: $PIPELINE_VERSION 

"; 
  exit (! $GOODEXIT);
}

# -------------
sub error_out
# -------------
{
  my ($msg) = @_;
  print STDERR "\n<~Pipeline failed.\n";
  print STDERR "  Failure cause: ", $msg,"\n";
  print STDERR "  Please note the cause.\n";

  close_log_on_error($msg);
  if ($HfResult ne "unset") {
    my $hf_path = $HfResult->get_value('headfile_dest_path');
    $HfResult->write_headfile($hf_path);
    $HfResult = "unset";
  }
  exit $BADEXIT;
}

