	
#!/usr/bin/env perl


=head1 NAME

 UpdateTrainingPopulationCvterm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stock of cvterm type "training population" to a "training population" cvterm, cv , and name dbxref.
This is done to eliminate duplicates of training population cvterms loaded previously in the different databases using different cv terms (null, local, stock_property), making the cvterm name for atraining population more explicit.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "training population" causes creating a dbxref.accession of "autocreated:training population" when creating properties using bio chado schema create_stock function. 
The same training population will be attempted to be created when autocreating another property with the name "training population".

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateTrainingPopulationCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create an training population cvterm
with cv of stock training population and dbxref of autocreated:stock
Then all stock of type_id matching the word  training population will be associated with the training population cvterm
this is important for making stock training population unified across the different databases and eliminating redundancy

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


#find or create cvterm with training population name and cv
#make sure it has a dbxref of autocreated:training population and db = null
##there might be an existing dbxref with training = autocreated:training population
#~ 
    my $coderef = sub {
	
	my $training_population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'training population',
      cv     => 'stock_type',
    });

	my $training_population_cvterm_id = $training_population_cvterm->cvterm_id;
	print "***training_population_id is $training_population_cvterm_id \n";
	

#find all stock that have a type_id  ilike %accession%' and change it to the 
#stock accession cvterm 
# delete the old cvterm of name and cv name

	my $stock = $schema->resultset("Stock::Stock")->search( 
	    {
		'type.name' => { ilike => 'training population%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $stock->count . " stock \n\n";
	print "**Changing cvterm name of training population , cv= stock ";
	$stock->update( { type_id => $training_population_cvterm_id});	
	
	my $old_cvterm = $schema->resultset("Cv::Cvterm")->search(
		{
		'me.name' => 'training population', 
		next if ('me.name' != 'training population'){
		'cv.name' => {'!=' => 'stock_type' },
		},
		{
		join => 'cv'
		}
		}
		);	
		

	$old_cvterm->delete();
	
	#select * from cvterm join cv using (cv_id) where cvterm.name = 'training population' and cv.name != 'stock_type';
	
	
	#DETAIL:  Key (organism_id, uniquename, type_id)=(5, global_population_set_2012-2015, 76776) already exists. at UpdateTrainingPopulationCvterm.pm line 101
    
	if ($self->trial) {
            print "Trial mode! Rolling back transaction\n\n";
            $schema->txn_rollback;
	    return 0;
        }
        return 1;
    };

    try {
        $schema->txn_do($coderef);
    
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };
    
    
    print "You're done!\n";
}





####
1; #
####
