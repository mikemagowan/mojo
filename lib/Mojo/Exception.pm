package Mojo::Exception;
use Mojo::Base -base;
use overload bool => sub {1}, '""' => sub { shift->to_string }, fallback => 1;

has [qw(frames line lines_before lines_after)] => sub { [] };
has message => 'Exception!';
has 'verbose';

sub inspect {
  my ($self, @files) = @_;

  # Extract file and line from message
  my @trace;
  my $msg = $self->line([])->lines_before([])->lines_after([])->message;
  while ($msg =~ /at\s+(.+?)\s+line\s+(\d+)/g) { unshift @trace, [$1, $2] }

  # Extract file and line from stack trace
  my $first = $self->frames->[0];
  push @trace, [$first->[1], $first->[2]] if $first;

  # Search for context in files
  for my $frame (@trace) {
    next unless -r $frame->[0] && open my $handle, '<:utf8', $frame->[0];
    $self->_context($frame->[1], [[<$handle>]]);
    return $self;
  }
  $self->_context($trace[-1][1], [map { [split "\n"] } @files]) if @files;

  return $self;
}

sub new { @_ > 1 ? shift->SUPER::new(message => shift) : shift->SUPER::new }

sub throw { die shift->new(shift)->trace(2)->inspect(@_) }

sub to_string {
  my $self = shift;

  my $str = $self->message;
  return $str unless $self->verbose;

  $str .= $_->[0] . ': ' . $_->[1] . "\n" for @{$self->lines_before};
  $str .= $self->line->[0] . ': ' . $self->line->[1] . "\n" if $self->line->[0];
  $str .= $_->[0] . ': ' . $_->[1] . "\n" for @{$self->lines_after};

  return $str;
}

sub trace {
  my ($self, $start) = (shift, shift // 1);
  my @frames;
  while (my @trace = caller($start++)) { push @frames, \@trace }
  return $self->frames(\@frames);
}

sub _append {
  my ($stack, $line) = @_;
  chomp $line;
  push @$stack, $line;
}

sub _context {
  my ($self, $num, $lines) = @_;

  # Line
  return unless defined $lines->[0][$num - 1];
  $self->line([$num]);
  _append($self->line, $_->[$num - 1]) for @$lines;

  # Before
  for my $i (2 .. 6) {
    last if ((my $previous = $num - $i) < 0);
    unshift @{$self->lines_before}, [$previous + 1];
    _append($self->lines_before->[0], $_->[$previous]) for @$lines;
  }

  # After
  for my $i (0 .. 4) {
    next if ((my $next = $num + $i) < 0);
    next unless defined $lines->[0][$next];
    push @{$self->lines_after}, [$next + 1];
    _append($self->lines_after->[-1], $_->[$next]) for @$lines;
  }
}

1;

=encoding utf8

=head1 NAME

Mojo::Exception - Exceptions with context

=head1 SYNOPSIS

  use Mojo::Exception;

  # Throw exception and show stack trace
  eval { Mojo::Exception->throw('Something went wrong!') };
  say "$_->[1]:$_->[2]"  for @{$@->frames};

  # Customize exception
  eval {
    my $e = Mojo::Exception->new('Died at test.pl line 3.');
    die $e->trace(2)->inspect->verbose(1);
  };
  say $@;

=head1 DESCRIPTION

L<Mojo::Exception> is a container for exceptions with context information.

=head1 ATTRIBUTES

L<Mojo::Exception> implements the following attributes.

=head2 frames

  my $frames = $e->frames;
  $e         = $e->frames([$frame1, $frame2]);

Stack trace if available.

  # Extract information from the last frame
  my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext,
      $is_require, $hints, $bitmask, $hinthash) = @{$e->frames->[-1]};

=head2 line

  my $line = $e->line;
  $e       = $e->line([3 => 'die;']);

The line where the exception occurred if available.

=head2 lines_after

  my $lines = $e->lines_after;
  $e        = $e->lines_after([[4 => 'say $foo;'], [5 => 'say $bar;']]);

Lines after the line where the exception occurred if available.

=head2 lines_before

  my $lines = $e->lines_before;
  $e        = $e->lines_before([[1 => 'my $foo = 8;'], [2 => 'my $bar = 9;']]);

Lines before the line where the exception occurred if available.

=head2 message

  my $msg = $e->message;
  $e      = $e->message('Died at test.pl line 3.');

Exception message, defaults to "C<Exception!>".

=head2 verbose

  my $bool = $e->verbose;
  $e       = $e->verbose($bool);

Render exception with context.

=head1 METHODS

L<Mojo::Exception> inherits all methods from L<Mojo::Base> and implements the
following new ones.

=head2 inspect

  $e = $e->inspect;
  $e = $e->inspect($file1, $file2);

Inspect L</"message"> and L</"frames"> to fill L</"lines_before">, L</"line">
and L</"lines_after"> with context information.

=head2 new

  my $e = Mojo::Exception->new;
  my $e = Mojo::Exception->new('Died at test.pl line 3.');

Construct a new L<Mojo::Exception> object.

=head2 throw

  Mojo::Exception->throw('Something went wrong!');
  Mojo::Exception->throw('Something went wrong!', $file1, $file2);

Throw exception from the current execution context.

  # Longer version
  die Mojo::Exception->new('Something went wrong!')->trace->inspect;

=head2 to_string

  my $str = $e->to_string;

Render exception.

  # Render exception with context
  say $e->verbose(1)->to_string;

=head2 trace

  $e = $e->trace;
  $e = $e->trace($skip);

Generate stack trace and store all L</"frames">.

  # Skip 3 call frames in stack trace
  $e->trace(3);

=head1 OPERATORS

L<Mojo::Exception> overloads the following operators.

=head2 bool

  my $bool = !!$e;

Always true.

=head2 stringify

  my $str = "$e";

Alias for L</"to_string">.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
