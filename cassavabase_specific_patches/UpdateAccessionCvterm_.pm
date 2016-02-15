	
#!/usr/bin/env perl


=head1 NAME

 UpdateAccessionCvterm_

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stock of cvterm type "accession" to a "accession" cvterm, cv , and name dbxref.
This is done to eliminate duplicates of accession cvterms loaded previously in the different databases using different cv terms (null, local, stock_property), making the cvterm name for accession more explicit.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "accession" causes creating a dbxref.accession of "autocreated:accession" when creating properties using bio chado schema create_stock function. 
The same accession will be attempted to be created when autocreating another property with the name "accession".

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>
 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateAccessionCvterm_;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create an accession cvterm
with cv of stock accession and dbxref of autocreated:stock
Then all stock of type_id matching the word accession will be associated with the accession cvterm
this is important for making stock accession unified across the different databases and eliminating redundancy

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


#find or create cvterm with accession name and cv
#make sure it has a dbxref of autocreated:accession and db = null
##there might be an existing dbxref with accession = autocreated:accession
#~ 
    my $coderef = sub {
	
	my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'accession',
      cv     => 'stock_type',
    });

	my $accession_cvterm_id = $accession_cvterm->cvterm_id;
	print "***accession_cvterm_id is $accession_cvterm_id \n";
	

#find all stock that have a type_id  ilike %accession%' and change it to the 
#stock accession cvterm 
# delete the old cvterm of name and cv name

	my $stock = $schema->resultset("Stock::Stock")->search( 
	    {
		'type.name' => { ilike => 'accession%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $stock->count . " stock \n\n";
	print "**Changing cvterm name of accession , cv= stock ";
	$stock->update( { type_id => $accession_cvterm_id});
	
	my $old_cvterm = $schema->resultset("Cv::Cvterm")->search(
		{
		'me.name' => 'accession', 
		'cv.name' => {'!=' => 'stock_type' },
		},
		{
		join => 'cv'
		}
		);	
	
	$old_cvterm->delete();
	
	#select * from cvterm join cv using (cv_id) where cvterm.name = 'accession' and cv.name != 'stock_type';		
    
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
