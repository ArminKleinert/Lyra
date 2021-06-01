
# [\s,]* Spaces
# [()'] (, ), '
# "(?:\\.|[^\\"])*"? Matches 0 or 1 strings
# ;.* Matches comment
# [^\s\[\]{}('"`,;)]* Matches all others
RE = /[\s,]*([()']|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)/

def tokenize(s)
  s.scan(RE).flatten.reject{|s| s.empty?}
end

class Cons
  attr_reader :car
  attr_reader :cdr
  
  def initialize(first, rest)
    @car = first
    @cdr = rest
  end
  
  def setcar(ncar)
    Cons.new ncar, @cdr
  end
  
  def setcdr(ncdr)
    Cons.new @car, ncdr
  end
end

def list(*args)
  if args.empty?
    nil
  else
    Cons.new args[0], list(*args[1 .. -1])
  end
end

def list_to_s_helper(cons)
  if cons.cdr.nil?
    cons.car.to_s
  elsif cons.cdr.is_a? Cons
    cons.car.to_s + " " + list_to_s_helper(cons.cdr)
  else
    cons.car.to_s + " . " + cons.cdr.to_s
  end
end

def list_to_s(cons)
  raise "Cons expected!" unless cons.is_a? Cons
  "(" + list_to_s_helper(cons) + ")"
end

puts tokenize(IO.read(ARGV[0])).inspect

