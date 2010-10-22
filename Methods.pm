=desc
Methods.pm

Contains the methods for
	Indegree
	TextRank
	Closeness
	Betweenness
	PRF scores for individual systems
	voting

Author: Ravi S Sinha
University of North Texas
Written: Fall 2006
Updated: Summer 2007
=cut

#! /usr/bin/perl

# Subroutine to predict a sense for a word given the indegree centrality values associated with each sense
sub getCentrality {
	my ($i, $j, $arrayRef) = @_;
	my @array = @$arrayRef;
	
	my $predictedSenseNo = 0; # Set the first one as the default
	my $flag = 0; # Has this word been addressed by our method?
	
		# Here the centrality is the sum of edge weights connecting to this vertex
		for (my $k=0; $k<$array[$i]->{words}[$j]->{numberOfSenses}; $k++) { # Iterating over the word's senses
			if($array[$i]->{words}[$j]->{senses}[$k]->{centrality} > 0) { $flag = 1; }  
			# All right, the word has at least one sense with edges coming out of it
			if($array[$i]->{words}[$j]->{senses}[$k]->{centrality} > $array[$i]->{words}[$j]->{senses}[$predictedSenseNo]->{centrality}) {
					$predictedSenseNo = $k;
			}
		}
		# We have obtained the sense number with maximum centrality measure here among the senses
		# This becomes the meaning for the word
		if ($flag==1) {
			$predictedSenseNo++; # This starts from 0, wnsn starts from 1
		}
		@$arrayRef = @array;
		return ($predictedSenseNo);
		
	@$arrayRef = @array;
}

# This method predicts the sense for a word and generates the feature file for indegree centrality
sub getIndegree {
	my ($featureFile, $dataDIR, $arrayRef) = @_;
	my @sentenceObj = @{$arrayRef};
		
	open FEATURES, ">./Features/$featureFile";
	for (my $i=0; $i<scalar(@sentenceObj); $i++) { # Iterate over sentences
		for (my $j=0; $j<$sentenceObj[$i]->{len}; $j++) { # Iterate over words
			#if ($sentenceObj[$i]->{words}[$j]->{wnsn} > 0) {
			
			$sentenceObj[$i]->{words}[$j]->{predicted} = &getCentrality($i, $j, \@sentenceObj);
			if($sentenceObj[$i]->{words}[$j]->{predicted} > 0) {
			print FEATURES "$sentenceObj[$i]->{words}[$j]->{id} $sentenceObj[$i]->{words}[$j]->{predicted}\n";
			}

			# A predicted value of 0 means nothing was predicted
			#}
		}
	}
	@$arrayRef = @sentenceObj;
	close FEATURES;
	&getScoresIndividual($featureFile, $dataDIR);
	return;
}


sub getTextRank {

=desc
Text Rank (implementation provided by Hakan)
Running the weighted PageRank (i.e. TextRank) on a graph obtained
using the Perl module Graph.pl

=formula
R(Vi) = (1 - d) + d * <Sum for all the vertices Vj pointing to Vi> [
	R(Vj) * (Weight of edge <j,i> <divided by> sum of weights of all outgoing edges from Vj) ]

=cut

my ($corpus, $folderName, $featureFile, $dataDIR) = @_;

# Extracting the edges and rebuilding the graph

my $SOURCE_DIR = "$folderName/";

opendir(DIR, $SOURCE_DIR) or die "Could not open dir $SOURCE_DIR - TextRank\n";
my @graphs = grep($_ ne '.' && $_ ne '..' && -f "$SOURCE_DIR\/$_", readdir(DIR));

print "Please wait\n";	
print "Folder where the graphs are located: $SOURCE_DIR\n";

opendir(DIR, $dataDIR) or die "Could not open dir $dataDIR - TextRank\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$dataDIR\/$_", readdir(DIR));

print "Folder where the dataset is located: $dataDIR\n";

# Need a separate hash for each word (word#pos), so the sense with the highest centrality can be chosen
my %scoreHASH = (); # Hash, Key = id number from Semcor, Value = the sense having highest score so far
my %scoreNum = (); # For storing the actual scores
my %idHash = ();

# Need a hash that would have the id as the key and all the senses as the values
# meaning for that id we have those candidates out of which one will be selected
my %HASH = ();
my $name;
my $h;
my $hid = 0;
my $tid;

open CBP, ">./temp/Currently_Being_Processed";

#########################################S T A R T  L O O P#################################################

