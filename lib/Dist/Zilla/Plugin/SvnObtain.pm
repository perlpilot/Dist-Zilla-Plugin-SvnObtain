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
  [SvnObtain/

=head1 DESCRIPTION
