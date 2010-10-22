# SenseClass.pm
#
# DESCRIPTION:
#
# A class representing one individual sense of a given word
# Takes help from the WordClass class in that the values are
# 	computed in the WordClass class and from there the
# 	SenseClass objects are constructed

package SenseClass;


# Constructor
sub new {

	my $class = shift;
	my ($string) = @_;
	my $self;
   	$self->{id} = '?';		# An arbitrary id
	$self->{word} = undef;		# A pointer to the WordClass to which this sense belongs
    	$self->{senseKey} = undef;	# Sense key according to WordNet: word#pos#sense
	$self->{lemma} = undef;
	$self->{centrality} = 0;	# The centrality for the Sense - could be indegree

	# Assign the values now
	$self->{senseKey} = $string;

	if ($string =~ /(.*)#.*#.*/) {
		$self->{lemma} = $1;	# The senseKey is derived from the WordClass->{querySense}
					# And thus takes the lemma, not the word
	}

	bless($self, $class);
	return $self;	

}

# Destructor
# nothing for now
sub DESTROY {
}

1;
