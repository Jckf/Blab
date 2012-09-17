# Deep Gorge Blab.
# Modified by Jim C. K. Flaten (jckf@jckf.no).

package Blab;

use strict;
use warnings;

sub new {
	my ($class,%options) = @_;

	my $this = {
		'filename'				=> './blab.db',
		'sent'					=> {},
		'time'					=> {},
		'linked_responses'		=> {},
		'all_responses'			=> {},
		'teachers'				=> {},
		'all_teachers'			=> 0
	};

	$this->{$_} = $options{$_} for (keys %options);

	bless($this,$class);

	$this->loadResponses();

	return $this;
}

sub addTeacher {
	my ($this,$teacher) = @_;
	$this->{'teachers'}->{lc $teacher} = 1;
}

sub removeTeacher {
	my ($this,$teacher) = @_;
	delete $this->{'teachers'}->{lc $teacher};
}

sub isTeacher {
	my ($this,$teacher) = @_;
	return defined($this->{'teachers'}->{lc $teacher}) ? 1 : 0;
}

sub getResponse {
	my ($this,$username) = @_;
	return $this->{'sent'}->{$username};
}

sub clearUsername {
	my ($this,$username) = @_;
	delete $this->{'sent'}->{$username};
}

sub loadResponses {
	my ($this) = @_;

	$this->{'linked_responses'} = {};
	$this->{'all_responses'} = {};

	return if (!-e $this->{'filename'});

	open(my $fh,$this->{'filename'});
	my @lines = <$fh>;
	close($fh);

	chomp @lines;

	for (@lines) {
		my ($input,$output,$teacher) = split(/###/,$_,3);
		$this->{'linked_responses'}->{$input} = {} if (!defined $this->{'linked_responses'}->{$input});
		$this->{'linked_responses'}->{$input}->{$output}++;
		$this->{'all_responses'}->{$output}++;
	}
}

sub processMessage {
	my ($this,$teacher,$message) = @_;

	chomp $message;

	$this->clearUsername($teacher) if (defined $this->{'time'}->{$teacher} && time() - $this->{'time'}->{$teacher} > 180);

	my ($response,$method) = ('');

	$this->addResponse($this->{'sent'}->{$teacher},$message,$teacher) if (($this->{'all_teachers'} == 1 || defined $this->{'teachers'}->{lc $teacher}) && defined $this->{'sent'}->{$teacher});

	my $split = int rand 9;
	($response,$method) = ($this->getExactResponse($message),		'exact')		if (int rand 5 < 4);
	#($response,$method) = ($this->getRatedResponse($message),		'rated')		if (1); # Added by Jim.
	($response,$method) = ($this->getSearchExactResponse($message),	'exact search')	if ($response eq '' && int rand 5 < 4);
	($response,$method) = ($this->getInputSearchResponse($message),	'input search')	if ($response eq '' && $split < 2);
	($response,$method) = ($this->getSearchResponse($message),		'search')		if ($response eq '' && $split < 6);
	($response,$method) = ($this->getRandomResponse(),				'random')		if ($response eq '');
	($response,$method) = ('Hello.',								'static')		if ($response eq '');

	$this->{'sent'}->{$teacher} = $response;
	$this->{'time'}->{$teacher} = time();

	return($response,$method);
}

sub addResponse {
	my ($this,$input,$output,$teacher) = @_;

	$input =~ s/^\s+//g;
	$input =~ s/\s+/ /g;
	$input =~ s/\s+$//g;

	$this->{'linked_responses'}->{$input} = {} if (!defined $this->{'linked_responses'}->{$input});
	$this->{'linked_responses'}->{$input}->{$output}++;
	$this->{'all_responses'}->{$output} = 0 if (!defined $this->{'all_responses'}->{$output});
	$this->{'all_responses'}->{$output}++;

	open(my $fh,'>>',$this->{'filename'});
	print $fh ($input . '###' . $output . '###' . $teacher . "\n");
	close($fh);
}

sub getExactResponse {
	my ($this,$input) = @_;

	for (keys %{$this->{'linked_responses'}}) {
		if (lc $_ eq lc $input ) {
			my @keys = keys %{$this->{'linked_responses'}->{$_}};
			if (@keys) {
				return $keys[int rand @keys];
			}
		}
	}

	return '';
}

# Added by Jim.
sub getRatedResponse {
	my ($this,$input) = @_;

	my ($max,@possible) = (0);

	my @words = split(/\s+/,$this->cleanInput($input));

	for my $key (keys %{$this->{'linked_responses'}}) {
		my $matches = 0;
		for my $word (@words) {
			if ($key =~ /\Q$word\E/i) {
				$matches++;
			}
		}
		if ($matches > 0 && $matches >= $max) {
			$max = $matches;
			for my $response (keys %{$this->{'linked_responses'}->{$key}}) {
				push(@possible,$response);
			}
		}
	}

	return @possible ? $possible[int rand @possible] : '';
}

sub getSearchExactResponse {
	my ($this,$input) = @_;

	my @words = split(/\s+/,$this->cleanInput($input));
	my @possible;

	for my $word (@words) {
		for my $key (keys %{$this->{'linked_responses'}}) {
			if (lc $key ne lc $input && $key =~ /\b\Q$word\E\b/i) {
				push(@possible,$key);
			}
		}
	}

	if (@possible) {
		my $key = $possible[int rand @possible];
		my @keys = keys %{$this->{'linked_responses'}->{$key}};
		if (@keys) {
			return $keys[int rand @keys];
		}
	}

	return '';
}

sub getInputSearchResponse {
	my ($this,$input) = @_;

	my @words = split(/\s+/,$this->cleanInput($input));
	my @possible;

	foreach my $word (@words) {
		foreach my $key (keys %{$this->{'linked_responses'}}) {
			if (lc $key ne lc $input && $key =~ /\b\Q$word\E\b/i) {
				push(@possible,$key);
			}
		}
	}

	return @possible ? $possible[int rand @possible] : '';
}

sub getSearchResponse {
	my ($this,$input) = @_;

	my @words = split(/\s+/,$this->cleanInput($input));
	my @possible;

	foreach my $word (@words) {
		foreach my $key (keys %{$this->{'all_responses'}}) {
			if (lc $key ne lc $input && $key =~ /\Q$word\E/i) {
				push(@possible,$key);
			}
		}
	}

	return @possible ? $possible[int rand @possible] : '';
}

sub getRandomResponse {
	my ($this) = @_;

	my @keys = keys %{$this->{'all_responses'}};
	if (@keys) {
		return $keys[int rand @keys];
	}

	return '';
}

sub cleanInput {
	my ($this,$message) = @_;

	#$message =~ s/n\'t/ not/gi; # This is incorrect. "Can't" turns into "Ca not".
	$message =~ s/\'re/ are/gi;
	$message =~ s/\'m/ am/gi;
	#$message =~ s/\'s/ is/gi; # This is very incorrect. The ending "'s" doesn't always mean "is"! "This is Jim's computer."

	$message =~ s/\b(the|a|an|there|that|this|it)\b//gi;
	$message =~ s/\b(am|is|are|be|was|were)\b//gi;
	$message =~ s/\b(you|me|i|my|mine)\b//gi;
	$message =~ s/\b(can|will|may|could|would|might|should)\b//gi;
	$message =~ s/\b(part|type|kind)\b//gi;
	$message =~ s/\b(of|for|in|out|on|over|under|at|near|by|to|from|with|up|down)\b//gi;
	$message =~ s/\b(and|but|or|not)\b//gi;
	$message =~ s/\b(has|have|had|make|makes|made|do|does|did|find|finds|found|use|uses|used|go|goes|went)\b//gi;
	$message =~ s/\b(yes|no|yea|yeah|ok)\b//gi;
	$message =~ s/\b(what|where|who|why|when|how)\b//gi;
	$message =~ s/\b(too|also|very|much|more|many|some|most)\b//gi;

	$message =~ s/\d+//gi; # We don't talk in digits, do we?

	$message =~ s/^\s+//g; # Prepending messages with whitespace? Remove it!
	$message =~ s/\s+$//g; # Appending whitespace to a message? Remove it!
	$message =~ s/\s+/ /g; # Multiple whitespace following eachother. One is enough.

	$message =~ s/\W+//g; # New rule to get rid of junk.
	$message =~ s/\b.\b//g; # A word of one character is not important.

	return $message;
}

1;