# Now, need to do the processing for all the graphs 
for (my $i=0; $i<scalar(@graphs); $i++) {
open GRAPH, "$SOURCE_DIR$graphs[$i]";
$tid = $graphs[$i];
# A new graph needs to be built for each word / window
my $g = Graph::Undirected->new();
print CBP $i." ".$graphs[$i]."\n";

$hid = -1;
LINE:
while (my $line = <GRAPH>) {
	chomp($line);
	my ($id, $u, $v, $w, $id2);
	if($line =~ /(.*?)\s(.*?)\s\-\s(.*?)\s(.*?)\sedgeWeight\s=\s(.*)/) {
		$u = $2;
		$v = $4;
		$w = $5;
		$id = $1; 
		$id2 = $3;
# Uncomment the following line if you want to experiment with thresholds while building the graph
#		if($w < 0.40) { next LINE; }
	}
	
	if($w == 0) { next LINE; }	
	if(!$g->has_vertex($u)) {
	$g->add_vertex($u);
	$hid++;
	$g->set_vertex_attribute($u, $name, $id);
	$g->set_vertex_attribute($u, $h, $hid);
	}

	if(!$g->has_vertex($v)) {
	$g->add_vertex($v);
	$hid++;
	$g->set_vertex_attribute($v, $name, $id2);
	$g->set_vertex_attribute($v, $h, $hid);
	}

	$idHash{$u} = $id;
	$idHash{$v} = $id2;
	$g->add_weighted_edge($u, $v, $w);
	if($u =~ /(.*?)\#\d+/) {
		$HASH{$id} = $1; # Not being used really
	}
}

# Preparing input for TextRank
open HIN, ">trgraph.dat";
my @vertices = $g->vertices;
my $vert = $g->vertices;
print HIN $vert."\n";
foreach my $ver (@vertices) { 
	my $temp = $g->get_vertex_attribute($ver, $h);
	print HIN "$ver $temp\n";
	my @in = $g->edges_to($ver);
	print HIN scalar(@in)." ";
	# edges_to/from/at returns an array of all edges
	# each edge is in turn a pair of (u, v)
	foreach my $ein (@in) { 
	my $temp1 = $g->get_vertex_attribute($$ein[0], $h);
	my $temp2 = $g->get_edge_weight($$ein[0], $$ein[1]);
	print HIN "$temp1 $temp2 "; 
	}  # Edges to this point, so this point is [1]
	print HIN "\n";
	my @out = $g->edges_from($ver);
	print HIN scalar(@out)." ";
	foreach my $eout (@out) { 
	my $temp3 = $g->get_vertex_attribute($$eout[1], $h);
	print HIN "$temp3 "; 
	}  # Edges from this point, so this point is [0]
	print HIN "\n";
}
close HIN;

system ('./textRank');

open HOUT, "trout.txt";

# Best to build an intermediate hash out of the result file
my %InterHash = ();
my ($node, $value);
while (my $res = <HOUT>) {
	chomp($res);
	if($res =~ /(.*?)\#(.*?)\#(.*?)/) {
		$node = $res;
		next;
	}
	else {
		$value = $res;
		$InterHash{$node} = $value;
		$scoreNum{$node} = 0;
	}
}

foreach my $key (keys %InterHash) {
	my $id = $idHash{$key};
	if($tid eq $id) {
	if (!defined($scoreHASH{$tid})) {
		if($key =~ /(.*?)\#(.*?)\#(\d+)/) {
			$scoreHASH{$tid} = $3;
			$scoreNum{$tid} = $InterHash{$key};
		}
	}
	elsif ($InterHash{$key} > $scoreNum{$tid}) {
		if($key =~ /(.*?)\#(.*?)\#(\d+)/) {
			$scoreHASH{$tid} = $3;
			$scoreNum{$tid} = $InterHash{$key};
		}			
	}
	}

	}
close HOUT;
close GRAPH;
} # Iteration over all the graphs created ends here

# Generate the feature file now

my %ID_HASH;

print LOG "Checkpoint 5:\nInside the getTextRank routine\n";
print LOG "-" x scrWid ."\n";

foreach my $d(@docs) {
my $file = "$dataDIR$d";
open TESTINFILE, $file;
print LOG "$file\n";
while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				$ID_HASH{$id} = 1;
				
			}
		}
	}
}
close TESTINFILE;
}
				
open FEATURES, ">./Features/$featureFile";
	
# Hashes ready, time to compare and calculate values
foreach my $trkey (keys %ID_HASH) {
	if (defined($scoreHASH{$trkey})) {
		print FEATURES "$trkey $scoreHASH{$trkey}\n";
	}
	else {
	print FEATURES "apparently no keys in the hash";
	}
}


close FEATURES;
&getScoresIndividual($featureFile, $dataDIR);
	
return;

}

sub getBetweenness {

=desc
Graph Betweenness centrality measure
using the Perl module Graph.pl

=cut

my ($corpus, $folderName, $featureFile, $dataDIR) = @_;

# Extracting the edges and rebuilding the graph

my $SOURCE_DIR = "$folderName/";

print "Please wait ... \n";

opendir(DIR, $SOURCE_DIR) or die "Could not open dir $SOURCE_DIR - Betweenness\n";
my @graphs = grep($_ ne '.' && $_ ne '..' && -f "$SOURCE_DIR\/$_", readdir(DIR));
print "The folder where the graphs are located: $SOURCE_DIR\n";

opendir(DIR, $dataDIR) or die "Could not open dir $dataDIR - Betweenness\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$dataDIR\/$_", readdir(DIR));
print "The folder where the dataset(s) is/are located: $dataDIR\n";

# Need a separate hash for each word (word#pos), so the sense with the highest centrality can be chosen
my %scoreHASH = (); # Hash, Key = id number from Semcor, Value = the sense having highest score so far
my %scoreNum = (); # For storing the actual scores
my %idHash = ();

# Need a hash that would have the id as the key and all the senses as the values
# meaning for that id we have those candidates out of which one will be selected
my %HASH = ();
my $name;
my $h;
my $tid;

open CBP, ">./temp/Currently_Being_Processed";

#########################################S T A R T  L O O P#################################################

