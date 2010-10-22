# GraphBuilder.pm
# Author: Ravi S Sinha
# University of North Texas
# Written: Fall 2006
# Updated: Summer 2007

# This module contains the function that builds the graph on word-senses, Word objects or Sentence objects.

#! /usr/bin/perl

sub buildGraph {

	# graphFolder - the folder containing all the graphs
	# graph - the graph objects\ created in the main program; this module is used 
	#	  for populating the graph as well as for calculating similarity 
	#	  measures, building the edges and calculating the centrality
	# type - word senses (WS), Word objects (WO) or Sentence objects (SO)
	# vertices - array of Sentence objects (SO) which contains within arrays of WordClass objects 
	#            and SenseClass objects
	# similarity - lesk or any other similarity measure
	# windowSize - size of the window within which words or sentences are considered
	# partOfSpeech - the part of speech to be considered
	# verbose - whether or not the edges being created should be displayed on the screen
	# arrayRef - a reference to the object which contains everything

	my ($graphFolder, $graph, $verbose, $windowSize, $similarity, $partOfSpeech, $arrayRef) = @_;
	my $type = "WS";
	my @array = @$arrayRef;
	my ($sim, $wn);
	my ($simjcn, $simlesk, $simlch);
	
	if ($similarity =~ /jcn/) {
		use WordNet::Similarity::jcn;
		$wn = WordNet::QueryData->new();
		$sim = WordNet::Similarity::jcn->new($wn);
	}
	elsif ($similarity =~ /lesk/) {
		use WordNet::Similarity::lesk;
		$wn = WordNet::QueryData->new();
		$sim = WordNet::Similarity::lesk->new($wn);
	}
	
  	elsif ($similarity =~ /path/) {
                use WordNet::Similarity::path;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::path->new($wn);
        }

  	elsif ($similarity =~ /hso/) {
                use WordNet::Similarity::hso;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::hso->new($wn);
        }

  	elsif ($similarity =~ /res/) {
                use WordNet::Similarity::res;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::res->new($wn);
        }

  	elsif ($similarity =~ /lin/) {
                use WordNet::Similarity::lin;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::lin->new($wn);
        }

  	elsif ($similarity =~ /lch/) {
                use WordNet::Similarity::lch;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::lch->new($wn);
        }

  	elsif ($similarity =~ /wup/) {
                use WordNet::Similarity::wup;
                $wn = WordNet::QueryData->new();
                $sim = WordNet::Similarity::wup->new($wn);
        }
	elsif ($similarity =~ /ALL/) {
		use WordNet::Similarity::lesk;
		use WordNet::Similarity::jcn;
		use WordNet::Similarity::lch;
		$wn = WordNet::QueryData->new();
		$simlesk = WordNet::Similarity::lesk->new($wn);
		$simjcn = WordNet::Similarity::jcn->new($wn);
		$simlch = WordNet::Similarity::lch->new($wn);
	}
	
	# Add additional similarity measures here in elsif... blocks

	print "OK, done creating all objects!!\n\n";
	my %THE_BIG_HASH = (); # The life blood of the program; hash of arrays
	my ($wordId1, $wordId2);
	print "An object / the objects of WordNet::Similarity::$similarity created. . .\n";

	print "Populating a graph over senses. . .\n";
		
	for (my $i=0; $i<scalar(@array); $i++) { # Iterate over sentences

	 	for (my $j=0; $j<$array[$i]->{len}; $j++) { # Iterate over words	
		$wordId1 = $array[$i]->{words}[$j]->{id};
		# Got one word, need to see all senses of this word and all senses
		# of next l words where l is the window size
		# But the edges built will be added to the hashes for both the senses
		# so we are actually looking both forward and backward
		
	WORK:	for (my $k=0; $k<$array[$i]->{words}[$j]->{numberOfSenses}; $k++) {	
	          my $workSense = $array[$i]->{words}[$j]->{senses}[$k];
		  # print LOG $workSense." ";
		  my $w;
		   if($workSense->{senseKey} =~ /.*#(.*)?#.*/) { $w = $1; }
		   if($partOfSpeech ne 'ALL') {
			 if($w ne $partOfSpeech) {
			  next WORK;
 			 }
		   }
		   $graph->add_vertex($workSense);
				
		   # Loop for drawing all edges coming out of this sense
		   # within a given window 
		   my ($l, $x, $edgeWeight);
		   $edgeWeight = 0;
		   for ($l=1; $l <= $windowSize; $l++) {
		     $x = $j + $l;
		     if(defined($array[$i]->{words}[$x])) {
			$wordId2 = $array[$i]->{words}[$x]->{id};
			# If the window size has not crossed
			# the sentence boundary, get similarity measures
			# with all the senses of this word
		OTHER:  for ($m=0; $m<$array[$i]->{words}[$x]->{numberOfSenses}; $m++) {
			  my $otherSense = $array[$i]->{words}[$x]->{senses}[$m];
			  #if(!($graph->has_vertex($otherSense))) {
				$graph->add_vertex($otherSense);
			  #}
			  my $o;
			  if($otherSense->{senseKey} =~ /.*#(.*)?#.*/) { $o = $1; }
							
			  if (($partOfSpeech ne 'ALL') && ($similarity ne 'ALL')) {
			    if ($o ne $partOfSpeech) {
			      next OTHER;
			    }
			    else {
							
			      $edgeWeight = $sim->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
			    }
			  }
                          elsif (($partOfSpeech ne 'ALL') && ($similarity eq 'ALL')) {
			    print "\nSorry, but a combination of ALL similarity measures with one part of speech is not meaningful. Please try again ...\n"; exit(0);
			  }

			  elsif (($partOfSpeech eq 'ALL') && ($similarity eq 'ALL')) {
			    # Results are being normalized but only for ALL
			    if (($w eq $o) && ($o eq 'n')) {
				$edgeWeight = $simjcn->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>0.2) {
					 $edgeWeight = 0.2;
				}
				$edgeWeight /= 0.2;
							
			    }
			    elsif (($w eq $o) && ($o eq 'v')) {
				$edgeWeight = $simjcn->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>0.2) {
					$edgeWeight = 0.2;
				}
				#$edgeWeight -= 0.34;
				$edgeWeight /= 0.2; 
						
			    }
			    elsif (($w eq $o) && ($o eq 'a')) {
				$edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});

				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
			    }
			    elsif (($w eq $o) && ($o eq 'r')) {
				$edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
			    }
			    elsif ($w ne $o) {
			        $edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
			    }
			  }

			  elsif(($partOfSpeech eq 'ALL') && ($similarity ne 'ALL')) {
				#if (($w eq 'n') || ($w eq 'v')) {
				#if (($o eq 'n') || ($o eq 'v')) {
			          	$edgeWeight = $sim->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				  	($error, $errorString) = $sim->getError();
					die "$errorString\n" if($error);
				#}
				#}
				#else { next OTHER; }
			  }
			  if($verbose) {		
			  print $wordId1." ".$workSense->{senseKey}." - ".$wordId2." ".$otherSense->{senseKey}." edgeWeight = ".$edgeWeight."\n";
		 	  }

			  push @{$THE_BIG_HASH{$wordId1}}, "$wordId1 $workSense->{senseKey} - $wordId2 $otherSense->{senseKey} edgeWeight = $edgeWeight";

			  push @{$THE_BIG_HASH{$wordId2}}, "$wordId2 $otherSense->{senseKey} - $wordId1 $workSense->{senseKey} edgeWeight = $edgeWeight";

                          $graph->add_weighted_edge($workSense, $otherSense, $edgeWeight);
			  # Calculate the indegree centrality here itself
			  $array[$i]->{words}[$j]->{senses}[$k]->{centrality} += $edgeWeight;
			  $array[$i]->{words}[$x]->{senses}[$m]->{centrality} += $edgeWeight;
			} # end iteration over all senses of one word -> m
		      } # end if the current window has not crossed the sentence boundary
		      else {
			# Now, the current window has crossed the sentence boundary
			# Time to transition into the next sentence 
			my $y = $x - $array[$i]->{len};
			$wordId2 = $array[$i+1]->{words}[$y]->{id};

		OTHER:  for ($m=0; $m<$array[$i+1]->{words}[$y]->{numberOfSenses}; $m++) {
                          my $otherSense = $array[$i+1]->{words}[$y]->{senses}[$m];
                          #if(!($graph->has_vertex($otherSense))) {
                             $graph->add_vertex($otherSense);
                          #}
                          my $o;
                          if($otherSense->{senseKey} =~ /.*#(.*)?#.*/) { $o = $1; }
                          my $edgeWeight = 0;

			  if(($partOfSpeech ne 'ALL') && ($similarity ne 'ALL')) {
								 
			    if ($o ne $partOfSpeech) {
				next OTHER;
			    }
			    else {
				$edgeWeight = $sim->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
			    }
                          }

			  elsif (($partOfSpeech ne 'ALL') && ($similarity eq 'ALL')) {
				print "\nSorry, but a combination of ALL similarity measures with one part of speech is not meaningful. Please try again ...\n"; exit(0);
                          }

			  elsif (($partOfSpeech eq 'ALL') && ($similarity eq 'ALL')) {
				 # Results are being normalized but only for ALL
                            if (($w eq $o) && ($o eq 'n')) {
				$edgeWeight = $simjcn->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>0.2) {
					 $edgeWeight = 0.2;
				}
				$edgeWeight /= 0.2;
						
			    }
			    elsif (($w eq $o) && ($o eq 'v')) {
				$edgeWeight = $simjcn->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>0.2) { $edgeWeight = 0.2; }
				$edgeWeight /= 0.2; 
			  					
			    }
			    elsif (($w eq $o) && ($o eq 'a')) {
				$edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
	   		    }
			    elsif (($w eq $o) && ($o eq 'r')) {
				$edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
			    }
			    elsif ($w ne $o) {
		 		$edgeWeight = $simlesk->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				if($edgeWeight>240) { $edgeWeight = 240; }
				$edgeWeight /= 240;
			    }
			  }

                          elsif(($partOfSpeech eq 'ALL') && ($similarity ne 'ALL')) {
				#if(($w eq 'n') || ($w eq 'v')) {
				#if(($o eq 'n') || ($o eq 'v')) {
		 		$edgeWeight = $sim->getRelatedness($workSense->{senseKey}, $otherSense->{senseKey});
				($error, $errorString) = $sim->getError();

  				die "$errorString\n" if($error);
				#}
				#}
				#else {next OTHER;}
			   }

			   if($verbose) {				
                           print $wordId1." ".$workSense->{senseKey}." - ".$wordId2." ".$otherSense->{senseKey}." edgeWeight = ".$edgeWeight."\n";
			   }
			   

			   push @{$THE_BIG_HASH{$wordId1}}, "$wordId1 $workSense->{senseKey} - $wordId2 $otherSense->{senseKey} edgeWeight = $edgeWeight";
			   
			   push @{$THE_BIG_HASH{$wordId2}}, "$wordId2 $otherSense->{senseKey} - $wordId1 $workSense->{senseKey} edgeWeight = $edgeWeight";
                           
                           $graph->add_weighted_edge($workSense, $otherSense, $edgeWeight);
                           $array[$i]->{words}[$j]->{senses}[$k]->{centrality} += $edgeWeight;
			   $array[$i+1]->{words}[$y]->{senses}[$m]->{centrality} += $edgeWeight;
	                 } # end iteration over all senses of one word -> m
         	       } # end else	

		     } # end iteration over all words inside the window -> l
		   } # end interation over senses -> k
		close FILE;

    	  } # end iteration over words -> j	
	} # end iteration over sentences - i
	
	foreach my $id (sort keys %THE_BIG_HASH) {
		
	  open FILE, ">".$graphFolder."/".$id; # We are supposed to be inside a folder at this point of time
	    foreach my $edge (@{$THE_BIG_HASH{$id}}) {
	    print FILE $edge."\n";
	  }
	    close FILE;
	}		
	# print "Done. Please see the graphs in the files named after word IDs ...\n";
	@$arrayRef = @array;
	return ($graph);
}
1;

