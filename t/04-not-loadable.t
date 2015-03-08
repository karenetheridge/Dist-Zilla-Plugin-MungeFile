use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;

my $tzil = Builder->from_config(
    { dist_root => 't/does_not_exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ 'MungeFile::WithDataSection' => { files => 'share/letter.txt', addressee => 'Bob' } ],
            ),
            'source/share/letter.txt' => <<'LETTER',
Dear {{ $addressee }},

It is with warm regards that I bring you this wonderful plugin. I hope
it serves you well.

Do also note that $DATA is {{ defined $DATA ? $DATA : 'undefined' }}, so do take care when using it
in your template code.

Cheers,
    ether!

LETTER
            'source/lib/Module.pm' => 'package Module;',
        },
    },
);

$tzil->chrome->logger->set_debug(1);
$tzil->build;

is(
    $tzil->slurp_file('build/share/letter.txt'),
    <<'NEW_LETTER',
Dear Bob,

It is with warm regards that I bring you this wonderful plugin. I hope
it serves you well.

Do also note that $DATA is undefined, so do take care when using it
in your template code.

Cheers,
    ether!

NEW_LETTER
    'non-compilable file content is transformed',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
