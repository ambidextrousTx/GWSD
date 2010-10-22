# ObjectBuilder.pm
#
# Ravi S Sinha
# MS (Computer Science)
# University of North Texas
# Written: Fall 2006

#! /usr/bin/perl


# ======================================================================
# readinText
#
# read all sentences
# store Word instances for each word, punctuation
# the resulting structure (@discourse) is a matrix
#  - sentences are on rows
#  - for each sentence (row) words are on columns
#
# CHANGE LOG
#
# Date          Author          Change
#=======================================================================
# 03-03-2004    Rada            initial version
# 10-14-2006    Ravi            modified for a project (Graph based WSD)
#=======================================================================

# a global variable incremented for each instance -- represents
# a unique id to be assigned to those instances that do not have
# an id in the input file

$wordId = 0;

sub readinText {
    my ($discourseRef, $inFile, $wordObjects) = @_;
    my @discourse = @$discourseRef;
    my @wordObj = @$wordObjects;

    my $sentIndex = 0;
    my $wordIndex = 0;

    # load input data
    # open the SemCor-like file, and start reading it
    open INFILE, "<$inFile" || die "Could not open input file $inFile. Please check the path and make sure it is valid\n";
    (-r INFILE) || die "Could not open input file $inFile. Please check the path and make sure it is valid\n";

    $testline=<INFILE>;

    print LOG "Checkpoint : Inside the Objectbuilder module\nThe test line of file = $testline\n";
    print LOG "Infile = $inFile\n";
    if (!($testline=~/\<.*=.*\>/)){
    print "\n \n WARNING:  Most probably you have specified the wrong input format!!!! \n \n";
    }
    close INFILE;
    open INFILE, "<$inFile" || die "Could not open input file $inFile. Please check the path and make sure it is valid\n";
    (-r INFILE) || die "Could not open input file $inFile. Please check the path and make sure it is valid\n";

    while(my $line = <INFILE>) {
	chomp $line;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;

	# if end of sentence, reset wordIndex, and increase sentIndex
	if($line =~ /^\<\/s\>/) {
	    $wordIndex=0;
	    $sentIndex++;
	    next;
	}
	
	# If inside sentence, store Word-s
	if($line =~ /^\<wf/ ||
	   $line =~ /^\<punc/) {
		
	    $word = new WordClass($line);
 	    $wordObj[$wordCount++] = $word;
	    if($word->{id} eq "?") {
		$wordId++;
		$word->{id} = "AUTO.".$wordId;
	    }
	    
		if(defined ($word)) {
			$discourse[$sentIndex][$wordIndex++] = $word;
			#print LOG $word->{word}."\n";
			# Checked, the code is working all right so far
			# The objects are being initialized and populated, and are returning values properly
		}
	}   
    }
    @$discourseRef = @discourse;
    @$wordObjects = @wordObj;
	
}

