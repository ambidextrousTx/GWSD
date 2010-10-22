# SentenceClass.pm
# Built on the basis of Word.pm - the word class package in SenseLearner

# Author: Ravi S Sinha
# University of North Texas
# Written: Fall 2006

package SentenceClass;

sub new {
	my $class = shift;
	my ($string) = @_;
	my $self;
	
	$self->{id} = '?'; 		# An arbitrary id for each sentence
	$self->{len} = undef;		# Length of the sentence
	$self->{words} = undef;		# An array of words in the sentence
	$self->{centrality} = undef;	# Any centrality measure as needed

	
 
	bless($self, $class);
    
	return $self;
}
1;

