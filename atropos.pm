#!/usr/local/pipeline-link/perl  
# atropos.pm
# Created 18 July, 2014 -- BJ Anderson CIVM (his first, so expect many naive and buggy behaviors)
#
#

my $PM = "atropos.pm";
my $VERSION = "2014/07/21";
my $NAME = "Atropos 3-class segmentation";
my $DESC = "ants";
my $ggo = 1;
my $debug_val = 5;
use strict;
use Env;
use lib split(':',$RADISH_PERL_LIB);
require Headfile;
use Getopt::Long qw(GetOptionsFromString);
Getopt::Long::Configure ("bundling");

our %defaults = (
    "d" => 3,
    "i" => "KMeans[3, 0.01x0.02x0.1]",
    "c" => "[5,0.001]",
    "k" => "Gaussian",

    "m" => "[ 0.1,1x1x1]",
    "e" => 0,

    "u" => 1,
    "p" => "Socrates[1]",
);

our %alternative = (
    "d" => "image-dimensionality",
    "a" => "intensity-image",
    "b" => "bspline",
    "i" => "initialization",
    "p" => "posterior-formulation",
    "x" => "mask-image",
    "c" => "convergence",
    "k" => "likelihood-model",
    "m" => "mrf",
    "g" => "icm",
    "o" => "output",
    "u" => "minimize-memory-usage",
    "w" => "winsorize-outliers",
    "e" => "use-euclidean-distance",
    "l" => "labels",
);

our @options = qw/d a b i p x c k m g o u w e l/;

# -------------
sub run_atropos_hf {
# -------------
    my ($do_it,$Hf) = @_;
    my $pf_path;
    my $atropos_channel= $Hf->get_value('atropos_channel');
    my $atropos_image_path  = $Hf->get_value ("${atropos_channel}-nii-path");
    my $ants_app_dir = $Hf->get_value('engine-app-ants-dir');
    my ($atropos_output_base,$atropos_output_path,$dummy) = fileparts($atropos_image_path);
    my $atropos_output = $atropos_output_path.$atropos_output_base."-atropos-labels.nii";
    my $mask_path;
    print STDOUT "  \$defaults{d} = $defaults{d}\n";
 
 # %defaults = (
 #	"a" => $atropos_image_path,
 #       "o" => $atropos_output,
 #   );
    $defaults{"a"} =  $atropos_image_path;
    $defaults{"o"} = $atropos_output;

    print STDOUT "  \$defaults{d} = $defaults{d}\n";
    if (-e $Hf->get_value('atropos_pf')) {
	$pf_path = $Hf->get_value('atropos_pf');
    } else {
	$pf_path = '';
    }
    if (defined $Hf->get_value("${atropos_channel}-strip-path")) {
	$mask_path = $Hf->get_value("${atropos_channel}-strip-path");
	$defaults{"x"} =  $mask_path;
    }
    (my $atropos_result, my $atropos_command) = execute_atropos($do_it,$pf_path );
    print STDOUT "\$atropos_command = $atropos_command \n ran with result =  $atropos_result.\n";
    return ($atropos_result);
}
    

# -------------
sub execute_atropos {
# ------------ 
    my ($do_it, $param_file_path) = @_;    
    my $cmd;
    my $param_file;
    if (-e $param_file_path) {
	my $param_file = new Headfile ('ro', $param_file_path);
	my $check_status= $param_file->check();
	if ( ! $check_status  ) { error_out("Parameter file not opened or does not exist");}
    
	my $read_status=$param_file->read_headfile;
	if ( ! $read_status  ) { error_out("Unable to read parameter file located at: ".$param_file_path );}
    }
    if ($do_it) {
	$cmd = build_command($param_file);
    }
    my $atropos_result = system($cmd);
    return($atropos_result, $cmd);

}


# -------------
sub build_command {
# -------------    
    my ($param_file) = @_;
    my $i = 0;
    my $antsPath = $ENV{'ANTSPATH'};
    my $atropos_cmd_line = $antsPath."/Atropos ";
    my $temp_cmd;
    
    foreach my $o (@options) {
	$i++;
	#system ('echo '.$o);
	$temp_cmd = handle_atropos_option($o, $param_file);
	#system ('echo '.$temp_cmd);
	if ($temp_cmd ne '') {
	    $atropos_cmd_line = $atropos_cmd_line.$temp_cmd.' ';
	}
    }
    return($atropos_cmd_line);

}

# -------------
sub handle_atropos_option {
# -------------
    my ($option, $param_file) = @_;
    my $cmd_to_execute = '';
    my $parameter;
    if (-e $param_file) {
	$parameter = search_param_file($option,$param_file );
	if ($parameter ne '') {
	    $cmd_to_execute = '-'.$option.' '.$parameter;
	    return($cmd_to_execute);
	} else {
	    return('');
	}
    } elsif (defined $defaults{$option}) {
	    $parameter = $defaults{$option};
	    $cmd_to_execute = '-'.$option.' '.$parameter;
	    return($cmd_to_execute);
    } else {
	return('');
    }
}


# -------------
#sub command_line_to_param_file {
## -------------
#    my ($command_line) = @_;
#    my @command_array = split('-',$command_line);
#    my $param_file = new Headfile;
#    for each my $option (@command_array) {
#	if ( =~ m/^-/){
#   
#
#if (-e $param_file) {
#	my $parameter = search_param_file($option,$param_file );
#	if ($parameter ne '') {
#	    $cmd_to_execute = '-'.$option.' '.$parameter;
#	    return($cmd_to_execute);
#	} else {
#	    return('');
#	}
#    } else 
#}


# -------------
sub search_param_file {
# ------------- 
    my ($option, $param_file) = @_;
    my $parameter ='';
    my $alt = $alternative{$option};
    
    if ($param_file->get_value($option) ne "NO_KEY" ) {
	$parameter = $param_file->get_value($option);
    } elsif ($param_file->get_value($option) ne "NO_KEY" ) {
	$parameter = $param_file->get_value($alt);
    } else {
	if (($defaults{$option}) ne '') {
	    $parameter = $defaults{$option};
	} else {
	    $parameter = '';
	}
    }
	return($parameter);

}