# Now, need to do the processing for all the graphs 
for (my $i=0; $i<scalar(@graphs); $i++) {

open GRAPH, "$SOURCE_DIR$graphs[$i]";
$tid = $graphs[$i];
# A new graph needs to be built for each word / window
my $g = Graph::Undirected->new();
print CBP $i." ".$graphs[$i]." ".$tid."\n";

LINE:
while (my $line = <GRAPH>) {
	chomp($line);
	my ($id, $u, $v, $w, $id2);
	if($line =~ /(.*?)\s(.*?)\s\-\s(.*?)\s(.*?)\sedgeWeight\s=\s(.*)/) {
		
		$u = $2;
		$v = $4;
		$w = $5;
		$id = $1; 
		$id2 = $3;
	}
	
	if($w == 0) { next LINE; }	
	if(!$g->has_vertex($u)) {
	$g->add_vertex($u);
	$hid++;
	$g->set_vertex_attribute($u, $name, $id);
	}

	if(!$g->has_vertex($v)) {
	$g->add_vertex($v);
	$hid++;
	$g->set_vertex_attribute($v, $name, $id2);
	}

	$idHash{$u} = $id;
	$idHash{$v} = $id2;
	$g->add_weighted_edge($u, $v, $w);
	if($u =~ /(.*?)\#\d+/) {
		$HASH{$id} = $1; # Not being used really
	}
}
print CBP "Graph built\n";

my @vertices = $g->vertices;

# Betweenness
# Implemented using paper from Uni Konstanz
my %CB; 

    my @V  = $g->vertices;
    @CB{@V}=map{0}@V;
    for my $s (@V) {
        my (@S,$P,%sigma,%d,@Q);
        $P->{$_} = [] for (@V);
        @sigma{@V} = map{0}@V; $sigma{$s} = 1;
        @d{@V} = map{-1}@V; $d{$s} = 0;
        push @Q,$s;
        while(@Q) {
            my $v = shift @Q;
            push @S,$v;
            for my $w ($g->neighbors($v)) {
                if($d{$w} < 0) {
                    push @Q,$w;
                    $d{$w} = $d{$v} + 1;
                }
                if($d{$w} == $d{$v} + 1) {
                    $sigma{$w} += $sigma{$v};
                    push @{$P->{$w}},$v;
                }
            }
        }
        my %rho; $rho{$_} = 0 for(@V);
        while(@S) {
            my $w = pop @S;
            for my $v (@{$P->{$w}}) {
                $rho{$v} += ($sigma{$v}/$sigma{$w})*(1+$rho{$w});
            }
            $CB{$w} += $rho{$w} unless $w eq $s;
        }
    }


foreach my $vi (@vertices) {
        my $score = $CB{$vi};
  
        my $id = $g->get_vertex_attribute($vi, $name);
	print Z "$i id=$id tid=$tid \n";
	if ($tid eq $id) {
	if(!defined($scoreHASH{$id})) {
		$scoreNum{$id} = $score;
		if($vi =~ /(.*?)\#(.*?)\#(\d+)/) {
			$scoreHASH{$id} = $3;
		}
	}
	else {
		if($scoreNum{$id} < $score) {
			$scoreNum{$id} = $score;
			if($vi =~ /(.*?)\#(.*?)\#(\d+)/) {
				$scoreHASH{$id} = $3;
			}
	}
	}
}

close GRAPH;
}
} # Iteration over all the graphs created ends here
close CBP;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;

# Generate the feature file now

my %ID_HASH;

foreach my $d(@docs) {
open TESTINFILE, $dataDIR."$d";
while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				$ID_HASH{$id} = 1;
			}
		}
	}
}
close TESTINFILE;
}
				
open FEATURES, ">./Features/$featureFile";
	
# Hashes ready, time to compare and calculate values
foreach my $trkey (keys %ID_HASH) {
	if (defined($scoreHASH{$trkey})) {
		print FEATURES "$trkey $scoreHASH{$trkey}\n";
	}
}
close FEATURES;
&getScoresIndividual($featureFile, $dataDIR);

return;

}

sub getCloseness {

=desc
Graph Closeness centrality measure
using the Perl module Graph.pl

=cut

my ($corpus, $folderName, $featureFile, $dataDIR) = @_;

# Extracting the edges and rebuilding the graph


my $SOURCE_DIR = "$folderName/";

opendir(DIR, $SOURCE_DIR) or die "Could not open dir $SOURCE_DIR - Closeness\n";
my @graphs = grep($_ ne '.' && $_ ne '..' && -f "$SOURCE_DIR\/$_", readdir(DIR));

opendir(DIR, $dataDIR) or die "Could not open dir $dataDIR - Closeness\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$dataDIR\/$_", readdir(DIR));


# Need a separate hash for each word (word#pos), so the sense with the highest centrality can be chosen
my %scoreHASH = (); # Hash, Key = id number from Semcor, Value = the sense having highest score so far
my %scoreNum = (); # For storing the actual scores
my %idHash = ();

# Need a hash that would have the id as the key and all the senses as the values
# meaning for that id we have those candidates out of which one will be selected
my %HASH = ();
my $name;
my $h;
my $tid;

open CBP, ">./temp/Currently_Being_Processed";

#########################################S T A R T  L O O P#################################################

