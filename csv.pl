=head1 NAME

csv.pl

=head1 SYNOPSIS


=head1 DESCRIPTION

Wrap COBOL source files in HTML tags

=head1 AUTHOR

rpillar - <http://developontheweb.co.uk/>

=head1 SEE ALSO

=cut

#!/usr/bin/perl;

use strict;
use warnings;

use Getopt::Long;
use List::Compare qw / get_intersection /;

#------------------------------------------------------------------------------
# main 'control' process ..
#------------------------------------------------------------------------------

{

    my $i_path;
    my $o_path;
    GetOptions( "input=s", \$i_path, "output=s", \$o_path );
    unless ( $i_path && $o_path ) {
        usage();
        exit;
    }

	print "\nInput Path - $i_path";
	print "\nOutput Path - $o_path\n";
	opendir(BIN, $i_path) or die "Can't open $i_path: $!";
	
	# process all files in the 'input' folder ...	
	while( defined (my $file = readdir BIN) ) {
		if (-T $file) {
			process ($i_path, $file, $o_path)
		}
	}
	closedir(BIN);

} # end of main ...

#------------------------------------------------------------------------------
# Process the specified file
#------------------------------------------------------------------------------
sub process {
	my ($i_path, $p_file, $o_path) = @_;

	print "\nProcessing file $p_file\n";
	my $input_name = $p_file;  
	$input_name =~ s/i\.txt$|\.cbl$|\.CBL$//;  # remove trailing file extension - 'txt/cbl/CBL'
	
	my $fullname = $i_path . $p_file;

	if (!open(INFO, $fullname)) {
		die "\nCould not open file : $fullname. Program stopped\n\n";
	}	
	
	# input file
	my @infile = <INFO>;
    
	# open output files - initialize as new ...
	my $source_out = $o_path."/".$input_name.'.html';
	open(OUT_1, ">$source_out");

    # process - initial update of 'program' details, identify 'main' section / copy / paragraph links
	my ( $source, $sections, $copys ) = add_main_links(\@infile);	
	my $updated_source = section_copy_links( $source, $sections, $copys );
	process_keywords();
	build_source_list();
	
	print "\nProcessed file $p_file\n";


	# close files
	close (INFO);
}

#==============================================================================

=head3 NAME

add_main_links

=cut

