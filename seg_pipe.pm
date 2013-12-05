#!/usr/local/pipeline-link/perl
# seg_pipe.pm
# global def for seg pipe, should be different for each seg pipe version, this one is for seg_pipe_mc.
# contains very specific funcitons, ... practially a class deffinition for the 3 functions, 
#  set_environment          sets up basic directory's we'll work out of
#  get_ants_metric_opts     loads ants metric file into a hf with keys for each item
#  get_engine_dependencies  loads engine installation settings
#
# package seg_pipe; these little packages dont like this line, not sure why, it causes a failure 
use warnings;
use strict;

# the begin block defines the variables to export
BEGIN { 
    use Exporter(); 
    @seg_pipe::ISA = qw(Exporter);
#    @seg_pipe::Export = qw();
    @seg_pipe::EXPORT_OK = qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT ); # $test_mode
}
# this use vars line telsl us which variables we're going to use in this module.
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT ); #$test_mode
$PIPELINE_VERSION = "2013/07/30";
$PIPELINE_NAME = "Multiple contrast Brain Seg Pipeline With hopefully arbitrary channels"; 
$PIPELINE_DESC = "CIVM MRI mouse brain image segmentation using multiple contrasts";
$HfResult = "unset";
$GOODEXIT = 0;
$BADEXIT  = 1;
my $debug_val = 5;
my $g_engine_ants_app_dir;
my $g_engine_matlab_app;
my $g_engine_matlab_opts;
my $g_engine_fsl_dir;
my $g_engine_name;

# ------------------
sub set_environment {
# ------------------
# gets engine vars using the get_engine_dep script and stores in new headfile $HfResult, 
# HfResult is a global, i dont think i like that convention, better to play pass the hf ref i'd say.
# to support this HFresult i've made the global world global for these scripts, why go back and forth between conventions...
# 
# this is just to make main_seg_pipe easier to read.
  my ($runno) = @_;
  print ("runno=$runno\n") if ($debug_val>=35);
  my ($std_input_dir, $std_work_dir, $std_result_dir, $std_headfile, $std_whs_images_dir, $std_whs_labels_dir, $engine_hostname) =
      get_engine_dependencies($runno);

  # --- open log
  open_log($std_result_dir);
  log_info ("Segmentation pipeline name: $PIPELINE_NAME"); 
  log_info ("Segmentation pipeline desc: $PIPELINE_DESC"); 
  log_info ("Segmentation pipeline version: $PIPELINE_VERSION"); 

  # --- open headfile for results
  $HfResult = new Headfile ('rw', $std_headfile); # there is no file by this name yet, so can't check

  $HfResult->set_value('headfile-dest-path', $std_headfile);
  $HfResult->set_value('dir-input' , $std_input_dir);
  $HfResult->set_value('dir-result', $std_result_dir);
  $HfResult->set_value('dir-work'  , $std_work_dir);
  $HfResult->set_value('dir-whs-labels-default', $std_whs_labels_dir);
  $HfResult->set_value('dir-whs-images-default', $std_whs_images_dir);

  $HfResult->set_value('engine-app-matlab'       , $g_engine_matlab_app);
  $HfResult->set_value('engine-app-matlab-opts'  , $g_engine_matlab_opts);
  $HfResult->set_value('engine-app-ants-dir'     , $g_engine_ants_app_dir);
  $HfResult->set_value('engine-app-fsl-dir'      , $g_engine_fsl_dir);
  $HfResult->set_value('engine-computer-name'    , $engine_hostname);
  
}

# ------------------
sub get_ants_metric_opts {
# ------------------
  use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME BIGGUS_DISKUS WKS_SETTINGS);
  if (! defined($PIPELINE_HOSTNAME)) { error_out ("Environment variable PIPELINE_HOSTNAME must be set."); }
  if (! defined($PIPELINE_HOME)) { error_out ("Environment variable PIPELINE_HOME must be set."); }
  if (! defined($BIGGUS_DISKUS)) { error_out ("Environment variable BIGGUS_DISKUS must be set."); }
  if (!-d $BIGGUS_DISKUS)      { error_out ("unable to find $BIGGUS_DISKUS"); }
  if (!-w $BIGGUS_DISKUS)      { error_out ("unable to write to $BIGGUS_DISKUS"); }
  if (!-d $PIPELINE_HOME)      { error_out ("unable to find $PIPELINE_HOME"); }

  my $ants_metrics_dir = "$WKS_SETTINGS/ants";
  if (! -e $ants_metrics_dir) {
     error_out ("$ants_metrics_dir does not exist.");
  }
  my $ants_metric_file  = "ants_metric_options";
  my $ants_metrics_path = "$ants_metrics_dir/$ants_metric_file";

  my $Ants_metrics = new Headfile ('ro', $ants_metrics_path);
  if (! $Ants_metrics->check()) {
    error_out("Unable to open ants metric constants file $ants_metrics_path\n");
  }
  if (! $Ants_metrics->read_headfile) {
     error_out("Unable to read ants metric constants from headfile form file $ants_metrics_path\n");
  }
  return $Ants_metrics;