# Now, need to do the processing for all the graphs 
for (my $i=0; $i<scalar(@graphs); $i++) {

open GRAPH, "$SOURCE_DIR$graphs[$i]";
$tid = $graphs[$i]; # id of the word to be disambiguated
# A new graph needs to be built for each word / window
my $g = Graph::Undirected->new();
print CBP $i." ".$graphs[$i]." ".$tid."\n";

LINE:
while (my $line = <GRAPH>) {
	chomp($line);
	my ($id, $u, $v, $w, $id2);
	if($line =~ /(.*?)\s(.*?)\s\-\s(.*?)\s(.*?)\sedgeWeight\s=\s(.*)/) {
		
		$u = $2;
		$v = $4;
		$w = $5;
		$id = $1; 
		$id2 = $3;
		if($w <= 0) { next LINE; } # No threshold but still cannot take negative edges!!
	}
	
	if($w == 0) { next LINE; }	
	if(!$g->has_vertex($u)) {
	$g->add_vertex($u);
	$hid++;
	$g->set_vertex_attribute($u, $name, $id);
	#$g->set_vertex_attribute($u, $h, $hid);

	#NOTE: adding two attributes to one vertex messes things up
	}

	if(!$g->has_vertex($v)) {
	$g->add_vertex($v);
	$hid++;
	$g->set_vertex_attribute($v, $name, $id2);
	#$g->set_vertex_attribute($v, $h, $hid);
	}

	$idHash{$u} = $id;
	$idHash{$v} = $id2;
	$g->add_weighted_edge($u, $v, $w);
	if($u =~ /(.*?)\#\d+/) {
		$HASH{$id} = $1; # Not being used really
	}
}
print CBP "Graph built\n";

my @vertices = $g->vertices;

foreach my $vi (@vertices) {
        my $score = 0;

        # Closeness of a vertex
        # is equal to the sum of all the shortest path distances from this node
        # to every other node in the graph

	
        my $id = $g->get_vertex_attribute($vi, $name);
	print Z "$i id=$id tid=$tid \n";
	#print CBP "there we are \n";
	if ($tid eq $id) {  # This means this is the one we are disambiguating!!
		my $vertex = $vi;
    		my $sp = $g->SPT_Dijkstra(first_root => $vertex);
    		my $s = 0;
    		for($g->vertices) {
        		$s += $sp->path_length($vertex,$_) || 0;
    		}
		if($s != 0) { $score = 1/$s; 
		} else { $score = 0; }
	
		if(!defined($scoreHASH{$id})) {
		$scoreNum{$id} = $score;
		if($vi =~ /(.*?)\#(.*?)\#(\d+)/) {
			$scoreHASH{$id} = $3;
		}
		}
		else {
		if($scoreNum{$id} < $score) {
			$scoreNum{$id} = $score;
			if($vi =~ /(.*?)\#(.*?)\#(\d+)/) {
				$scoreHASH{$id} = $3;
			}
		}
		}
	}

close GRAPH;
}
} # Iteration over all the graphs created ends here

close CBP;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;

# Generate the feature file now

my %ID_HASH;

foreach my $d(@docs) {
open TESTINFILE, $dataDIR."$d";
while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				$ID_HASH{$id} = 1;
			}
		}
	}
}
close TESTINFILE;
}
				
open FEATURES, ">./Features/$featureFile";
	
# Hashes ready, time to compare and calculate values
foreach my $trkey (keys %ID_HASH) {
	if (defined($scoreHASH{$trkey})) {
		print FEATURES "$trkey $scoreHASH{$trkey}\n";
	}
}
close FEATURES;
&getScoresIndividual($featureFile, $dataDIR);

return;

}

# The following method calculates the PRF measures for the individual methods;
# This method is called by Indegree, PageRank, Closeness, Betweenness etc. with the feature file and the test file ( the corpus file )

sub getScoresIndividual {

# Check the value in the original data file (match the ids) 
# Generate an output file with (id, selected candidate sense number) pair
# get P, R and F

my ($featureFile, $dataDIR) = @_; 

my $tpn = 0;
my $tpv = 0;
my $tpa = 0;
my $tpr = 0;
my $tp = 0;
my $denRecalln = 0;
my $denRecallv = 0;
my $denRecalla = 0;
my $denRecallr = 0;
my $denRecall = 0;
my $denPrecn = 0;
my $denPrecv = 0;
my $denPreca = 0;
my $denPrecr = 0;
my $denPrec = 0;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;
my $senseTagCounter = 0; # Counter to keep track of whether the dataset has sense tags or not

opendir(DIR, $dataDIR) or die "Could not open dir $dataDIR - individual scoring\nSystem says: $!\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$dataDIR\/$_", readdir(DIR));

print LOG "Checkpoint 6\nInside the getScoresIndividual routine\n";
print LOG "dataDIR $dataDIR featureFile $featureFile\n";
print LOG "-" x scrWid ."\n";

foreach my $d(@docs) {
my $file = "$dataDIR$d";
open TESTINFILE, "$file";
print LOG $file."\n";
while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$senseTagCounter++;
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				
				if ($a =~ /pos=NN/) {
				$denRecalln++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'n';
				$SENSE_HASH{$id} = $sense;
			
				}

				elsif ($a =~ /pos=VB/) {
				$denRecallv++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'v';
				$SENSE_HASH{$id} = $sense;

				}

				elsif ($a =~ /pos=JJ/) {
				$denRecalla++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'a';
				$SENSE_HASH{$id} = $sense;

				}

				elsif ($a =~ /pos=RB/) {
				$denRecallr++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'r';
				$SENSE_HASH{$id} = $sense;

				}

			}
		}
		
	}
}
close TESTINFILE;
print LOG "-" x scrWid ."\n";
}

open FEATURES, "./Features/$featureFile";