#==============================================================================
sub add_main_links {
    my $file = shift;
    
    # variables ...
	my @words;	
	my @source;
	my $line_no     = 0;	
	my $procedure   = "";
	my $copy_tag    = 0;
	my $section_tag = 0;
	my %sections;
	my %sections_list;
	my %copys;
	
	foreach my $line ( @{$file} ) {
		$line =~ s/\r|\n//g;    # remove carriage returns / line feeds
		chomp $line;            # just in case !!!
		my $length_all = length($line);
		
		# blank line - just set to 'area A' - spaces 
		if ( $length_all == 0 ) {
			$source[$line_no] = "        ";
			$line_no++;
			next;
		}		
		
		# split 'line' - area 'A' / 'B' (assumes margings at 8 and 72) - not strictly true from a COBOL perspective but ...
		my ( $area_A, $area_B ) =  unpack("(A7A65)",$line);
		
        ### process 'DIVISION' statements ###		
		if ( $line =~ /DIVISION/i) {
			@words = split(/ /, $area_B);

            if ( $words[0] =~ /IDENTIFICATION/i ) {
			    $source[$line_no] = "<span class=\"div_name\"><a name=\"Id_Div\">".$line."</a></span>";
		    }
			elsif( $words[0] =~ /ENVIRONMENT/i) {
				$source[$line_no] = "<span class=\"div_name\"><a name=\"Env_Div\">".$line."</a></span>";				
			}
			elsif ( $words[0] =~ /DATA/i) {
				$source[$line_no] = "<span class=\"div_name\"><a name=\"Data_Div\">".$line."</a></span>";				
			}			
			elsif ( $words[0] =~ /PROCEDURE/i) {
				$source[$line_no] = "<span class=\"div_name\"><a name=\"Proc_Div\">".$line."</a></span>";
				
				# if I have reached the 'procedure' division then set this flag - used later ...
				$procedure = 1; 				
			}			
			@words=(); # reset ...
		}
		
        ### process 'SECTION' names ###
		elsif(/\sSECTION[.]/i) {
			$section_tag++;
			@words = split(/\s/, $area_B);
			
			# if this line is a comment ...
			if (substr($area_A, 6, 1) eq '*') {
				$source[$line_no] = "<span class=\"comments\">".$line."</span>";			
			}	
			else {
			
			    # these SECTIONs should always appear 'above' the PROCEDURE division ...
				unless ($procedure) {
					if ($words[0] =~ /INPUT-OUTPUT/i) {
						$source[$line_no] = "<span class=\"section_name\"><a name=\"InOut_Sec\">".$line."</a></span>";				
					}			
					elsif ($words[0] =~ /FILE/i) {
						$source[$line_no] = "<span class=\"section_name\"><a name=\"File_Sec\">".$line."</a></span>";				
					}
					elsif ($words[0] =~ /WORKING-STORAGE/i) {
						$source[$line_no] = "<span class=\"section_name\"><a name=\"WS_Sec\">".$line."</a></span>";				
					}
					elsif ($words[0] =~ /LINKAGE/i) {
						$source[$line_no] = "<span class=\"section_name\"><a name=\"Link_Sec\">".$line."</a></span>";				
					}
					elsif ($words[0] =~ /CONFIGURATION/i) {
						$source[$line_no] = "<span class=\"section_name\"><a name=\"Conf_Sec\">".$line."</a></span>";				
					}
				}
				
				# store 'sections' and add a named 'link' ...
				else {
					$sections{$words[0]}      = "#SEC$section_tag";
					$sections_list{$words[0]} = "#SEC$section_tag";
					$source[$line_no]         = "<a name=\"SEC$section_tag\">".$line."</a>";
				}	
			}
			@words=(); # reset ...
		}
	    ### process 'COPY' names ###
		elsif(/ COPY /i) {
			$copy_tag++;
			@words = split(/ +/, $area_B);
			if (substr($area_A, 6, 1) eq '*') {
				$source[$line_no] = "<span class=\"comments\">".$line."</span>";		
			}	
			else {
				$words[2] =~ s/\.$//;
				$copys{$words[2]}="#COPY$copy_tag";
				$source[$line_no] = $line;	
			}
		}

        ### process other 'names' that start in position 8 - 'PARAGRAPH' names ###	

		else {			
			@words = split(/ /, $area_B);
			if (substr($area_A, 6, 1) eq '*') {
				$source[$line_no] = "<span class=\"comments\">".$line."</span>";			
			}
			elsif (substr($area_A, 6, 1) eq '/') {
				$source[$line_no] = "<span class=\"comments\">".$line."</span>";			
			}
			elsif ((substr($area_B, 0, 1) ne " ") && $procedure) {
				$section_tag++;
				$words[0]            =~ s/\.$//;
				$sections{$words[0]} = "#SEC$section_tag";
				$source[$line_no]    = "<a name=\"SEC$section_tag\">".$line."</a>";
			}
			else {
				$source[$line_no] = $line;
			}
			@words=();
		}
		
	    $line_no++;
	}

    # return initial 'program' listing, section names, copy names 
    return ( \@source, \%sections, \%copys );
}	

#------------------------------------------------------------------------------
# process the links for Section / Copy names / Go Tos etc ###
#------------------------------------------------------------------------------

