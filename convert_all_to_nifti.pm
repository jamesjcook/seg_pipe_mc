#!/usr/local/pipeline-link/perl

# convert_all_to_nifti.pm 

# created 2010/11/02 Sally Gewalt CIVM
# modified 2012/04/27 james cook. Tried to make this generic will special handling for dti from archive cases.
# calls nifti code that can get dims from header

use strict;
require convert_to_nifti_util;
my $debug_val=10;


# ------------------
sub convert_all_to_nifti {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype
  my ($go, $Hf_out)  = @_;
  my $flip_y=$Hf_out->get_value('flip_y');
  my $flip_z=$Hf_out->get_value('flip_z');
  # dimensions are for the SOP acquisition. 
  my $nii_raw_data_type_code = 4; # civm .raw  (short - big endian)
  my $nii_i32_data_type_code = 8; # .i32 output of t2w image set creator 

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
      if ( $ch_id =~ m/(T1)|(T2W)|(T2star)/ ) {
	  if ($ch_id eq 'T2W' ) {
	      print ("convert_all_to_nifti: ASSUMING YOUR T2W DATA is 16 bit!!!!!! IF YOU USED the NEW fic program this is OK! If you have older MEFIC processed data go to convert_all_to_nifti and change $nii_raw_data_type_code to $nii_i32_data_type_code (switch lines 53 and 55! \n"); 
	  }
	  my $input_headfile  = $runno_dir . "/" . "$runno.headfile";
	  print "\tOpening input data headfile: $input_headfile\n";
	  my $runno_Hf = new Headfile ('ro', $input_headfile);
	  if (! $runno_Hf->check)         {error_out("Problem opening input runno headfile; $input_headfile");}
	  if (! $runno_Hf->read_headfile) {error_out("Could not read input runno headfile: $input_headfile");}
	  my $input_specid = $runno_Hf->get_value ("U_specid");
	  my $xdim = $runno_Hf->get_value ("S_xres_img");
	  log_info( "  Specimen id read from $ch_id input scan $runno headfile: $input_specid\n");
	  $Hf_out->set_value("specid_${ch_id}"  , $input_specid);

	  $nii_ch_id=convert_to_nifti_util($go, $ch_id, $nii_raw_data_type_code, $flip_y, $flip_z, $Hf_out, $runno_Hf); # .raw 
      } elsif ( $ch_id =~ m/(adc)|(dwi)|(e1)|(fa)/){
	  my $input_headfile = $runno_dir . "/" . "tensor${runno}.headfile";
	  my $runno_Hf = new Headfile ('ro', $input_headfile);
	  if (! $runno_Hf->check)          {error_out("Problem opening input runno headfile; $input_headfile");}
	  if (! $runno_Hf->read_headfile)  {error_out("Could not read input runno headfile: $input_headfile");}
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
	
	  $nii_ch_id = "$ch_id\-nii";
  	  $Hf_out->set_value("$ch_id\_image-suffix", $in_ext); 
	  $Hf_out->set_value("$nii_ch_id\-file" , $dest_nii_file);
	  $Hf_out->set_value("$nii_ch_id\-path", $dest_nii_path);
	  
	  my $cmd = "cp $in_file $dest_nii_path";
	  push @cmd_list, $cmd;
	  
#	  $Hf_out->setValue("$ch_id\-file
#my $dest_nii_file = "$runno\.nii";
#	  mv $runno_dir

#	  my $dest_nii_file = "$runno\.nii";
#	  my $dest_nii_path = "$dest_dir/$dest_nii_file";
#	  my $runno          = $Hf->get_value("$setid\-file");  # runno of civmraw format scan 
#	  my $src_image_path = $Hf->get_value("$setid\-path");
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
      execute($go, "copying dti derrived to work", @cmd_list) or error_out("failed to move nii input files to work dir");
  }

}


1;

