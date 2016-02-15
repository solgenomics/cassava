	
#!/usr/bin/env perl


=head1 NAME

 UpdateGenotypingExperimentCvterm
 

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all experiments of cvterm type "genotyping experiment" to a "genotyping experiment" cvterm, cv and name dbxref.
This is done to eliminate duplicates of genotyping experiment cvterms loaded previously in the different databases using different cv terms (null, local, experiment_property), making the cvterm name for genotyping experiment more explicit.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "genotyping experiment" causes creating a dbxref.genotyping experiment of "autocreated:genotyping experiment" when creating properties using bio chado schema create_stock function. 
The same genotyping experiment will be attempted to be created when autocreating another property with the name "genotyping experiment".

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateGenotypingExperimentCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create an genotyping experiment cvterm
with cv of experiment genotyping experiment and dbxref of autocreated:
Then all experiment of type_id matching the word genotyping experiment will be associated with the genotyping experiment cvterm
this is important for making experiment genotyping experiment unified across the different databases and eliminating redundancy

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


#find or create cvterm with genotyping experiment name and cv
#make sure it has a dbxref of autocreated:genotyping experiment and db = null
##there might be an existing dbxref with genotyping experiment = autocreated:genotyping experiment
#~ 
    my $coderef = sub {
	
	my $genotyping_experiment_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'genotyping experiment',
      cv     => 'experiment_type',
    });

	my $genotyping_experiment_cvterm_id = $genotyping_experiment_cvterm->cvterm_id;
	print "***genotyping_experiment_cvterm_id is $genotyping_experiment_cvterm_id \n";
	

#find all experiment that have a type_id  ilike %genotyping experiment%' and change it to the 
#experiment genotyping experiment cvterm 
# delete the old cvterm of name and cv name

	my $experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search( 
	    {
		'type.name' => { ilike => 'genotyping experiment%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $experiment->count . " experiment \n\n";
	print "**Changing cvterm name of genotyping experiment , cv= experiment ";
	$experiment->update( { type_id => $genotyping_experiment_cvterm_id});
	
	my $old_cvterm = $schema->resultset("Cv::Cvterm")->search(
		{
		'me.name' => 'genotyping_experiment', 
		'cv.name' => {'!=' => 'experiment_type' },
		},
		{
		join => 'cv'
		}
		);	
	
	$old_cvterm->delete();
	
	#select * from cvterm join cv using (cv_id) where cvterm.name = 'genotyping experiment' and cv.name != 'experiment_type';		
    
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
