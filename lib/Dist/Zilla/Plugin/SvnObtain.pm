package Dist::Zilla::Plugin::SvnObtain;
# ABSTRACT: obtain files from a subversion repository before building a distribution

use SVN::Client;
use File::Path qw/ make_path remove_tree /;
use Cwd;
use Moose;
use namespace::autoclean;

with 'Dist::Zilla::Role::Plugin';
with 'Dist::Zilla::Role::BeforeBuild';

has 'svn_dir' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => 'src',
);

has _repos => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
    default => sub { {} },
);

sub BUILDARGS {
    my $class = shift;
    my %repos = ref($_[0]) ? %{$_[0]} : @_;

    my $zilla = delete $repos{zilla};
    my $svn_dir = delete $repos{plugin_name};
    $svn_dir = '.' if $svn_dir eq 'SvnObtain';

    my %args;
    for my $project (keys %repos) {
        if ($project =~ /^--/) {
            (my $arg = $project) =~ s/^--//; $args{$arg} = delete $repos{$project}; next;
        }
        my ($url,$rev) = split ' ', $repos{$project};
        $rev = 'HEAD' unless $rev;
        $repos{$project} = { url => $url, rev => $rev };
    }

    return {
        zilla => $zilla,
        plugin_name => 'SvnObtain',
        _repos => \%repos,
        svn_dir => $svn_dir,
        %args,
    };
}

sub before_build {
    my $self = shift;

    if (-d $self->svn_dir) {
        $self->log("using existing directory " . $self->svn_dir);
    } else {
        $self->log("creating directory " . $self->svn_dir);
        make_path($self->svn_dir);
    }
    my $prev_dir = getcwd;
    chdir($self->svn_dir) or die "Can't change to the " . $self->svn_dir . " directory -- $!";
    for my $project (keys %{$self->_repos}) {
        my ($url,$rev) = map { $self->_repos->{$project}{$_} } qw/url rev/;
        $self->log("checking out $project revision $rev");
        my $svn = SVN::Client->new;
        $svn->checkout($url, $project, $rev, 1);
    }
    chdir($prev_dir) or die "Can't change back to the $prev_dir directory -- $!";
}


__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::SvnObtain - obtain files from a subversion repository before building a distribution

=head1 SYNOPSIS

In your F<dist.ini>:

  [SvnObtain]
    ;subdir = url                                   revision
    parrot  = https://svn.parrot.org/parrot/trunk   48152

  [SvnObtain/path/to/some/other/dir]
    blah = http://svn.example.com/repos/my-project

=head1 DESCRIPTION

Uses L<SVN::Client> to obtain files from a subversion repository for
inclusion in a distribution made with L<Dist::Zilla>.

C<[SvnObtain]> sections in your F<dist.ini> file describe a set of
Subversion repositories that will be downloaded into the current
directory prior to building a distribution. Subdirectories will be
created that correspond to the name of the projects listed in that
section. Optionally, after the URL of the subversion repository, you may
specify a particular revision to check out. If you do not specify a
revision, C<HEAD> will be used. For instance, to include a copy
MIT's simile timeline widget into your distribution, your
F<dist.ini> would contain something like this:

  [SvnObtain]
    simile = http://simile-widgets.googlecode.com/svn

This would create a subdirectory called F<simile> in the current
directory that contains the C<HEAD> revision.

If you do not wish the project directories to be created in the current
directory, you may specify a path relative to the current directory as
part of the section name. For instance, to checkout subversion
repositories into a subdirectory called F<libs/javascript>, the section
name would look like this:

  [SvnObtain/libs/javascript]
    jquery = http://jqueryjs.googlecode.com/svn/trunk
    simile = http://simile-widgets.googlecode.com/svn  2100

If the directory F<libs/javascript> does not exist, each component of
the path will be created as necessary. Once the directory
F<libs/javascript> exists, project directories will be created within it
for F<jquery> and F<simile>. The F<jquery> checkout will be at the HEAD
revision and the F<simile> checkout will be at revision 2100.

=head1 AUTHOR

Jonathan Scott Duff <duff@pobox.com>

=head1 COPYRIGHT

This software is copyright (c) 2010 by Jonathan Scott Duff

This is free sofware; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language itself.

=cut

