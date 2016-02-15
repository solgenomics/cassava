	
#!/usr/bin/env perl


=head1 NAME

 UpdateSnpGenotypeCvterm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stock of cvterm type "snp genotype" to a "snp genotype" cvterm, cv , and name dbxref.
This is done to eliminate duplicates of snp genotype cvterms loaded previously in the different databases using different cv terms (null, local, stock_property), making the cvterm name for snp genotype more explicit.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "snp genotype" causes creating a dbxref.snp genotype of "autocreated:snp genotype" when creating properties using bio chado schema create_stock function. 
The same snp genotyping will be attempted to be created when autocreating another property with the name "snp genotype".

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateSnpGenotypeCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create an snp genotyping cvterm
with cv of stock snp_genotyping and dbxref of autocreated:snp genotyping
Then all stock of type_id matching the word snpgenotyping will be associated with the snp_genotyping cvterm
this is important for making stock snp genotyping unified across the different databases and eliminating redundancy

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


#find or create cvterm with snp genotyping name and cv
#make sure it has a dbxref of autocreated:snp genotyping and db = null
##there might be an existing dbxref with snp genotyping = autocreated:snp genotyping
#~ 
    my $coderef = sub {
	
	my $snp_genotyping_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'snp genotyping',
      cv     => 'genotype_property',
    });

	my $snp_genotyping_cvterm_id = $snp_genotyping_cvterm->cvterm_id;
	print "***snp_genotyping_cvterm_id is $snp_genotyping_cvterm_id \n";
	

#find all stock that have a type_id  ilike %snp_genotyping%' and change it to the 
#stock snp_genotyping cvterm 
# delete the old cvterm of name and cv name

	my $snp_genotyping = $schema->resultset("Stock::Stock")->search( 
	    {
		'type.name' => { ilike => 'snp%genotyping' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $snp_genotyping->count . " snp_genotyping \n\n";
	print "**Changing cvterm name of snp_genotyping , cv= snp genotyping ";
	$snp_genotyping->update( { type_id => $snp_genotyping_cvterm_id});
	
	my $old_cvterm = $schema->resultset("Cv::Cvterm")->search(
		{
		'me.name' => 'snp genotyping', 
		'cv.name' => {'!=' => 'genotype_property' },
		},
		{
		join => 'cv'
		}
		);	c
	
	$old_cvterm->delete();
	
	#select * from cvterm join cv using (cv_id) where cvterm.name = 'snp genotyping' and cv.name != 'local';		
    
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