# Need to create a hash from the feature file too

my %FeatureHash = ();
while (my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$FeatureHash{$arr[0]} = $arr[1];
}
	
# Here we are creating the output file in the XML format, for the case when there are no sense tags in the dataset
unless ($senseTagCounter) {
	# Execute all this unless the counter is greater than 0 (there was at least one sense tag in the input data set)
	open OUT, ">$featureFile.out";
	print  "The dataset you provided does not have any sense tags. So it is not possible to calculate the PRF scores \nfor this dataset. Instead, a new file is generated for you under the name of $featureFile.out, where you \ncan see all the tags that have been assigned by this centrality metric.\n";
	foreach my $d(@docs) {
	 my $file = "$dataDIR$d";
	 open TESTINFILE, "$file";
	 
	 while (my $l = <TESTINFILE>) {
	   chomp($l);
	   if ($l =~ /id=(.*?)\s/) {
	     $l =~ s/id=(.*?)\s/id=$1 wnsn=$FeatureHash{$1} /;
	   }
	   print OUT $l."\n";
 	 }
	 close TESTINFILE;
	}
	close OUT;
	exit(1);	
}

# If we are here it means there were some sense tags in the data set, in which case we can calculate the scores
# Hashes ready, time to compare and calculate values
foreach my $trkey (keys %ID_HASH) {
	if (defined($FeatureHash{$trkey})) {
		
		if ($POS_HASH{$trkey} eq 'n') {
			$denPrecn++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpn++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'v') {
			$denPrecv++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpv++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'a') {
			$denPreca++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpa++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'r') {
			$denPrecr++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpr++;
				
			}
		}
	}
}
			
$tp = $tpn+$tpv+$tpr+$tpa;
$denRecall = $denRecalln+$denRecallv+$denRecallr+$denRecalla;
$denPrec = $denPrecn+$denPrecv+$denPrecr+$denPreca;

open FINAL, ">./Scores/$featureFile.Scores";

print FINAL "True positives = \n";
print FINAL "n\tv\ta\tr\tall\n$tpn\t$tpv\t$tpa\t$tpr\t$tp\n";
print FINAL "denRecall = \n";
print FINAL "n\tv\ta\tr\tall\n$denRecalln\t$denRecallv\t$denRecalla\t$denRecallr\t$denRecall\n";
print FINAL "denPrecision = \n";
print FINAL "n\tv\ta\tr\tall\n$denPrecn\t$denPrecv\t$denPreca\t$denPrecr\t$denPrec\n";
print FINAL "P = \n";
print FINAL "n\tv\ta\tr\n";
if($denPrecn!=0) {
print FINAL $tpn/$denPrecn."\t";
}
else {
print FINAL "0.00"."\t";
}
if($denPrecv!=0) {
print FINAL $tpv/$denPrecv."\t";
}
else {
print FINAL "0.00"."\t";
}
if($denPreca!=0) {
print FINAL $tpa/$denPreca."\t";
}
else {
print FINAL "0.00"."\t";
}
if($denPrecr!=0) {
print FINAL $tpr/$denPrecr."\n";
}
else {
print FINAL "0.00"."\n";
}
print FINAL "Overall P =\n";
my $prec;
if($denPrec!=0) {
$prec = $tp / $denPrec;
}
else {
$prec = 0.00;
}
print FINAL "$prec\n";
print FINAL "R = \n";
print FINAL "n\tv\ta\tr\n".$tpn/$denRecalln."\t".$tpv/$denRecallv."\t".$tpa/$denRecalla."\t".$tpr/$denRecallr."\n";
print FINAL "Overall R =\n";
my $recall = $tp / $denRecall;
print FINAL "$recall\n";
print FINAL "Overall F = \n";
if(0 != $prec + $recall) {
   my $f = (2*$prec*$recall) / ($prec + $recall);
   print FINAL "$f\n";
}
else {
   print FINAL "0\n";
}
close FINAL;

return;
}

# This method calculates the PRF for the voting methods

sub getScores {

# Check the value in the original data file (match the ids) 
# Generate an output file with (id, selected candidate sense number) pair
# get P, R and F

my ($featureFile, $dataDIR) = @_; 

my $tpn = 0;
my $tpv = 0;
my $tpa = 0;
my $tpr = 0;
my $tp = 0;
my $denRecalln = 0;
my $denRecallv = 0;
my $denRecalla = 0;
my $denRecallr = 0;
my $denRecall = 0;
my $denPrecn = 0;
my $denPrecv = 0;
my $denPreca = 0;
my $denPrecr = 0;
my $denPrec = 0;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;
my $senseTagCounter = 0; # Counter to keep track of whether the dataset has sense tags or not

opendir(DIR, $dataDIR) or die "Could not open dir $dataDIR - individual scoring\nSystem says: $!\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$dataDIR\/$_", readdir(DIR));

print LOG "Checkpoint 6\nInside the getScores routine\n";
print LOG "dataDIR $dataDIR featureFile $featureFile\n";
print LOG "-" x scrWid ."\n";

