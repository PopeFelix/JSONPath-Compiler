use Test::Most;
use JSONPath::Tokenizer qw(tokenize);

my %EXPRESSIONS = (
    '$[*].id'                                    => [qw/$ . * . id/],
    q{$[0].title}                                => [qw/$ . 0 . title/],
    q{$..labels[?(@.name==bug)]}                 => [qw/$ .. labels [ ?( @ . name == bug ) ]/],
    q{$.store.book[(@.length-1)].title}          => [qw/$ . store . book [ ( @ . length-1 ) ] . title/],
    q{$.store.book[?(@.price < 10)].title}       => [qw/$ . store . book [ ?( @ . price <  10 ) ] . title/],
    q{$.store.book[?(@.price <= 10)].title}      => [qw/$ . store . book [ ?( @ . price <= 10 ) ] . title/],
    q{$.store.book[?(@.price >= 10)].title}      => [qw/$ . store . book [ ?( @ . price >= 10 ) ] . title/],
    q{$.store.book[?(@.price === 10)].title}     => [qw/$ . store . book [ ?( @ . price === 10 ) ] . title/],
    q{$['store']['book'][0]['author']}           => [qw/$ . store . book . 0 . author/],
    q{$[*].user[?(@.login == 'laurilehmijoki')]} => [qw/$ . * . user [ ?( @ . login == laurilehmijoki ) ]/],
);

for my $expression ( keys %EXPRESSIONS ) {
    my @tokens;
    lives_and { is_deeply [ tokenize($expression) ], $EXPRESSIONS{$expression} }
    qq{Expression "$expression" tokenized correctly};
}

done_testing;