sub section_copy_links {
    my ( $source, $sections, $copys ) = @_;
	
	my $line_no = 0;
	foreach my $line ( @{$source} ) {

		# split 'line' - area 'A' / 'B' (assumes margings at 8 and 72) - not strictly true from a COBOL perspective but ...
		my ( $area_A, $area_B ) =  unpack("(A7A65)",$line);
		
		### ignore 'comment' lines
		if (substr($area_A, 6, 1) eq '*') {
			$line_no++;
			next;
		}
		
        ### process 'PERFORM' statements - add links to enable navigation to the appropriate 'section' ###	
		if ( $area_B =~ /\sPERFORM/i)
		{
			my @words = split(/ +/, $area_B);
			
			# remove 'period' at end of SECTION name (if it exists)
			if ($words[2] =~ /\.$/)
			{
				chop($words[2]);
			}			
            
            ### check if this 'word' is in SECTION hash ###
			if (exists ( $sections->{$words[2]} ) )          
			{
				my $section_name = $words[2];
				my $p_tag = $sections->{$section_name}; 
				
				### get position of PERFORM ###
				my $start = index( uc($area_B), 'PERFORM' ); 
				my $href = "<a href=\"$p_tag\">";
				
				### indent the PERFORM / 'link' by the correct amount ###
				my $new_line = $area_A;
				$new_line = $new_line.( ' ' x $start);     
				$new_line = $new_line . $href;
			
				my $perform_name_len  = length($area_B) - $start;
				my $perform_name      = substr($area_B, $start, $perform_name_len);
				$new_line             = $new_line . $perform_name . "</a>";

				### updated 'line'
				@{$source}[$line_no] = $new_line;			
			}

			$line_no++;
			next;	
		}
		
        ### process 'COPY' statements ###
		
		if (/COPY /i)
		{
			my @words = split(/ +/, $area_B);

			# remove 'period' at end of COPY name (if it exists)
			if ($words[2] =~ /\.$/)
			{
				chop($words[2]);
			}

			### check if in COPY hash ###
			if (exists ( $copys->{$words[2]} ) ) 
			{
				my $copy_member_name = $words[2];
				my $c_tag            = $copys->{$copy_member_name}; 
				
				### get position of COPY ###
				my $start = index( uc($area_B), 'COPY' ); 
				my $href  = "<a href=\"$c_tag\">";
				
				### indent the COPY / 'link' by the correct amount ###
				my $new_line = $area_A;				
				$new_line = $new_line.( ' ' x $start ); 
				$new_line = $new_line . $href;
			
				my $copy_name_len = length($area_B) - $start;
				my $copy_name     = substr($area_B, $start, $copy_name_len);
				$new_line         = $new_line . $copy_name . "</a>";

				### updated 'line'
				@{$source}[$line_no] = $new_line;				
			}

			$line_no++;
			next;
		}	
		
        ### process 'GO TO' statements ###
		
		if (/GO TO/i)
		{
			my @words = split(/ +/, $area_B);
			
			# remove 'period' at end of GO TO name (if it exists)
			if ($words[3] =~ /\.$/)
			{
				chop($words[3]);
			}

			### check if in SECTIONS hash ###
			if (exists ( $sections->{$words[3]} ) ) 
			{
				my $goto_label_name = $words[3];
				my $g_tag           = $sections->{$goto_label_name}; 
				
				### get position of the GO TO ###
				my $start = index( uc($area_B), 'GO TO' ); 
				my $href = "<a href=\"$g_tag\">";
				
				### indent the GO TO / 'link' by the correct amount ###
				my $new_line = $area_A;				
				$new_line = $new_line.( ' ' x $start ); 
				$new_line = $new_line . $href;
			
				my $goto_name_len = length($area_B) - $start;
				my $goto_name     = substr($area_B, $start, $goto_name_len);
				$new_line         = $new_line . $goto_name . "</a>";

				### updated 'line'
				@{$source}[$line_no] = $new_line;			
			}

			$line_no++;
			next;
		}	

		$line_no++;
	}

	return $source;		
}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub process_keywords
{
	my $line;
	my $procedure;
	my $length_all;
	my $length_rest;
	my $first_7;
	my $pos_7;
	my $the_rest;
	my $start;
	my @words;
	my @WORDS;
	my $lc;
	my @intersection;
	my $match;
	my @keywords = ('SECTION', 'PERFORM', 'END-PERFORM', 'MOVE', 'TO', 'IF', 'END-IF', 'EVALUATE', 'END-EVALUATE',
			'INSPECT', 'TALLYING', 'FROM', 'UNTIL', 'COMPUTE', 'FOR', 'OF', 'BY', 'INTO', 'SET', 'DISPLAY', 'CLOSE');
		
	$line_no = 0;
	while ($line_no <= $no_of_lines)
	{
		$line = $program[$line_no];
		$_ = $line;
		if (/ PROCEDURE /i)
		{
			$procedure = 1;
		}
		if ($procedure)
		{
			if (/comments/i)
			{
				;
			}
			else
			{
				if (/GO TO/i)
				{
					;
				}
				else
				{
					$length_all = length($line);
					$length_rest = $length_all - 7;
					$first_7 = substr($line, 0, 7);
					$pos_7 = substr($line, 6, 1);
					$the_rest = substr($line, 7, $length_rest);
					@words = split(/ +|\./, $the_rest);
					@WORDS = map { uc } @words;
					$lc = List::Compare->new('--unsorted', \@keywords, \@WORDS);
					@intersection = $lc->get_intersection;
			
					foreach $match (@intersection)
					{
						$start = index( uc($the_rest), $match );
						my $prefix = substr($the_rest, 0, $start);
						my $keyword_span = "<span class=\"keyword\">";
						my $keyword_length = length($match);
						my $keyword = substr($the_rest, $start, $keyword_length);
						my $keyword_span_close = "</span>";
						my $suffix_length = $length_rest - ($start + $keyword_length);
						my $suffix = substr($the_rest, $start + $keyword_length, $suffix_length);
						$line = $first_7.$prefix.$keyword_span.$keyword.$keyword_span_close.$suffix;
						$length_all = length($line);			
						$length_rest = $length_all - 7;
						$the_rest = substr($line, 7, $length_rest);			
					}
				}
				$program[$line_no] = $line;
			}
		}
		$line_no++;
	}
}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub build_source_list {
	my $href1;
	my $href2;
	my @sorted_copy;
	my @sections_keys;
	my @sections_values;
	my $length;
	my $y;
	
	print OUT_1 "<!doctype html>";
	print OUT_1 "<html>";
	print OUT_1 "<head>";
	print OUT_1 "<meta charset=\"utf-8\">";
	print OUT_1 "<title>COBOL Source Viewer</title>";
	print OUT_1 "<link rel=\"stylesheet\" type=\"text/css\" href=\"csv.css\">";
	print OUT_1 "</head>";
	print OUT_1 "<body>";

	print OUT_1 "<div id=\"divisions\">";
	print OUT_1 "<br>"."<a href=\"#Id_Div\">Identification Division</a"."<br>";
	print OUT_1 "<br>"."<a href=\"#Env_Div\">Environment Division</a"."<br>";
	print OUT_1 "<br>"."<a href=\"#Data_Div\">Data Division</a"."<br>";	
	print OUT_1 "<br>"."<a href=\"#WS_Sec\">Working Storage</a"."<br>";
	print OUT_1 "<br>"."<a href=\"#Link_Sec\">Linkage Section</a"."<br>";
	print OUT_1 "<br>"."<a href=\"#Proc_Div\">Procedure Division</a"."<br>";
	print OUT_1 "<br>"."<hr>";
	print OUT_1 "</div>";

	print OUT_1 "<div id=\"code\">";
	print OUT_1 "<pre>";	
	$line_no = 0;
	while ($line_no <= $no_of_lines)
	{
		print OUT_1 $program[$line_no]."<br>";
		$line_no++;
	}
	print OUT_1 "</pre>";
	print OUT_1 "</div>";

### sort the sections list and place in html page ###

	print OUT_1 "<div id=\"sections_list\">";
	$href1 = "<a href=\"";
	$href2 = "\">";
	@sections_keys = keys %sections_list;
	@sections_keys = sort(@sections_keys);
	$length = @sections_keys;
	$length--;
	for ($y = 0; $y <= $length && $sections_keys[$y] ne "x"; $y++)
	{
		print OUT_1 $href1.$sections_list{$sections_keys[$y]}.$href2.$sections_keys[$y]." <a/>"."<br>";		
	}
	print OUT_1 "</div>";
	
### sort the copybook list and place in html page ###

	print OUT_1 "<div id=\"copybooks\">";
	$href1 = "<a href=\"".$o_path."copy/";
	$href2 = ".html\"target=\"_blank\">";	
	@sorted_copy = keys %copys;
	@sorted_copy = sort(@sorted_copy);
	$length = @sorted_copy;
	$length--;
	for ($y = 0; $y <= $length && $sorted_copy[$y] ne "x"; $y++)
	{
		print OUT_1 $href1.$sorted_copy[$y].$href2.$sorted_copy[$y]." <a/>"."<br>";		
	}
	print OUT_1 "</div>";
	
	print OUT_1 "</body>";
	print OUT_1 "</html>";
}

sub usage {
    print "\nPerl script - csv.pl\n"
	print "\nError - both input pathname and output pathname need to be specified\n";
	print "Usage :- perl CSV.pl <input pathname> <output pathname> \n\n";
}