#my $ants_metrics = new Headfile ('ro', $ants_metrics_path);
}

# ------------------
sub get_engine_dependencies {
# ------------------
# finds and reads engine dependency file 
  my ($runno) = @_;


  use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME BIGGUS_DISKUS WKS_SETTINGS WORKSTATION_HOSTNAME);
  
  if (! defined($BIGGUS_DISKUS)) { error_out ("Environment variable BIGGUS_DISKUS must be set."); }
  if (!-d $BIGGUS_DISKUS)        { error_out ("unable to find $BIGGUS_DISKUS"); }
  if (!-w $BIGGUS_DISKUS)        { error_out ("unable to write to $BIGGUS_DISKUS"); }
  if  ( ! defined($WORKSTATION_HOSTNAME)) { 
      print("WARNING: obsolete variable PIPELINE_HOSTNAME used.\n");
  } else { 
      $PIPELINE_HOSTNAME=$WORKSTATION_HOSTNAME;
  }
  my $engine_constants_dir ;
  if ( ! defined($WKS_SETTINGS) ) { 
      print("WARNING: obsolete variable PIPELINE_HOME used to find dependenceis\n");
      $engine_constants_dir="$PIPELINE_HOME/dependencies";
  } else { 
      $PIPELINE_HOME=$WKS_SETTINGS;
      $engine_constants_dir="$PIPELINE_HOME/engine_deps";
  }
    
  if (! defined($PIPELINE_HOSTNAME)) { error_out ("Environment variable WORKSTATION_HOSTNAME must be set."); }
  if (! defined($PIPELINE_HOME)) { error_out ("Environment variable WKS_SETTINGS must be set."); }
  if (!-d $PIPELINE_HOME)        { error_out ("unable to find $PIPELINE_HOME"); }
  if (! -d $engine_constants_dir) {
      error_out ("$engine_constants_dir does not exist.");
  }
  my $engine_file =join("_","engine","$PIPELINE_HOSTNAME","dependencies"); 
  my $engine_constants_path = "$engine_constants_dir/".$engine_file;
  if ( ! -f $engine_constants_path ) { 
      $engine_file=join("_","engine","$PIPELINE_HOSTNAME","pipeline_dependencies");
      $engine_constants_path = "$engine_constants_dir/".$engine_file;
      print("WARNING: OBSOLETE SETTINGS FILE USED, $engine_file\n")
  }
  
  my $Engine_constants = new Headfile ('ro', $engine_constants_path);
  if (! $Engine_constants->check()) {
    error_out("Unable to open engine constants file $engine_constants_path\n");
  }
  if (! $Engine_constants->read_headfile) {
     error_out("Unable to read engine constants from headfile form file $engine_constants_path\n");
  }
  $g_engine_matlab_app   = $Engine_constants->get_value('engine_app_matlab');
  $g_engine_matlab_opts  = $Engine_constants->get_value('engine_app_matlab_opts');
  print("engine file: $engine_file\n");
  print("mat opts : $g_engine_matlab_opts\n");
  $g_engine_ants_app_dir = $Engine_constants->get_value('engine_app_ants_dir');
  $g_engine_fsl_dir      = $Engine_constants->get_value('engine_app_fsl_dir');
  if (! -e $g_engine_matlab_app)   { error_out ("unable to find $g_engine_matlab_app");} 
  if (! defined $g_engine_matlab_opts)   { error_out ("unable to find g_engine_matlab_opts");} 
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
      $engine_whs_images_dir, $engine_whs_labels_dir, $PIPELINE_HOSTNAME);
}

1;

