#!/usr/local/pipeline-link/perl

# convert_all_to_nifti.pm 

# modified 20130730 james cook, renamed flip_y to flip_x to be more accurate.
# modified 2012/04/27 james cook. Tried to make this generic will special handling for dti from archive cases.
# calls nifti code that can get dims from header
# created 2010/11/02 Sally Gewalt CIVM
use strict;
require convert_to_nifti_util;
my $debug_val = 5;


# ------------------
sub convert_all_to_nifti {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype
  my ($go, $Hf_out)  = @_;
  my $flip_x=$Hf_out->get_value('flip_x');
  my $flip_z=$Hf_out->get_value('flip_z');
  # dimensions are for the SOP acquisition. 
  my $nii_raw_data_type_code = 512; # civm .raw  (unsigned short - big endian) 
  my $nii_i32_data_type_code = 8; # .i32 output of t2w image set creator 
  my $ants_app_dir           = $Hf_out->get_value('engine-app-ants-dir');
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));


# -- open, read headfile belonging to  each runno for image params
  my @cmd_list;
  my $nii_ch_id;
  print "Convert All to Nifti\n";
  for my $ch_id (@channel_array) {
      print "\tLooking up channel $ch_id \n";
      my $runno = $Hf_out->get_value("$ch_id\-runno");
      my $runno_dir = $Hf_out->get_value("$ch_id\-path");
      if (! -d $runno_dir) { error_out ("convert_all_to_nifti: no source dir! $runno_dir"); }
      if ( $ch_id =~ m/(T1)|(T2W)|(T2star)/ ) { # should move this to global options, as archivechannels	  
	  if ($ch_id eq 'T2W' ) {
	      print ("convert_all_to_nifti: ASSUMING YOUR T2W DATA is 16 bit!!!!!! IF YOU USED the NEW fic program this is OK! If you have older MEFIC processed data go to convert_all_to_nifti and change $nii_raw_data_type_code to $nii_i32_data_type_code (switch lines 53 and 55! \n"); 
	  }
	  my $input_headfile  = $runno_dir . "/" . "$runno.headfile";
	  print "\tOpening input data headfile: $input_headfile\n";
	  my $runno_Hf = new Headfile ('ro', $input_headfile);
	  if (! $runno_Hf->check)         {error_out("Problem opening input runno headfile; $input_headfile");}
	  if (! $runno_Hf->read_headfile) {error_out("Could not read input runno headfile: $input_headfile");}
	  my $input_specid = $runno_Hf->get_value ("U_specid");
#	  my $xdim = $runno_Hf->get_value ("S_xres_img");
	  log_info( "  Specimen id read from $ch_id input scan $runno headfile: $input_specid\n");
	  $Hf_out->set_value("specid_${ch_id}"  , $input_specid);

	  $nii_ch_id=convert_to_nifti_util($go, $ch_id, $nii_raw_data_type_code, $flip_x, $flip_z, $Hf_out, $runno_Hf); # .raw 
      } elsif ( $ch_id =~ m/(adc)|(dwi)|(e1)|(fa)/){  # should move this to global options, dtiresearchchannels
	  my $input_headfile = $runno_dir . "/" . "tensor${runno}.headfile";
	  my $runno_Hf = new Headfile ('ro', $input_headfile);
	  if (! $runno_Hf->check)          {
	      $input_headfile = $runno_dir . "/" . "${runno}.headfile";
	      $runno_Hf = new Headfile ('ro', $input_headfile);
	  }
	  if (! $runno_Hf->check)          { error_out("Problem opening input runno headfile; $input_headfile"); }
	  if (! $runno_Hf->read_headfile)  {
	      error_out("Could not read input runno headfile: $input_headfile");
	  }
	  my $input_specid = $runno_Hf->get_value ("U_specid");
	  log_info( "  Specimen id read from $ch_id input scan $runno headfile: $input_specid\n");
# lines from convert_to_nifti which add to hf_out
	  my $in_path = $Hf_out -> get_value("$ch_id\-path");
	  my $in_name = $Hf_out -> get_value("$ch_id\-image-basename");
	  my $in_ext  = $Hf_out -> get_value("$ch_id\-image-suffix");
	  my $in_file = "${in_path}/${in_name}.${in_ext}";
	  
	  my $dest_nii_file = "${in_name}.${in_ext}";
	  my $dest_dir      = $Hf_out->get_value("dir-work");
	  my $dest_nii_path = "$dest_dir/$dest_nii_file";
	  my  $NIFTI_MFUNCTION = $Hf_out->get_value("nifti_matlab_converter");
	  $nii_ch_id = "$ch_id\-nii";
  	  $Hf_out->set_value("$ch_id\_image-suffix", $in_ext); 
	  $Hf_out->set_value("$nii_ch_id\-file" , $dest_nii_file);
	  $Hf_out->set_value("$nii_ch_id\-path", $dest_nii_path);
	  
    
	  ######## clean up these options.
	  my $src_image_path=$in_path;
	  my $image_prefix=$in_name;
	  my $image_suffix=$in_ext;
#	  $dest_nii_path=0;
	  my ($xdim,$ydim,$zdim) =(0,0,0);#### should get this from nii.hdr in matlab
	  #$nii_datatype_code=$nii_raw_data_type_code;
	  my ($xvox,$yvox,$zvox) =(0,0,0);#### should get this from nii.hdr in matlab
#	  $flip_x=0;
#	  $flip_z=0;
	  my $sliceselect    = $Hf_out->get_value_like("slice-selection");  # using get_value like is experimental, should be switched to get_value if this fails.
	  my ($zstart, $zstop);
	  
	  my @stringargs = ($src_image_path,$image_prefix,$image_suffix,$dest_nii_path);
	  my @numargs =    ($xdim, $ydim, $zdim, $nii_raw_data_type_code, $xvox,$yvox,$zvox, $flip_x, $flip_z);

	  if ( $sliceselect eq "all" || $sliceselect eq "NO_KEY" || $sliceselect eq "UNDEFINED_VALUE" || $sliceselect eq "EMPTY_VALUE" ) { 
	    # do nothing with zstart, zstop
	    $zstart='';
	    $zstop='';
	  } else { 
	    ($zstart, $zstop) = split('-',$sliceselect);
	    push(@numargs,$zstart);
	    push(@numargs,$zstop);
	  } 

	  my $args = "'".join('\', \'',@stringargs)."',".join(', ',@numargs);
	  my $cmd =  make_matlab_command ($NIFTI_MFUNCTION, $args, "$ch_id\_", $Hf_out); 
	  #INSERT flip nifti code here abouts, maybe with flip nii function
#	  my $cmd="$ants_app_dir/PermuteFlipImageOrientationAxes 3 $in_file $dest_nii_path 0 1 2 0 $flip_x $flip_z 1"; 
	  #PermuteFlipImageOrientationAxes ImageDimension  inputImageFile  outputImageFile xperm yperm {zperm}  xflip yflip {zflip}  {FlipAboutOrigin}
#	  my $cmd = "cp $in_file $dest_nii_path";

	  push @cmd_list, $cmd;
	  
      } else {
	  error_out("Unsupported channel name $ch_id\n");
      }
      if ($nii_ch_id eq '') {
	  error_out("Nii id not set correctly, on convert_to_nifti_util\n" );
      } else { 
	  print("\tnii_ch_id returnd $nii_ch_id\n") if ($debug_val >=10);
      }
  }
  
  if($#cmd_list>=0) {#_indep_forks
      execute($go, "copying dti derrived to work and flip if necessary", @cmd_list) or error_out("failed to move nii input files to work dir");
  }

}


1;

