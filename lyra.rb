
# [\s,]* Whitespace
# [()'] Matches (, ), '
# "(?:\\.|[^\\"])*"? Matches 0 or 1 string
# ;.* Matches comment and rest or line
# [^\s\[\]{}('"`,;)]* Everything else
RE = /[\s,]*([()']|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)/

Cons = Struct.new :car, :cdr

def list_to_s_helper(cons)
  if cons.cdr.nil?
    elem_to_s(cons.car)
  elsif cons.cdr.is_a?(Cons)
    elem_to_s(cons.car) + ", " + list_to_s_helper(cons.cdr)
  else
    elem_to_s(cons.car) + " . " + elem_to_s(cons.cdr)
  end
end

def list_to_s(cons)
  "(" + list_to_s_helper(cons) + ")"
end

def elem_to_s(e)
  if e.is_a? Cons
    list_to_s(e)
  else
    e.to_s
  end
end

def tokenize(s)
  s.scan(RE).flatten.reject{|s| s.empty?}
end

def list(*args)
  if args.empty?
    nil
  else
    Cons.new(args[0], list(*args[1..-1]))
  end
end

def parse_str(token)
  token.gsub(/\\./, {"\\\\" => "\\", "\\n" => "\n", "\\\"" => '"'})
end

def make_ast(tokens, level=0)
  root = []
  while (t = tokens.shift) != nil
    case t
    when "("
      root << make_ast(tokens, level+1)
    when ")"
      raise "Unexpected ')'" if level == 0
      return list(*root)
    when '"'                    then raise "Unexpected '\"'"
    when "nil"                  then root << nil
    when "#t"                   then root << true
    when "#f"                   then root << false
    when /^-?[0-9]+$/           then root << t.to_i
    when /^-?[0-9][0-9.]*$/     then root << t.to_f
    when /^"(?:\\.|[^\\"])*"$/  then root << parse_str(t)
    else root << t.to_sym
    end
  end
  raise "Expected ')', got EOF" if level != 0
  list(*root)
end

#puts elem_to_s(Cons.new(1, Cons.new(2, nil)))
#puts elem_to_s(list(1,2,list(3),4,5))

s = ";Comment\n\"string\"\n1\n(define (inc n) (+ n 1))"
tokens = tokenize(s)
puts tokens.inspect

ast = make_ast(tokens)
puts ast.class
puts elem_to_s(ast)
