# Perl  - read COBOL source and create an HTML web page with appropriate 'Links'.
#         assumes 'structured' COBOL - ie. use of Sections / limited use of 'Go To's etc.
#
#
#   RLP - October 2009 Version 0.8
#
# Restructure script to use 'divs' rather thans frames, tidy up code, 
#
# To do :- place output file names / directories in a parameter file
#          PERFORM statements where the perform is the only statement on the 'line' - do not process
#           - check number of words !
#          test 'COPY' processing where part of 'name'
#          make use of Template to structure the 'output' 

########################################################################################
#
#     Display changes ....
#
#          highlighting of 'keywords' based on the ISPF standard !! (red) - Working Storage / Procedure Division etc
#          highlighting of 'string values' based on the ISPF standard !! (white) - anything within quotes
#          highlighting of 'embedded commands' - CICS / SQL (EXEC .. END-EXEC) (lightblue)
#          highlighting of 'mod number' (yellow)
#          make 'periods' yellow
#
########################################################################################

########################################################################################
#
#     Other stuff ....
#
#          further 'down the track' - a Frontend !!!
#          link to 'called' modules
#
########################################################################################

#!/usr/bin/perl

use strict;
use warnings;

use List::Compare qw / get_intersection /;

sub main() {
	# define variables - a long list !!!

	my $numArgs;
	my $i_path;
	my $o_path;
	my $p_file;
	my $file;
	my $input_name;
	my $fullname;
	my $source_out;
	my $sec_tag;
	my $copy_tag;
	my $line_no;
	my $no_of_lines;
	my @program;
	my %copys;
	my %sections = ();
	my %sections_list = ();

	$" = '#';

	if ($#ARGV < 1) {
		print "\nError - input pathname / output pathname not specified\n";
		print "Usage :- perl CSV.pl <input pathname> <output pathname> \n\n";
	}
	else {
		$i_path = $ARGV[0];
		$o_path = $ARGV[1];
		print "\nInput Path - $i_path";
		print "\nOutput Path - $o_path\n";
		opendir(BIN, $i_path) or die "Can't open $i_path: $!";
		
		while( defined ($file = readdir BIN) ) {
			if ($file eq ".") {
				print "\nProcessed Dir_Header";
			}
			elsif ($file eq "..") {
				print "\nProcessed Dir_Parent";            
			}
			else {
				process ($i_path, $file, $o_path)  #### print "$file\n" if -T "$path/$file";
			}
        
			%sections = ();
			%sections_list = ();
		}
		closedir(BIN);
	}
} # end of main ...

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub process {
	my ($i_path, $p_file, $o_path) = @_;

	print "\nProcessing file $p_file\n";
	$input_name = $p_file;  
	$input_name =~ s/.txt$//;  # remove trailing file extension - '.txt'
	
	$fullname = $i_path . $p_file;

	if (!open(INFO, $fullname))
	{
		die "\nCould not open file : $fullname. Program stopped\n\n";
	}	
    
	# open files - initialize as new ...
	$source_out = $o_path."/".$input_name.'.html';
	open(OUT_1, ">$source_out");

	$sec_tag = 0;
	$line_no = 0;

	setup_program();	
	section_copy_links();
	process_keywords();
	build_source_list();
	
	print "\nProcessed file $p_file\n";


	# close files
	close (INFO);
}	

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