foreach my $d(@docs) {
my $file = "$dataDIR$d";
open TESTINFILE, "$file";
print LOG $file."\n";
while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$senseTagCounter++;
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				
				if ($a =~ /pos=NN/) {
				$denRecalln++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'n';
				$SENSE_HASH{$id} = $sense;
			
				}

				elsif ($a =~ /pos=VB/) {
				$denRecallv++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'v';
				$SENSE_HASH{$id} = $sense;

				}

				elsif ($a =~ /pos=JJ/) {
				$denRecalla++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'a';
				$SENSE_HASH{$id} = $sense;

				}

				elsif ($a =~ /pos=RB/) {
				$denRecallr++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'r';
				$SENSE_HASH{$id} = $sense;

				}

			}
		}
		
	}
}
close TESTINFILE;
print LOG "-" x scrWid ."\n";
}

open FEATURES, "./Features/$featureFile";

# Need to create a hash from the feature file too

my %FeatureHash = ();
while (my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$FeatureHash{$arr[0]} = $arr[1];
}
	
# Here we are creating the output file in the XML format, for the case when there are no sense tags in the dataset
unless ($senseTagCounter) {
	# Execute all this unless the counter is greater than 0 (there was at least one sense tag in the input data set)
	open OUT, ">$featureFile.out";
	print  "The dataset you provided does not have any sense tags. So it is not possible to calculate the PRF scores \nfor this dataset. Instead, a new file is generated for you under the name of $featureFile.out, where you \ncan see all the tags that have been assigned by this centrality metric.\n";
	foreach my $d(@docs) {
	 my $file = "$dataDIR$d";
	 open TESTINFILE, "$file";
	 
	 while (my $l = <TESTINFILE>) {
	   chomp($l);
	   if ($l =~ /id=(.*?)\s/) {
	     $l =~ s/id=(.*?)\s/id=$1 wnsn=$FeatureHash{$1} /;
	   }
	   print OUT $l."\n";
 	 }
	 close TESTINFILE;
	}
	close OUT;
	exit(1);	
}

# If we are here it means there were some sense tags in the data set, in which case we can calculate the scores
# Hashes ready, time to compare and calculate values
foreach my $trkey (keys %ID_HASH) {
	if (defined($FeatureHash{$trkey})) {
		
		if ($POS_HASH{$trkey} eq 'n') {
			$denPrecn++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpn++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'v') {
			$denPrecv++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpv++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'a') {
			$denPreca++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpa++;
				
			}
		}
		elsif ($POS_HASH{$trkey} eq 'r') {
			$denPrecr++;
			if ($SENSE_HASH{$trkey} eq $FeatureHash{$trkey}) {
				$tpr++;
				
			}
		}
	}
}
			
$tp = $tpn+$tpv+$tpr+$tpa;
$denRecall = $denRecalln+$denRecallv+$denRecallr+$denRecalla;
$denPrec = $denPrecn+$denPrecv+$denPrecr+$denPreca;

print FINAL "True positives = \n";
print FINAL "n\tv\ta\tr\tall\n$tpn\t$tpv\t$tpa\t$tpr\t$tp\n";
print FINAL "denRecall = \n";
print FINAL "n\tv\ta\tr\tall\n$denRecalln\t$denRecallv\t$denRecalla\t$denRecallr\t$denRecall\n";
print FINAL "denPrecision = \n";
print FINAL "n\tv\ta\tr\tall\n$denPrecn\t$denPrecv\t$denPreca\t$denPrecr\t$denPrec\n";
print FINAL "P = \n";
print FINAL "n\tv\ta\tr\n".$tpn/$denPrecn."\t".$tpv/$denPrecv."\t".$tpa/$denPreca."\t".$tpr/$denPrecr."\n";
print FINAL "Overall P =\n";
my $prec = $tp / $denPrec;
print FINAL "$prec\n";
print FINAL "R = \n";
print FINAL "n\tv\ta\tr\n".$tpn/$denRecalln."\t".$tpv/$denRecallv."\t".$tpa/$denRecalla."\t".$tpr/$denRecallr."\n";
print FINAL "Overall R =\n";
my $recall = $tp / $denRecall;
print FINAL "$recall\n";
print FINAL "Overall F = \n";
my $f = (2*$prec*$recall) / ($prec + $recall);
print FINAL "$f\n";

return;
}



sub vote2 {

my ($file0, $file1, $corpus, $pathToCorpus) = @_;
my $DIR;
# print $pathToCorpus." ".$corpus."\n"; # OK, the values are being passed
if(($corpus eq 'Senseval-2') || ($corpus eq 'Senseval-3')) {
open DATAIN, "GWSD.conf";
while(my $line = <DATAIN>) {
	my @arr = split /\s+/, $line;
	if($corpus eq $arr[0]) {
		$DIR = $arr[1];
	}
}
close DATAIN;
}

elsif(defined($pathToCorpus)) {
	$DIR = $pathToCorpus;
}
else {
	print "Error: you did not provide the name of the folder where the corpus is located ...\n";
	exit(1);
}

print LOG "Checkpoint 9: Inside the vote method\nThe files opened for evaluation are in the folder:\n$DIR\n";
print LOG '-' x ScrWid . "\n";
print "This is the new improved voting scheme! Voting between only indegree and textrank\n";

my $tpn = 0;
my $tpv = 0;
my $tpa = 0;
my $tpr = 0;
my $denRecalln = 0;
my $denRecallv = 0;
my $denRecalla = 0;
my $denRecallr = 0;
my $denPrecn = 0;
my $denPrecv = 0;
my $denPreca = 0;
my $denPrecr = 0;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;

open CORRECT, ">./temp/Correct_features";

opendir(DIR, $DIR) or die "Could not open dir $DIR - voting2\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$DIR\/$_", readdir(DIR));

