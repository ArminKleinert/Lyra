
# [\s,]* Whitespace
# [()'] Matches (, ), '
# "(?:\\.|[^\\"])*"? Matches 0 or 1 string
# ;.* Matches comment and rest or line
# [^\s\[\]{}('"`,;)]* Everything else
RE = /[\s,]*([()']|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)/

class Cons 
  attr_accessor :car
  attr_accessor :cdr
  
  def initialize(car, cdr)
    @car = car
    @cdr = cdr
  end
  
  def to_s
    elem_to_s(self)
  end

  def first
    @car
  end
  
  def second
    @cdr.car
  end
  
  def third
    @cdr.cdr.car
  end
  
  def fourth
    @cdr.cdr.cdr.car
  end
  
  def rest
    @cdr
  end
  
  def nth(i)
    if i == 0
      @car
    elsif !(@cdr.is_a?(Cons))
      nil
    else
      @cdr.nth(i-1)
    end
  end
  
  def nthrest(i)
    if i == 0 || @cdr.nil?
      @cdr
    else
      @cdr.nthrest(i-1)
    end
  end
end

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

def list_len(cons)
  if cons.nil?
    0
  else
    1 + list_len(cons.cdr)
  end
end

# nil is not a valid pair but will be used as a separator between local ENV
# and global ENV.
ENV = Cons.new(nil,nil)

class LyraFn < Proc
  attr_reader :arg_counts
  attr_reader :body
  attr_accessor :name
  attr_reader :ismacro
  
  def initialize(name, ismacro, min_args, max_args=min_args, &body)
    @arg_counts = (min_args .. max_args)
    @body = body
    @name = name
    @ismacro = ismacro
  end
  
  def call(args, env)
    args_given = list_len(args)
    raise "Too few arguments." if args_given < arg_counts.first
    raise "Too many arguments." if arg_counts.last >= 0 && args_given > arg_counts.last
    
    body.call(args, env)
  end
  
  def to_s
    "<#{@ismacro ? "macro" : "function"} #{name}>"
  end
end

def setup_core_functions
  def add_fn(name, min_args, max_args=min_args, &body)
    entry = Cons.new(name, LyraFn.new(name, false, min_args, max_args, &body))
    ENV.cdr = Cons.new(entry , ENV.cdr)
  end
  
  add_fn(:"+", 2) { |args, env| args.car + args.second }
  add_fn(:"-", 2) { |args, env| args.car - args.second }
  add_fn(:"*", 2) { |args, env| args.car * args.second }
  add_fn(:"/", 2) { |args, env| args.car / args.second }
  
  add_fn(:"list", -1) { |args, env| args }
  add_fn(:"car", 1) { |args, env| args.car }
  add_fn(:"cdr", 1) { |args, env| args.cdr }
  add_fn(:"cons", 2) { |args, env| Cons.new(args.car, args.cdr) }
  
  add_fn(:"cons?", 1) { |args, env| args.car.is_a?(Cons)}
  add_fn(:"int?", 1) { |args, env| args.car.is_a?(Integer)}
  add_fn(:"float?", 1) { |args, env| args.car.is_a?(Float)}
  add_fn(:"string?", 1) { |args, env| args.car.is_a?(String)}
  
  add_fn(:"int", 1) { |args, env| args.car.to_i }
  add_fn(:"float", 1) { |args, env| args.car.to_f }
  add_fn(:"string", 1) { |args, env| args.car.to_s }
  
  add_fn(:"print", 1) { |args, env| print(elem_to_s(args.car)) }
  add_fn(:"sprint", 2) { |args, env| args.car.print(elem_to_s(args.second)) }
  add_fn(:"println", 1) { |args, env| print(elem_to_s(args.car)) }
  add_fn(:"read", 0) { |args, env| gets }
  add_fn(:"sread", 1) { |args, env| args.car.gets }
  add_fn(:"slurp", 1) { |args, env| IO.read(args.car) }
  add_fn(:"spit", 2) { |args, env| IO.write(args.car, args.second) }
  
  true
end

# Turns 2 lists into a combined one.
# pairs(list(1,2,3), list(4,5,6)) => ((1 . 4) (2 . 5) (3 . 6))
def pairs(cons0, cons1)
  if cons0.nil? || cons1.nil?
    nil
  else
    Cons.new(Cons.new(cons0.car, cons1.car), pairs(cons0.cdr, cons1.cdr))
  end
end

# Check atoms for equality
def eq?(x, y)
  x == y
end

# Search environment for symbol
def associated(x, env)
  if env.nil?
    raise "Symbol not found: #{elem_to_s(x)}"
  elsif env.car.nil?
    # Divider between local and global environments
    associated(x, env.cdr)
  elsif eq?(env.car.car, x)
    env.car.cdr
  else
    associated(x, env.cdr)
  end
end

# Append two lists
# Complexity depends on the first list
def append(c0, c1)
  if c0.nil?
    c1
  else
    Cons.new(c0.car, append(c0.cdr, c1))
  end
end

# Takes a Cons (list of expressions), calls eval_ly on each element
# and return a new list
def eval_list(expr_list, env)
  if expr_list.nil?
    nil
  else
    Cons.new(eval_ly(expr_list.car, env), eval_list(expr_list.cdr, env))
  end
end

# Similar to eval_list, but only returns the last evaluated value
def eval_keep_last(expr_list, env)
  if expr_list.nil?
    nil
  elsif expr_list.cdr.nil?
    eval_ly(expr_list.car, env)
  else
    eval_ly(expr_list.car, env)
    eval_keep_last(expr_list.cdr, env)
  end
end

# Defines a new function or variable and puts it into the global ENV.
# If `ismacro` is true, the function will not evaluate its
# arguments right away.
def evdefine(expr, env, ismacro)
  name = nil
  res = nil
  if expr.first.is_a?(Cons)
    # Form is `(define (...) ...)` (Function definition)
    name = expr.first.first
    args_expr = expr.first.rest
    body = expr.rest
    #if ismacro
    #  res = LyraFn.new(name, true, list_len(args_expr)) do |args, environment|
    #    env1 = append(pairs(args_expr, args), environment)
    #    eval_keep_last(body, env1)
    #  end
    #else
      res = evlambda(args_expr, body, ismacro)
    #end
    res.name = name
  else
    # Form is `(define .. ...)` (Variable definition)
    name = expr.first
    val = expr.second
    res = eval_ly(val)
  end
  entry = Cons.new(name, res)
  ENV.cdr = Cons.new(entry , ENV.cdr) # Put new entry into global ENV
  res
end

# args_expr has the format `(args...)`
# body_expr has the format `expr...`
def evlambda(args_expr, body_expr, ismacro = false)
  arg_count = list_len(args_expr)
  LyraFn.new("", ismacro, arg_count) do |args, environment|
    env1 = append(pairs(args_expr, args), environment)
    eval_keep_last(body_expr, env1)
  end
end

# Evaluation function
def eval_ly(expr, env)
  if expr.nil?
    nil # nil evaluates to nil
  elsif expr.is_a?(Symbol)
    associated(expr, env) # Get associated value from env
  elsif expr.is_a?(Cons)
    case expr.car
    when :if
      if eval_ly(expr.second, env)
        eval_ly(expr.third, env)
      else
        eval_ly(expr.fourth, env)
      end
    when :lambda
      args_expr = expr.second
      body_expr = expr.cdr.cdr
      evlambda(args_expr, body_expr)
    when :define
      evdefine(expr.cdr, env, false)
    when :"let*"
      name = expr.second.car
      val = eval_ly(expr.second.second, env)
      env1 = Cons.new(Cons.new(name, val), env)
      eval_keep_last(expr.cdr.cdr, env1)
    when :quote
      expr.cdr # TODO TEST
    when :"def-macro"
      evdefine(expr.cdr, env, true)
    else
      # Find value of symbol in env and call it as a function
      func = eval_ly(expr.car, env)
      args = expr.cdr
      args = eval_list(args, env) unless func.ismacro
      func.call(args, env)
    end
  else
    expr # Atoms evaluate to themselves
  end
end

expr0 = list(:"+", 1, 2)
expr1 = list(:lambda, list(:e), :e)
expr2 = list(list(:lambda, list(:e), :e), 67)
expr3 = list(:"let*", list(:x, 1), list(:"+", :x, 15))
expr4 = list(:"define", list(:id, :e), :e)
expr5 = list(expr4, list(:id, 177))
expr6 = list(:"def-macro", list(:doub, :x), list(:cons, :x, :x))
expr7 = list(:"def-macro", list(:macroid, :x), :x)
expr8 = list(:doub, :"***")

#puts elem_to_s(eval_ly(expr0, env1))
#puts (eval_ly(1, env1))
#puts elem_to_s(eval_list(list(1,2,3), env1))
setup_core_functions()
#puts ENV
#puts associated(:"+", ENV)
puts elem_to_s(eval_ly(expr1, ENV))
puts elem_to_s(eval_ly(expr2, ENV))
puts elem_to_s(eval_ly(expr3, ENV))
puts elem_to_s(eval_ly(expr4, ENV))
puts elem_to_s(eval_ly(expr5, ENV))
puts elem_to_s(eval_ly(expr6, ENV))
puts elem_to_s(eval_ly(expr7, ENV))
puts elem_to_s(eval_ly(expr8, ENV))