sub setup_program
{
	my $line;
	my $procedure = 0;
	my $length_all;
	my $length_rest;
	my $first_7;
	my $the_rest;
	my @words;
	
	$line_no = 0;	
	$procedure = "";
	$copy_tag = 0;
	$sec_tag = 0;
	
	while (defined ($line = <INFO>))
	{
		$line =~ s/\r|\n//g;    # remove carriage returns / line feeds
		chomp $line;            # just in case !!!
		$length_all = length($line);
		
		if ($length_all == 0)
		{
			$program[$line_no] = "        ";
		}
		else
		{
			$length_rest = $length_all - 7;
			$first_7 = substr($line, 0, 7);
			$the_rest = substr($line, 7, $length_rest);
			$_ = $line;
		
### process 'DIVISION' statements ###
		
			if (/DIVISION/i)
			{
				@words = split(/ /, $the_rest);
				$_ = $words[0];
				if (/IDENTIFICATION/i)
				{
					$program[$line_no] = "<span class=\"div_name\"><a name=\"Id_Div\">".$line."</a></span>";
				}
				elsif (/ENVIRONMENT/i)
				{
					$program[$line_no] = "<span class=\"div_name\"><a name=\"Env_Div\">".$line."</a></span>";				
				}
				elsif (/DATA/i)
				{
					$program[$line_no] = "<span class=\"div_name\"><a name=\"Data_Div\">".$line."</a></span>";				
				}			
				elsif (/PROCEDURE/i)
				{
					$program[$line_no] = "<span class=\"div_name\"><a name=\"Proc_Div\">".$line."</a></span>";
					$procedure = 1;				
				}			
				@words=();
			}
		
### process 'SECTION' names ###
		
			elsif(/ SECTION[.]/i)
			{
				$sec_tag++;
				@words = split(/ /, $the_rest);
				if (substr($first_7, 6, 1) eq '*')
				{
					$program[$line_no] = "<span class=\"comments\">".$line."</span>";			
				}	
				else 
				{
					$_ = $words[0];
					if (!$procedure) {
						if (/INPUT-OUTPUT/i)
						{
							$program[$line_no] = "<span class=\"section_name\"><a name=\"InOut_Sec\">".$line."</a></span>";				
						}			
						elsif (/FILE/i)
						{
							$program[$line_no] = "<span class=\"section_name\"><a name=\"File_Sec\">".$line."</a></span>";				
						}
						elsif (/WORKING-STORAGE/i)
						{
							$program[$line_no] = "<span class=\"section_name\"><a name=\"WS_Sec\">".$line."</a></span>";				
						}
						elsif (/LINKAGE/i)
						{
							$program[$line_no] = "<span class=\"section_name\"><a name=\"Link_Sec\">".$line."</a></span>";				
						}
						elsif (/CONFIGURATION/i)
						{
							$program[$line_no] = "<span class=\"section_name\"><a name=\"Conf_Sec\">".$line."</a></span>";				
						}
					}
				else
					{
						if ($procedure) {
							$sections{$words[0]}="#SEC$sec_tag";
							$sections_list{$words[0]}="#SEC$sec_tag";
							$program[$line_no] = "<a name=\"SEC$sec_tag\">".$line."</a>";
						}
					}	
				}
				@words=();
			}
	
			elsif(/ COPY /i)
			{
				$copy_tag++;
				@words = split(/ +/, $the_rest);
				if (substr($first_7, 6, 1) eq '*')
				{
					$program[$line_no] = "<span class=\"comments\">".$line."</span>";				
				}	
				else 
				{
					$words[2] =~ s/\.$//;
					$copys{$words[2]}="#COPY$copy_tag";
					$program[$line_no] = $line;	
				}
			}

### process other 'names' that start in position 8 - 'PARAGRAPH' names ###	

			else
			{			
				@words = split(/ /, $the_rest);
				if (substr($first_7, 6, 1) eq '*')
				{
					$program[$line_no] = "<span class=\"comments\">".$line."</span>";			
				}
				elsif (substr($first_7, 6, 1) eq '/')
				{
					$program[$line_no] = "<span class=\"comments\">".$line."</span>";			
				}
				elsif ($length_rest < 1)    # process null lines !!!
				{
					$program[$line_no] = $line;
				}
				elsif ((substr($the_rest, 0, 1) ne " ") && $procedure)
				{
					$sec_tag++;
					$words[0] =~ s/\.$//;
					$sections{$words[0]}="#SEC$sec_tag";
					$program[$line_no] = "<a name=\"SEC$sec_tag\">".$line."</a>";
				}
				else
				{
					$program[$line_no] = $line;
				}
				@words=();
			}
		}
		$line_no++;
	}
	$line_no--;
	$no_of_lines = $line_no;
}

### process the links for Section / Copy names / Go Tos etc ###

