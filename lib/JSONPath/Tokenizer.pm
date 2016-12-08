use 5.016;

package JSONPath::Tokenizer;

use Carp;
use JSONPath::Constants qw(:symbols :operators);
use Exporter::Easy ( OK => [ 'tokenize' ] );
use Readonly;

Readonly my %RESERVED_SYMBOLS => (
    $DOLLAR_SIGN          => 1,
    $COMMERCIAL_AT        => 1,
    $FULL_STOP            => 1,
    $LEFT_SQUARE_BRACKET  => 1,
    $RIGHT_SQUARE_BRACKET => 1,
    $ASTERISK             => 1,
    $COLON                => 1,
    $LEFT_PARENTHESIS     => 1,
    $RIGHT_PARENTHESIS    => 1,
    $COMMA                => 1,
    $EQUAL_SIGN           => 1,
    $EXCLAMATION_MARK     => 1,
    $GREATER_THAN_SIGN    => 1,
    $LESS_THAN_SIGN       => 1,
    $QUESTION_MARK        => 1,
);

Readonly my $OPERATOR_TYPE_PATH       => 1;
Readonly my $OPERATOR_TYPE_COMPARISON => 2;
Readonly my %OPERATORS                => (
    $TOKEN_ROOT                => $OPERATOR_TYPE_PATH,          # $
    $TOKEN_CURRENT             => $OPERATOR_TYPE_PATH,          # @
    $TOKEN_CHILD               => $OPERATOR_TYPE_PATH,          # . OR []
    $TOKEN_RECURSIVE           => $OPERATOR_TYPE_PATH,          # ..
    $TOKEN_ALL                 => $OPERATOR_TYPE_PATH,          # *
    $TOKEN_FILTER_OPEN         => $OPERATOR_TYPE_PATH,          # ?(
    $TOKEN_SCRIPT_OPEN         => $OPERATOR_TYPE_PATH,          # (
    $TOKEN_FILTER_SCRIPT_CLOSE => $OPERATOR_TYPE_PATH,          # )
    $TOKEN_SUBSCRIPT_OPEN      => $OPERATOR_TYPE_PATH,          # [
    $TOKEN_SUBSCRIPT_CLOSE     => $OPERATOR_TYPE_PATH,          # ]
    $TOKEN_UNION               => $OPERATOR_TYPE_PATH,          # ,
    $TOKEN_ARRAY_SLICE         => $OPERATOR_TYPE_PATH,          # [ start:end:step ]
    $TOKEN_SINGLE_EQUAL        => $OPERATOR_TYPE_COMPARISON,    # =
    $TOKEN_DOUBLE_EQUAL        => $OPERATOR_TYPE_COMPARISON,    # ==
    $TOKEN_TRIPLE_EQUAL        => $OPERATOR_TYPE_COMPARISON,    # ===
    $TOKEN_GREATER_THAN        => $OPERATOR_TYPE_COMPARISON,    # >
    $TOKEN_LESS_THAN           => $OPERATOR_TYPE_COMPARISON,    # <
    $TOKEN_NOT_EQUAL           => $OPERATOR_TYPE_COMPARISON,    # !=
    $TOKEN_GREATER_EQUAL       => $OPERATOR_TYPE_COMPARISON,    # >=
    $TOKEN_LESS_EQUAL          => $OPERATOR_TYPE_COMPARISON,    # <=
);

# ABSTRACT: Helper class for JSON::Path::Evaluator. Do not call directly.

# Take an expression and break it up into tokens

sub tokenize {
    my $expression = shift;

    # $expression = normalize($expression);
    my @tokens;
    my @chars = split //, $expression;
    my $char;
    while ( defined( my $char = shift @chars ) ) {
        my $token = $char;
        if ( $RESERVED_SYMBOLS{$char} ) {
            if ( $char eq $FULL_STOP ) {    # distinguish between the '.' and '..' tokens
                my $next_char = shift @chars;
                if ( $next_char eq $FULL_STOP ) {
                    $token .= $next_char;
                }
                else {
                    unshift @chars, $next_char;
                }
            }
            elsif ($char eq $QUESTION_MARK){
                my $next_char = shift @chars;
                # $.addresses[?(@.addresstype.id == D84002)]

                if ( $next_char eq $LEFT_PARENTHESIS ) {
                    $token .= $next_char;
                }
                else { 
                    die qq{filter operator "$token" must be followed by '('\n};
                }
            }
            elsif ( $char eq $EQUAL_SIGN ) {    # Build '=', '==', or '===' token as appropriate
                my $next_char = shift @chars;
                if ( !defined $next_char ) {
                    die qq{Unterminated comparison: '=', '==', or '===' without predicate\n};
                }
                if ( $next_char eq $EQUAL_SIGN ) {
                    $token .= $next_char;
                    $next_char = shift @chars;
                    if ( !defined $next_char ) {
                        die qq{Unterminated comparison: '==' or '===' without predicate\n};
                    }
                    if ( $next_char eq $EQUAL_SIGN ) {
                        $token .= $next_char;
                    }
                    else {
                        unshift @chars, $next_char;
                    }
                }
                else {
                    unshift @chars, $next_char;
                }
            }
            elsif ( $char eq $LESS_THAN_SIGN || $char eq $GREATER_THAN_SIGN ) {
                my $next_char = shift @chars;
                if ( !defined $next_char ) {
                    die qq{Unterminated comparison: '=', '==', or '===' without predicate\n};
                }
                if ( $next_char eq $EQUAL_SIGN ) {
                    $token .= $next_char;
                }
                else {
                    unshift @chars, $next_char;
                }
            }
        }
        else {
            # Read from the character stream until we have a valid token
            while ( defined( $char = shift @chars ) ) {
                if ( $RESERVED_SYMBOLS{$char} ) {
                    unshift @chars, $char;
                    last;
                }
                $token .= $char;
            }
        }
        push @tokens, $token;
    }

    return normalize(@tokens);
}

sub normalize { 
    my @token_stream = @_;

    my @new_stream;
    while (defined (my $token = shift @token_stream)) { 
        if ($token eq $TOKEN_SUBSCRIPT_OPEN) { 
            my @sub_stream;
            while (defined (my $token = shift @token_stream)) {
                push @sub_stream, $token;
                last if $token eq $TOKEN_SUBSCRIPT_CLOSE;
            }
            my $last_token = pop @sub_stream;
            die qq{Opening bracket ($TOKEN_SUBSCRIPT_OPEN) without corresponding closing bracket\n} unless $last_token eq $TOKEN_SUBSCRIPT_CLOSE;

            @sub_stream = normalize(@sub_stream);
            if (scalar @sub_stream == 1) { 
                push @new_stream, $TOKEN_CHILD, @sub_stream; 
            }
            else { 
                push @new_stream, $TOKEN_SUBSCRIPT_OPEN, @sub_stream, $TOKEN_SUBSCRIPT_CLOSE;
            }
        }
        elsif (my ($quote, $str) = ($token =~ m/(['"])(.+)\1/)) {
            push @new_stream, $str;
        }
        else {
            $token =~ s/^\s+//;
            $token =~ s/\s+$//;
            push @new_stream, $token;
        }
    }
    return @new_stream;
}
1;
__END__