foreach my $d(@docs) {
open TESTINFILE, $DIR."$d";


while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				
				if ($a =~ /pos=NN/) {
				$denRecalln++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'n';
				$SENSE_HASH{$id} = $sense;
				
				}

				elsif ($a =~ /pos=VB/) {
				$denRecallv++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'v';
				$SENSE_HASH{$id} = $sense;
				}

				elsif ($a =~ /pos=JJ/) {
				$denRecalla++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'a';
				$SENSE_HASH{$id} = $sense;
				}

				elsif ($a =~ /pos=RB/) {
				$denRecallr++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'r';
				$SENSE_HASH{$id} = $sense;
				}

			}
		}
	}
}
close TESTINFILE;
}

my %IndegreeHASH;
my %TextRankHASH;

open FEATURES, "./Features/$file0";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$IndegreeHASH{$arr[0]} = $arr[1];
}

close FEATURES;

open FEATURES, "./Features/$file1";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$TextRankHASH{$arr[0]} = $arr[1];
}
close FEATURES;

foreach my $kkey (keys %ID_HASH) {
	print CORRECT $kkey." ".$SENSE_HASH{$kkey}."\n";
}
close CORRECT;

# Hashes ready, time to compare and calculate values

foreach my $key(keys %ID_HASH) {
if  
( defined($IndegreeHASH{$key}) and defined($TextRankHASH{$key}) and ($IndegreeHASH{$key} eq $TextRankHASH{$key}) ){ 
if ($POS_HASH{$key} eq 'n') { $denPrecn++; }
elsif ($POS_HASH{$key} eq 'v') { $denPrecv++; }
elsif ($POS_HASH{$key} eq 'a') { $denPreca++; }
elsif ($POS_HASH{$key} eq 'r') { $denPrecr++; }
}
}

# Build the combined hash for all the ids (words)

my %THE_HASH = ();
foreach my $k (keys %ID_HASH) {

if(defined($IndegreeHASH{$k})) { push @{$THE_HASH{$k}}, $IndegreeHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }
if(defined($TextRankHASH{$k})) { push @{$THE_HASH{$k}}, $TextRankHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }

}

# Would like to see how the thing looks like
open ISR, ">./temp/Sys_Res_Ind";
foreach my $k1 (keys %THE_HASH) {
 if(defined($THE_HASH{$k1})) {
 print ISR $k1." ";
 foreach my $entry ( @{$THE_HASH{$k1}} ) {
  print ISR $entry." "; 
 }
 print ISR "\n";
}}
close ISR;
open CHECK, ">./temp/C";

my $t = "TEMP";
open FINAL, ">./Scores/Voting.Scores";
# Now, take two at a time and predict senses:

print FINAL "Indegree and TextRank\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($IndegreeHASH{$key}) and defined($TextRankHASH{$key}) and ($IndegreeHASH{$key} eq $TextRankHASH{$key})) {
		print TEMP "$key $IndegreeHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

close FINAL;
return;

}

sub vote {

my ($file0, $file1, $file2, $file3, $corpus, $pathToCorpus) = @_;
my $DIR;
# print $pathToCorpus." ".$corpus."\n"; # OK, the values are being passed
if(($corpus eq 'Senseval-2') || ($corpus eq 'Senseval-3')) {
open DATAIN, "GWSD.conf";
while(my $line = <DATAIN>) {
	my @arr = split /\s+/, $line;
	if($corpus eq $arr[0]) {
		$DIR = $arr[1];
	}
}
close DATAIN;
}

elsif(defined($pathToCorpus)) {
	$DIR = $pathToCorpus;
}
else {
	print "Error: you did not provide the name of the folder where the corpus is located ...\n";
	exit(1);
}

print LOG "Checkpoint 9: Inside the vote method\nThe files opened for evaluation are in the folder:\n$DIR\n";
print LOG '-' x ScrWid . "\n";

my $tpn = 0;
my $tpv = 0;
my $tpa = 0;
my $tpr = 0;
my $denRecalln = 0;
my $denRecallv = 0;
my $denRecalla = 0;
my $denRecallr = 0;
my $denPrecn = 0;
my $denPrecv = 0;
my $denPreca = 0;
my $denPrecr = 0;

my %ID_HASH;
my %POS_HASH;
my %SENSE_HASH;

open CORRECT, ">./temp/Correct_features";

opendir(DIR, $DIR) or die "Could not open dir $DIR - voting\n";
my @docs=grep($_ ne '.' && $_ ne '..' && -f "$DIR\/$_", readdir(DIR));

foreach my $d(@docs) {
open TESTINFILE, $DIR."$d";


while (my $l = <TESTINFILE>) {
	chomp($l);
	my ($id, $sense);
	my $a = $l;
	if ($a =~ /id=(.*?)\s/) { 
		$id = $1;
		if ($a =~ /wnsn=(\d+)\s/) {
			$sense = $1;
			if($sense =~ /(\d+);(\d+)/) { $sense = $1; } # Some wnsn senses are like 7;1 etc.
			if($sense > 0) {
				
				if ($a =~ /pos=NN/) {
				$denRecalln++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'n';
				$SENSE_HASH{$id} = $sense;
				
				}

				elsif ($a =~ /pos=VB/) {
				$denRecallv++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'v';
				$SENSE_HASH{$id} = $sense;
				}

				elsif ($a =~ /pos=JJ/) {
				$denRecalla++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'a';
				$SENSE_HASH{$id} = $sense;
				}

				elsif ($a =~ /pos=RB/) {
				$denRecallr++;
				$ID_HASH{$id} = 1;
				$POS_HASH{$id} = 'r';
				$SENSE_HASH{$id} = $sense;
				}

			}
		}
	}
}
close TESTINFILE;
}

my %IndegreeHASH;
my %TextRankHASH;
my %BWHASH;
my %CLHASH;

open FEATURES, "./Features/$file0";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$IndegreeHASH{$arr[0]} = $arr[1];
}

