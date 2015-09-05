use strict;
use warnings;
package Dist::Zilla::Plugin::MungeFile;
# ABSTRACT: Modify files in the build, with templates and arbitrary extra variables
# KEYWORDS: plugin file content injection modification template
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.010';

use Moose;
with (
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::FileFinderUser' => { default_finders => [ ] },
);
use MooseX::SlurpyConstructor 1.2;
use List::Util 'first';
use Scalar::Util 'blessed';
use namespace::autoclean;

sub mvp_multivalue_args { qw(files) }
sub mvp_aliases { { file => 'files' } }

has files => (
    isa  => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { [] },
    traits => ['Array'],
    handles => { files => 'sort' },
);

has _extra_args => (
    isa => 'HashRef[Str]',
    init_arg => undef,
    lazy => 1,
    default => sub { {} },
    traits => ['Hash'],
    handles => { _extra_args => 'elements' },
    slurpy => 1,
);

around dump_config => sub
{
    my $orig = shift;
    my $self = shift;

    my $config = $self->$orig;

    $config->{'' . __PACKAGE__} = {
        finder => $self->finder,
        files => [ $self->files ],
        $self->_extra_args,
        blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
    };

    return $config;
};

sub munge_files
{
    my $self = shift;

    my @files = map {
        my $filename = $_;
        my $file = first { $_->name eq $filename } @{ $self->zilla->files };
        defined $file ? $file : ()
    } $self->files;

    $self->munge_file($_) for @files, @{ $self->found_files };
}

sub munge_file
{
    my ($self, $file, $more_args) = @_;

    $self->log_debug([ 'updating contents of %s in memory', $file->name ]);

    $file->content(
        $self->fill_in_string(
            $file->content,
            {
                $self->_extra_args,     # must be first
                dist => \($self->zilla),
                plugin => \$self,
                %{ $more_args || {} },
            },
        )
    );
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [MungeFile]
    file = lib/My/Module.pm
    house = maison

And during the build, F<lib/My/Module.pm>:

    my @stuff = qw(
        {{
            expensive_build_time_sub($house)
        }}
    );
    my ${{ $house }} = 'my castle';

Is transformed to:

    my @stuff = qw(
        ...list generated from "maison"
    );
    my $maison = 'my castle';

=head1 DESCRIPTION

=for stopwords FileMunger

This is a L<FileMunger|Dist::Zilla::Role::FileMunger> plugin for
L<Dist::Zilla> that passes a file(s)
through a L<Text::Template>.

The L<Dist::Zilla> object (as C<$dist>) and this plugin (as C<$plugin>) are
also made available to the template, for extracting other information about
the build.

Additionally, any extra keys and values you pass to the plugin are passed
along in variables named for each key.

=for Pod::Coverage munge_files munge_file mvp_aliases

=head1 OPTIONS

=head2 C<finder>

=for stopwords FileFinder

This is the name of a L<FileFinder|Dist::Zilla::Role::FileFinder> for finding
files to modify.

Other pre-defined finders are listed in
L<Dist::Zilla::Role::FileFinderUser/default_finders>.
You can define your own with the
L<[FileFinder::ByName]|Dist::Zilla::Plugin::FileFinder::ByName> plugin.

There is no default.

=head2 C<file>

Indicates the filename in the dist to be operated upon; this file can exist on
disk, or have been generated by some other plugin.  Can be included more than once.

B<At least one of the C<finder> or C<file> options is required.>

=head2 C<arbitrary option>

All other keys/values provided will be passed to the template as is.

=head1 METHODS

=head2 munge_file

    $plugin->munge_file($file, { key => val, ... });

In addition to the standard C<$file> argument, a hashref is accepted which
contains additional data to be passed through to C<fill_in_string>.

=head1 BACKGROUND

=for stopwords refactored

This module has been refactored out of
L<Dist:Zilla::Plugin::MungeFile::WithDataSection> and
L<Dist::Zilla::Plugin::MungeFile::WithConfigFile> to make it more visible as a
general template-runner file-munging plugin.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Plugin::Substitute>
* L<Dist::Zilla::Plugin::GatherDir::Template>
* L<Dist::Zilla::Plugin::MungeFile::WithDataSection>
* L<Dist::Zilla::Plugin::MungeFile::WithConfigFile>

=cut