sub createObjects {
	my ($database, $sentenceObjects) = @_;

	my @databaseRef = @$database;
	my @sentenceObj = @$sentenceObjects;

	my $sentenceCount = 0;
	
	$wn = WordNet::QueryData->new();
	open OUTFILE, ">./temp/File.Objects";


	my $sentences = scalar(@databaseRef);
	my $sentid = 0;


	print LOG "We are inside the createObjects routine\n";
	print LOG "\$sentence = $sentences\n";
	# All right, everything is working so far

	my $j;
	for(my $i=0; $i<$sentences; $i++) { # Loop over sentence objects
		$j = 0;
		my $sentObj = new SentenceClass($databaseRef[$i]);
		$sentenceObj[$sentenceCount++] = $sentObj; # sentenceCount EQ i
		if (($setenceObj[$i]->{id}) == '?') {
			$sentid++;
			$sentenceObj[$i]->{id} = "AUTO.".$sentid;
		}
		print OUTFILE "Sentence #".$i."\n";
		print OUTFILE "============================================================"."\n";
		print OUTFILE "id: ". $sentenceObj[$i]->{id}."\n\n";
		my @sentence = @{$databaseRef[$i]};
		my $wcount = scalar(@sentence);

		# print LOG "\$wcount = $wcount\n";
		# Alles okay soweit
		LOOP: for(my $c=0; $c<$wcount; $c++) { # Loop over word objects
			# NEW ADDITION AS OF JAN 20, 2007
			
			if(!($sentence[$c]->{littlePos} =~ /[nvar]/)) {
				next LOOP;
				
			} 
			#elsif($sentence[$c]->{wnsn} < 1) {
			#	next LOOP;
			#}
			# The above is the bug which causes empty objects and empty results for the case
			# when the dataset contains no tags because in that case the wnsn values are
			# by default set as 0 so this condition is always true and the objects are
			# never populated
			else {
			$sentenceObj[$i]->{words}[$j] = $sentence[$c];

			# Writing output to file only for testing purposes
			# Object orientation is to be used in this project
			print OUTFILE "Word #". $j."\n\n";
			print OUTFILE "word: ". $sentenceObj[$i]->{words}[$j]->{word}." ";
			print OUTFILE "lemma: ". $sentenceObj[$i]->{words}[$j]->{lemma}." ";
			print OUTFILE "pos: ". $sentenceObj[$i]->{words}[$j]->{pos}." ";
			print OUTFILE "sense: ". $sentenceObj[$i]->{words}[$j]->{sense}." ";
			print OUTFILE "id: ". $sentenceObj[$i]->{words}[$j]->{id}." ";
			print OUTFILE "wnsn: ". $sentenceObj[$i]->{words}[$j]->{wnsn}." ";
			print OUTFILE "littlepos: ". $sentenceObj[$i]->{words}[$j]->{littlePos}." ";
			print OUTFILE "querysense: ". $sentenceObj[$i]->{words}[$j]->{querySense}." ";
			print OUTFILE "predicted: ". $sentenceObj[$i]->{words}[$j]->{predicted}."\n\n";

			# Create SenseClass objects and populate the values
			my $s = $sentenceObj[$i]->{words}[$j]->{querySense};
			my @senses;
			if ($s =~ /(.*?#.*?)#.*/) {
				my $arg = $1;
				@senses = $wn->querySense($arg);
			}
			my $scount = scalar(@senses);
			$sentenceObj[$i]->{words}[$j]->{numberOfSenses} = $scount;
			my $senseid = 0;
			for (my $k=0; $k<scalar(@senses); $k++) { # Loop over sense objects 
				# The condition of the loop makes sure that no sense objects are created
				# for words that have no querySense values i.e. sense objects are created
				# only for n, v, a, r
				print OUTFILE "Sense #". $k."\n\n";
				my $sense = new SenseClass($senses[$k]);
				$sentenceObj[$i]->{words}[$j]->{senses}[$k] = $sense;
				# Pointer to the word the sense belongs to
				$sentenceObj[$i]->{words}[$j]->{senses}[$k]->{word} = \$sentenceObj[$i]->{words}[$j];
				if (($sentenceObj[$i]->{words}[$j]->{senses}[$k]->{id}) == '?') {
					$senseid++;
					$sentenceObj[$i]->{words}[$j]->{senses}[$k]->{id} = "AUTO.".$senseid;
				}
				print OUTFILE $sentenceObj[$i]->{words}[$j]->{senses}[$k]->{id}." ";

				print OUTFILE $sentenceObj[$i]->{words}[$j]->{senses}[$k]->{senseKey}."\n";
			
			}
			
			print OUTFILE "Number of senses for the word= ".$sentenceObj[$i]->{words}[$j]->{numberOfSenses}."\n\n";
			$j++;
			}
		}
		$sentenceObj[$i]->{len} = $j;
		print OUTFILE "Length of the sentence= ".$sentenceObj[$i]->{len}."\n";
		print OUTFILE "============================================================"."\n";
		print OUTFILE "\n\n";			
	}

	@$database = @databaseRef;
	@$senseObjects = @senseObj;
	@$wordObjects = @wordObj;
	@$sentenceObjects = @sentenceObj;
}


close INFILE;
close OUTFILE;
1;