close FEATURES;

open FEATURES, "./Features/$file1";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$TextRankHASH{$arr[0]} = $arr[1];
}
close FEATURES;

open FEATURES, "./Features/$file2";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$BWHASH{$arr[0]} = $arr[1];
}
close FEATURES;

open FEATURES, "./Features/$file3";
while(my $line = <FEATURES>) {
chomp($line);
my @arr = split /\s+/, $line;
$CLHASH{$arr[0]} = $arr[1];
}

close FEATURES;

foreach my $kkey (keys %ID_HASH) {
	print CORRECT $kkey." ".$SENSE_HASH{$kkey}."\n";
}
close CORRECT;

# Hashes ready, time to compare and calculate values

foreach my $key(keys %ID_HASH) {
if ( 
( defined($IndegreeHASH{$key}) and defined($TextRankHASH{$key}) and ($IndegreeHASH{$key} eq $TextRankHASH{$key}) ) 
|| 
( defined($IndegreeHASH{$key}) and defined($BWHASH{$key}) and ($IndegreeHASH{$key} eq $BWHASH{$key} ) )
|| 
( defined($IndegreeHASH{$key}) and defined($CLHASH{$key}) and ($IndegreeHASH{$key} eq $CLHASH{$key} ) )
|| 
( defined($TextRankHASH{$key}) and defined($BWHASH{$key}) and ($TextRankHASH{$key} eq $BWHASH{$key} ) )
|| 
( defined($TextRankHASH{$key}) and defined($CLHASH{$key}) and ($TextRankHASH{$key} eq $CLHASH{$key} ) )
|| 
( defined($BWHASH{$key}) and defined($CLHASH{$key}) and ($BWHASH{$key} eq $CLHASH{$key} ) )
||
( defined($IndegreeHASH{$key}) )
) {
if ($POS_HASH{$key} eq 'n') { $denPrecn++; }
elsif ($POS_HASH{$key} eq 'v') { $denPrecv++; }
elsif ($POS_HASH{$key} eq 'a') { $denPreca++; }
elsif ($POS_HASH{$key} eq 'r') { $denPrecr++; }
}
}

# Build the combined hash for all the ids (words)

my %THE_HASH = ();
foreach my $k (keys %ID_HASH) {

if(defined($IndegreeHASH{$k})) { push @{$THE_HASH{$k}}, $IndegreeHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }
if(defined($TextRankHASH{$k})) { push @{$THE_HASH{$k}}, $TextRankHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }
if(defined($BWHASH{$k})) { push @{$THE_HASH{$k}}, $BWHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }
if(defined($CLHASH{$k})) { push @{$THE_HASH{$k}}, $CLHASH{$k}; } else { push @{$THE_HASH{$k}}, '0'; }

}

# Would like to see how the thing looks like
open ISR, ">./temp/Sys_Res_Ind";
foreach my $k1 (keys %THE_HASH) {
 if(defined($THE_HASH{$k1})) {
 print ISR $k1." ";
 foreach my $entry ( @{$THE_HASH{$k1}} ) {
  print ISR $entry." "; 
 }
 print ISR "\n";
}}
close ISR;
open CHECK, ">./temp/C";

my $t = "TEMP";
open FINAL, ">./Scores/Voting.Scores";
# Now, take two at a time and predict senses:

print FINAL "Indegree and TextRank\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($IndegreeHASH{$key}) and defined($TextRankHASH{$key}) and ($IndegreeHASH{$key} eq $TextRankHASH{$key})) {
		print TEMP "$key $IndegreeHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

print FINAL "Indegree and Betweenness\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($IndegreeHASH{$key}) and defined($BWHASH{$key}) and ($IndegreeHASH{$key} eq $BWHASH{$key})) {
		print TEMP "$key $IndegreeHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

print FINAL "Indegree and Closeness\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($IndegreeHASH{$key}) and defined($CLHASH{$key}) and ($IndegreeHASH{$key} eq $CLHASH{$key})) {
		print TEMP "$key $IndegreeHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

print FINAL "TextRank and Betweenness\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($BWHASH{$key}) and defined($TextRankHASH{$key}) and ($BWHASH{$key} eq $TextRankHASH{$key})) {
		print TEMP "$key $TextRankHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

print FINAL "TextRank and Closeness\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($CLHASH{$key}) and defined($TextRankHASH{$key}) and ($CLHASH{$key} eq $TextRankHASH{$key})) {
		print TEMP "$key $CLHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);

print FINAL "Betweenness and Closeness\n";
open TEMP, ">./Features/$t";
foreach my $key( keys %SENSE_HASH ) {
	if(defined($BWHASH{$key}) and defined($CLHASH{$key}) and ($BWHASH{$key} eq $CLHASH{$key})) {
		print TEMP "$key $CLHASH{$key}\n";
	}
}
close TEMP;
&getScores($t, $DIR);


close FINAL;
return;

}
1;
