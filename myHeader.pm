# myHeader.pm
# 
# Contains all the 'use'd things
#
# Author: Ravi S Sinha
# University of North Texas
# Written: Fall 2006


#! /usr/bin/perl
use lib './';					# The path of the package
use SenseClass;					# Class representing senses
use WordClass;					# Class representing words
use SentenceClass;				# Class representing sentences
use ObjectBuilder;				# Module that builds the objects
use GraphBuilder;				# Module that builds the graphs
use Methods;					# Module containing all UNIVERSAL methods
use WordNet::QueryData;				
use WordNet::Similarity;
use Graph::Undirected;

my $wnHome = defined($ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/home/public/wordnet2.0/dict"; 
use constant scrWid => 80;
open LOG, ">>log.file";
