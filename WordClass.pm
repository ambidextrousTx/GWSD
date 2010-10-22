# WordClass.pm
#
# DESCRIPTION:
# Derived from the Word class in SenseLearner2.0
#
# Takes input in the Semcor format and creates Word objects for every word. 

package WordClass;

# Constructor for the SemCor version.

sub new {
	my $class = shift;
	my ($string) = @_;
	my $self;
	# Check if current example *seems* valid
	if(!($string =~ /^\<wf/ || $string =~ /^\<punc/)) {
		print STDERR "Invalid line $string\n";
		exit;
    	}
	$self->{senses} = undef;	# An array containing all the senses of the word
	$self->{numberOfSenses} = 0	;# The number of senses this word has
					# Can't be determined here; we need the other values
					# So a method called getLength needs to be written
    	$self->{centrality} = 0; 	# Any centrality measure; could be in-degree or any other
   	$self->{id} = "?";		# An arbitrary id
    	$self->{word} = "?";   		# Word
    	$self->{pos} = "?";    		# Part of speech, Treebank tags
    	$self->{lemma} = "?";  		# Lemma
    	$self->{sense} = "?";  		# lexsn, from WordNet
    	$self->{wnsn} = 0;     		# WordNet sense number, version dependent

    	$self->{predicted} = 0;		# Predicted WordNet sense number, according to the centrality
	
    	# Information for QueryData 
    	$self->{littlePos} = "?"; 	# One letter POS, for QueryData
    	$self->{querySense} = "?";	# querySense format, for QueryData

    	# Punctuation
    	if($string =~ /^\<punc\>([^\<]+)\</) {
		$self->{word} = $1;
		$self->{lemma} = "PUNCT";
		$self->{pos} = "PUNCT";
		$self->{sense} = "?";
    	}
    	# Otherwise, it means it's a word
    	if($string =~ /^\<wf/) {
		if($string =~ /id=([^ \>]*)/) {
	    		$self->{id} = $1;
		}
	    
		if($string =~ /pos=([^ \>]*)/) {
	    		$self->{pos} = $1;
		}

		if($string =~ /lemma=([^ \>]*)/) {
	    		$self->{lemma} = $1;
		}

		if($string =~ /lexsn=([^ \>]*)/) {
	    		$self->{sense} = $self->{lemma}."%".$1;
		}

		if($string=~ /wnsn=([^ \>]*)/) {
	    		$self->{wnsn} = $1;
		}
	
		if($string=~ /\>([^\<]*)/) {
	    		$self->{word} = $1;
		}

    	}

    	# Create a "small case" POS information -- to be used with QueryData
    	if($self->{pos} =~ /(NN|VB|JJ|RB)/) {
		$posid = $1;
		if ($posid eq "NN") {
			$posid = "n";
		}
		elsif ($posid eq "JJ") {
			$posid = "a";
		}
		elsif ($posid eq "RB") {
			$posid = "r";
		}
		elsif ($posid eq "VB") {
			$posid = "v";
		}
		else {
			$posid = "";
		}
		$self->{littlePos} = $posid;
    	} 

    	# Finally create the querySense information -- to be used with QueryData
    	$self->{querySense} = "?";
    	$self->{wnsn} =~ s/\;.*//g;
    	if($self->{sense} =~ /\%(\d)/) {
		$self->{querySense} = $self->{lemma}."#".$self->{littlePos}."#".$self->{wnsn};
    	}
    
    	bless($self, $class);
    
    	return $self;
}


# Destructor.
# nothing for now
sub DESTROY {
}


1;
