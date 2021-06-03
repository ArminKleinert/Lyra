
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
    elem_to_s(cons.car) + " " + list_to_s_helper(cons.cdr)
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

def cons(x,y)
  Cons.new(x,y)
end

def car(x)
  x.car
end

def cdr(x)
  x.cdr
end


=begin
s = ";Comment\n\"string\"\n1\n(define (inc n) (+ n 1))"
tokens = tokenize(s)
puts tokens.inspect

ast = make_ast(tokens)
puts ast.class
puts elem_to_s(ast)
puts
=end

def pairs(cons0, cons1)
  if cons0.nil? || cons1.nil?
    nil
  else
    Cons.new(Cons.new(cons0.car, cons1.car), pairs(cons0.cdr, cons1.cdr))
  end
end

def eq?(x, y)
  x == y
end

def associated(x, env)
  if eq?(env.car.car, x)
    env.car.cdr
  #elsif env.cdr.nil?
  #  nil
  else
    associated(x, env.cdr)
  end
end

def append(c0, c1)
  if c0.nil?
    c1
  else
    Cons.new(c0.car, append(c0.cdr, c1))
  end
end

def eval_list(expr_list, env)
  if expr_list.nil?
    nil
  else
    Cons.new(eval_ly(expr_list.car, env), eval_list(expr_list.cdr, env))
  end
end

def eval_keep_last(expr_list, env)
=begin
  temp = nil
  until expr_list.nil?
    temp = eval_ly(expr_list.car, env)
    expr_list = expr_list.cdr
  end
  temp
=end
  if expr_list.nil?
    nil
  elsif expr_list.cdr.nil?
    eval_ly(expr_list.car, env)
  else
    eval_ly(expr_list.car, env)
    eval_keep_last(expr_list.cdr, env)
  end
end

def eval_ly(expr, env)
  if expr.nil?
    nil # nil evaluates to nil
  elsif expr.is_a?(Symbol)
    associated(expr, env) # Get associated value from env
  elsif expr.is_a?(Cons)
    case expr.car
    when :if
      if eval_ly(expr.cdr.car, env)
        eval_ly(expr.cdr.cdr.car, env)
      else
        eval_ly(expr.cdr.cdr.cdr.car, env)
      end
    when :lambda
      args_expr = expr.cdr.car
      body_expr = expr.cdr.cdr
      lambda do |args, environment|
        env1 = append(pairs(args_expr, eval_list(args, env)), env)
        eval_keep_last(body_expr, env1)
      end
    when :define
      # ...
    when :"let*"
      name = expr.cdr.car.car
      val = eval_ly(expr.cdr.car.cdr.car, env)
      env1 = Cons.new(Cons.new(name, val), env)
      eval_keep_last(expr.cdr.cdr, env1)
    else
      # Find value of symbol in env and call it as a function
      eval_ly(expr.car, env).call(expr.cdr, env)
    end
  else
    expr # Atoms evaluate to themselves
  end
end

env1 = list(Cons.new(:"+", lambda{|args, env| eval_ly(args.car, env) + eval_ly(args.cdr.car, env)}))
expr0 = list(:"+", 1, 2)
expr1 = list(:lambda, list(:e), :e)
expr2 = list(list(:lambda, list(:e), :e), 1)
expr3 = list(:"let*", list(:x, 1), list(:"+", :x, 15))

#puts elem_to_s(eval_ly(expr0, env1))
#puts (eval_ly(1, env1))
#puts elem_to_s(eval_list(list(1,2,3), env1))
puts elem_to_s(eval_ly(expr1, env1).call(Cons.new(1,nil), env1))
puts elem_to_s(eval_ly(expr2, env1))
puts elem_to_s(eval_ly(expr3, env1))