sub section_copy_links
{
	my $length_all;
	my $length_rest;
	my $pos_7;
	my $the_rest;
	my $space;
	my $first_7;
	my @words;
	my $p_tag;
	my $new_line;
	my $section_name;
	my $start;
	my $href;
	my $perform_name;
	my $perform_name_len;
	my $copy_name;
	my $c_tag;
	my $copy_name_len;
	my $g_tag;
	my $goto_name;
	my $goto_name_len;
	
	$line_no = 0;
	while ($line_no <= $no_of_lines)
	{
		$program[$line_no] =~ s/\s+$//;  # remove trailing spaces
		
		### prepare !!! ###
		
		chomp($program[$line_no]);	
		$length_all = length($program[$line_no]);
		$length_rest = $length_all - 7;
		$pos_7 = substr($program[$line_no], 6, 1);
		$first_7 = substr($program[$line_no], 0, 7);
		$the_rest = substr($program[$line_no], 7, $length_rest);
		$space = " ";
		
		### process 'the rest' - everything after byte 7 ###	
		$_ = $the_rest;
		if ($pos_7 eq "*")
		{
		}
		
### process 'PERFORM' statements - add links to enable navigation to the appropriate 'section' ###

	
		elsif (/ PERFORM/i)
		{
			@words = split(/ +/, $the_rest);
			
			if ($words[2] =~ /\.$/)
			{
				chop($words[2]);
			}			
			if (exists ($sections{$words[2]})) ### check if in SECTION hash ###
			{
				$section_name = $words[2];
				$p_tag = $sections{$section_name}; 
				
				$start = index( uc($the_rest), 'PERFORM' ); ### get position of PERFORM ###
				$href = "<a href=\"$p_tag\">";
				
				$new_line = "";
				$space = " ";
				$new_line = $new_line.$first_7;
				
				$new_line = $new_line.($space x $start); ### indent the PERFORM / 'link' by the correct amount ###
				$new_line = $new_line.$href;
			
				$perform_name_len = $length_rest - $start;
				$perform_name = substr($the_rest, $start, $perform_name_len);
				$new_line = $new_line.$perform_name."</a>";
				$program[$line_no] = $new_line;
				@words=();				
			}	
		}
		
### process 'COPY' statements ......... ###
		
		elsif (/COPY /i)
		{
			@words = split(/ +/, $the_rest);

			if ($words[2] =~ /\.$/)
			{
				chop($words[2]);
			}			
			if (exists ($copys{$words[2]})) ### check if in COPY hash ###
			{
				$copy_name = $words[2];
				$c_tag = $copys{$copy_name}; 
				
				$start = index( uc($the_rest), 'COPY' ); ### get position of COPY ###
				$href = "<a href=\"$c_tag\">";
				
				$new_line = "";
				$space = " ";
				$new_line = $new_line.$first_7;
				
				$new_line = $new_line.($space x $start); ### indent the COPY / 'link' by the correct amount ###
				$new_line = $new_line.$href;
			
				$copy_name_len = $length_rest - $start;
				$copy_name = substr($the_rest, $start, $copy_name_len);
				$new_line = $new_line.$copy_name."</a>";
				$program[$line_no] = $new_line;
				@words=();				
			}
		}	
		
### process 'GO TO' statements ......... ###
		
		elsif (/GO TO/i)
		{
			@words = split(/ +/, $the_rest);
			
			if ($words[3] =~ /\.$/)
			{
				chop($words[3]);
			}
			if (exists ($sections{$words[3]})) ### check if in SECTIONS hash ###
			{
				$goto_name = $words[3];
				$g_tag = $sections{$goto_name}; 
				
				$start = index( uc($the_rest), 'GO TO' ); ### get position of the GO TO ###
				$href = "<a href=\"$g_tag\">";
				
				$new_line = "";
				$space = " ";
				$new_line = $new_line.$first_7;
				
				$new_line = $new_line.($space x $start); ### indent the GO TO / 'link' by the correct amount ###
				$new_line = $new_line.$href;
			
				$goto_name_len = $length_rest - $start;
				$goto_name = substr($the_rest, $start, $goto_name_len);
				$new_line = $new_line.$goto_name."</a>";
				$program[$line_no] = $new_line;
				@words=();				
			}
		}					
		$line_no++;
	}		
}

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
