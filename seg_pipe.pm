#!/usr/local/pipeline-link/perl
# global def for seg pipe, should be different for each seg pipe version, this one is for seg_pipe_mc.
package seg_pipe;
use warnings;
use strict;

# the begin block defines the variables to export
BEGIN { 
    use Exporter(); 
    @seg_pipe::ISA = qw(Exporter);
    @seg_pipe::Export = qw();
    @seg_pipe::EXPORT_OK = qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT); # $test_mode
}
# this use vars line telsl us which variables we're going to use in this module.
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT); #$test_mode
$PIPELINE_VERSION = "2012/03/21";
$PIPELINE_NAME = "Multiple contrast Brain Seg Pipeline With hopefully arbitrary channels"; 
$PIPELINE_DESC = "CIVM MRI mouse brain image segmentation using multiple contrasts";
$HfResult = "unset";
$GOODEXIT = 0;
$BADEXIT  = 1;
