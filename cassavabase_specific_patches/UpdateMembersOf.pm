	
#!/usr/bin/env perl


=head1 NAME

 UpdateMembersOf

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stock of cvterm type "members of" to a "members of" cvterm, cv , and name dbxref.
This is done to eliminate duplicates of members of cvterms loaded previously in the different databases using different cv terms (null, local, stock_property), making the cvterm name for members of more explicit.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "members of" causes creating a dbxref.members of "autocreated:members of" when creating properties using bio chado schema create_stock function. 
The same relationship term members of will be attempted to be created when autocreating another property with the name "members of".

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateMembersOf;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create an member of cvterm
with cv of stock member of and dbxref of autocreated:members of
Then all stock of type_id matching the word member of will be associated with the member of cvterm
this is important for making stock member of term unified across the different databases and eliminating redundancy

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


#find or create cvterm with members of name and cv
#make sure it has a dbxref of autocreated:members ofand db = null
##there might be an existing dbxref with members of = autocreated:members of
#~ 
    my $coderef = sub {
	
	my $members_of_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'members of',
      cv     => 'stock_relationship',
    });

	my $members_of_cvterm_id = $members_of_cvterm->cvterm_id;
	print "***members_of_cvterm_id is $members_of_cvterm_id \n";
	

#find all stock that have a type_id  ilike %members of%' and change it to the 
#stock member of cvterm 
# delete the old cvterm of name and cv name

	my $stock = $schema->resultset("Stock::Stock")->search( 
	    {
		'type.name' => { ilike => 'members of%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $stock->count . " stock \n\n";
	print "**Changing cvterm name of members of, cv= stock ";
	$stock->update( { type_id => $members_of_cvterm_id});
	
	my $old_cvterm = $schema->resultset("Cv::Cvterm")->search(
		{
		'me.name' => 'members of', 
		'cv.name' => {'!=' => 'stock_relationship' },
		},
		{
		join => 'cv'
		}
		);	
	
	$old_cvterm->delete();
	
	#select * from cvterm join cv using (cv_id) where cvterm.name = 'members of' and cv.name != 'stock_relationship';		
    
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
