
# [\s,]* Whitespace
# [()'] Matches (, ), '
# "(?:\\.|[^\\"])*"? Matches 0 or 1 string
# ;.* Matches comment and rest or line
# [^\s\[\]{}('"`,;)]* Everything else
RE = /[\s,]*([()']|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)/

Cons = Struct.new(:car, :cdr) do
  def list_to_s_helper()
    if cdr.nil?
      elem_to_s(car)
    elsif cdr.is_a?(Cons)
      elem_to_s(car) + " " + cdr.list_to_s_helper()
    else
      elem_to_s(car) + " . " + elem_to_s(cdr)
    end
  end
  
  def to_s
    "(" + self.list_to_s_helper() + ")"
  end
end

def first(c)
  c.car
end
def second(c)
  c.cdr.car
end
def third(c)
  c.cdr.cdr.car
end
def fourth(c)
  c.cdr.cdr.cdr.car
end
def rest(c)
  c.cdr
end

def elem_to_s(e)
  e.to_s
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
    when /^-?[0-9.][0-9]*$/     then root << t.to_f
    when /^"(?:\\.|[^\\"])*"$/  then root << parse_str(t)
    else root << t.to_sym
    end
  end
  raise "Expected ')', got EOF" if level != 0
  list(*root)
end

LYRA_ENV = nil

def not?(x)
  !x
end

def append(cons0, cons1)
  if cons0.nil?
    cons1
  else
    Cons.new(cons0.car, append(cons0.cdr, cons1))
  end
end

def pairs(cons0, cons1)
  if cons0.nil?
    nil
  elsif cons0.cdr.nil?
    Cons.new(Cons.new(cons0.car, cons1), nil)
  else
    Cons.new(Cons.new(cons0.car, cons1.car), pairs(cons0.cdr, cons1.cdr))
  end
end

def associated(key, env)
  if env.nil?
    raise "Key not found: #{key}"
  elsif env.car.car == key
    env.car.cdr
  else
    associated(key, env.cdr)
  end
end

def eval_ly(expr, env)
  if expr.nil?
    nil
  elsif !expr.is_a?(Cons) && !expr.is_a?(Symbol)
    expr
  elsif expr.is_a?(Symbol)
    associated(expr, env)
  else 
    # List starting with something
    case first(expr)
    when :if
      pred = eval_ly(second(expr), env)
      if pred != false && !pred.nil?
        eval_ly(third(expr), env)
      else
        eval_ly(fourth(expr), env)
      end
    when :"let*"
      pair = second(expr)
      body = rest(rest(expr))
      name = first(pair)
      value = eval_ly(second(pair), env)
      env1 = Cons.new(Cons.new(name, value), env)
      eval_keep_last(body, env1)
    when :let
      bindings = second(expr)
      body = rest(rest(expr))
      
      env1 = env
      until bindings.nil?
        name = first(first(bindings))
        value = eval_ly(second(first(bindings)), env1)
        env1 = Cons.new(Cons.new(name, value), env1)
        bindings = bindings.cdr
      end

      eval_keep_last(body, env1)
    when :quote
      second(expr)
    when :lambda
      args = second(expr)
      body = rest(rest(expr))
    when :define
      # TODO
    when :"def-macro"
      # TODO
    else
      func = associated(first(expr), env)
      func
    end
  end
end

def make_define(args_expr, body, env)
  lambda do |args_expr, env|
  args = evlist(args_expr, env)
  env1 = append(pairs(args_expr, args), env)
  eval_keep_last(body, env1)
  end
end

def evlist(ls, env)
  if ls.nil?
    nil
  else
    Cons.new(eval_ly(first(ls), env), evlist(rest(ls), env))
  end
end

def eval_keep_last(expr, env)
  until expr.nil?
    r = eval_ly(expr.car, env)
    expr = expr.cdr
  end
  r
end

(lambda (n m) (+ n m))
(define (name n m) (+ n m))
(define name (lambda (n m) (+ n m)))
(def-macro (name e) ...)

(define (name n m) (+ n m))
        (name (+ 4 5) 9)

s = "(let ((a #f) (b 6) (c 7)) (if a b c))"
tokens = tokenize(s)
ast = make_ast(tokens)
puts eval_keep_last(ast, LYRA_ENV)
puts
