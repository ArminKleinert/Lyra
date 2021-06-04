
# [\s,]* Whitespace
# [()'] Matches (, ), '
# "(?:\\.|[^\\"])*"? Matches 0 or 1 string
# ;.* Matches comment and rest or line
# [^\s\[\]{}('"`,;)]* Everything else
RE = /[\s,]*('\(\)|[()]|"(?:\\.|[^\\"])*"?|;.*|'?[^\s\[\]{}('"`,;)]*)/

Cons = Struct.new(:car, :cdr) do
  def list_to_s_helper()
    if cdr.nil?
      car.to_s
    elsif cdr.is_a?(Cons)
      car.to_s + " " + cdr.list_to_s_helper
    else
      car.to_s + " . " + cdr.to_s
    end
  end
  
  def to_s
    "(" + list_to_s_helper() + ")"
  end
  
  def to_a
    rest = cdr
    result = [car]
    while rest.is_a?(Cons)
      result << rest.car
      rest = rest.cdr
    end
    result
  end
end

def first(c); c.car
end
def second(c); c.cdr.car
end
def third(c); c.cdr.cdr.car
end
def fourth(c); c.cdr.cdr.cdr.car
end
def rest(c); c.cdr
end

def tokenize(s)
  s.scan(RE).flatten.reject{|s| s.empty? || s.start_with?(";")}
end

def list(*args)
  if args.empty?
    nil
  else
    Cons.new(args[0], list(*args[1..-1]))
  end
end

def parse_str(token)
  token.gsub(/\\./, {"\\\\" => "\\", "\\n" => "\n", "\\\"" => '"'})[1..-2]
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
    when "'()"                  then root << nil
    when "#t"                   then root << true
    when "#f"                   then root << false
    when /^-?[0-9]+$/           then root << t.to_i
    when /^-?[0-9][0-9.]*$/     then root << t.to_f
    when /^"(?:\\.|[^\\"])*"$/  then root << parse_str(t)
    else
      if t.start_with?("'")
        root << list(:quote, t[1..-1].to_sym)
      else
        root << t.to_sym
      end
    end
  end
  raise "Expected ')', got EOF" if level != 0
  list(*root)
end

def list_len(cons, n=0)
  unless cons.is_a?(Cons)
    n
  else
    list_len(cons.cdr, n+1)
  end
end

class TailCall < StandardError
  attr_reader :args
  def initialize(args)
    @args = args
  end
end

class LyraFn < Proc
  attr_reader :arg_counts
  attr_reader :body
  attr_accessor :name
  attr_reader :ismacro
  attr_reader :arg_names
  
  def initialize(name, ismacro, min_args, max_args=min_args, arg_names=nil, &body)
    @arg_counts = (min_args .. max_args)
    @body = body
    @name = name
    @ismacro = ismacro
    @arg_names = arg_names
  end
  
  def call(args, env)
    args_given = list_len(args)
    raise "#{@name}: Too few arguments. (Given #{args_given}, expected #{@arg_counts})" if args_given < arg_counts.first
    raise "#{@name}: Too many arguments. (Given #{args_given}, expected #{@arg_counts})" if arg_counts.last >= 0 && args_given > arg_counts.last
    
    $lyra_call_stack = Cons.new(self, $lyra_call_stack)
    
    begin
      r = body.call(args, env)
    rescue TailCall => tailcall
      unless native?
        args = tailcall.args
        retry
      end
    rescue RuntimeError
      $stderr.puts "#{@name} failed with error: #{$!}"
      raise
    end
    
    unless $lyra_call_stack.nil?
      $lyra_call_stack = $lyra_call_stack.cdr
    end
    
    r
  end
  
  def to_s
    "<#{@ismacro ? "macro" : "function"} #{name}>"
  end
  
  def native?
    false
  end
end

class NativeLyraFn < LyraFn
  def native?
    true
  end
end

def setup_core_functions
  def add_fn(name, min_args, max_args=min_args, &body)
    entry = Cons.new(name, NativeLyraFn.new(name, false, min_args, max_args, &body))
    LYRA_ENV.cdr = Cons.new(entry, LYRA_ENV.cdr)
  end
  def add_macro(name, min_args, max_args=min_args, &body)
    entry = Cons.new(name, NativeLyraFn.new(name, true, min_args, max_args, &body))
    LYRA_ENV.cdr = Cons.new(entry, LYRA_ENV.cdr)
  end
  def add_var(name, value)
    LYRA_ENV.cdr = Cons.new(Cons.new(name, value), LYRA_ENV.cdr)
  end

  add_fn(:"p=", 2)        { |args, _| first(args) == second(args) }

  add_fn(:"p<", 2)        { |args, _| first(args) < second(args) }
  add_fn(:"p>", 2)        { |args, _| first(args) > second(args) }

  add_fn(:"p+", 2)        { |args, _| first(args) + second(args) }
  add_fn(:"p-", 2)        { |args, _| first(args) - second(args) }
  add_fn(:"p*", 2)        { |args, _| first(args) * second(args) }
  add_fn(:"p/", 2)        { |args, _| first(args) / second(args) }
  add_fn(:"p%", 2)        { |args, _| first(args) % second(args) }

  add_fn(:"p&", 2)        { |args, _| first(args) & second(args) }
  add_fn(:"p|", 2)        { |args, _| first(args) | second(args) }
  add_fn(:"p^", 2)        { |args, _| first(args) ^ second(args) }

  add_fn(:list, -1)       { |args, _| args }
  add_fn(:car, 1)         { |args, _| first(args).car }
  add_fn(:cdr, 1)         { |args, _| first(args).cdr }
  add_fn(:cons, 2)        { |args, _| Cons.new(first(args), second(args)) }
  add_fn(:"set-car!", 2)  { |args, _| first(args).car = second(args) }
  add_fn(:"set-cdr!", 2)  { |args, _| first(args).cdr = second(args) }

  add_fn(:null?, 1)       { |args, _| first(args).nil? }
  add_fn(:cons?, 1)       { |args, _| first(args).is_a?(Cons)}
  add_fn(:int?, 1)        { |args, _| first(args).is_a?(Integer)}
  add_fn(:float?, 1)      { |args, _| first(args).is_a?(Float)}
  add_fn(:string?, 1)     { |args, _| first(args).is_a?(String)}

  add_fn(:int, 1)         { |args, _| first(args).to_i }
  add_fn(:float, 1)       { |args, _| first(args).to_f }
  add_fn(:string, 1)      { |args, _| first(args).to_s }
  add_fn(:bool, 1)        { |args, _| !!first(args) }

  add_fn(:sprint!, 2)     { |args, _| first(args).print(second(args))}
  add_fn(:sread!, 1)      { |args, _| first(args).gets }
  add_fn(:slurp!, 1)      { |args, _| IO.read(first(args)) }
  add_fn(:spit!, 2)       { |args, _| IO.write(first(args), second(args)) }
  
  add_fn(:eval!, 1)       { |args, env| eval_keep_last(first(args), env) }
  add_fn(:"call-with-env!", 2){ |args, _| args.car.call(args.cdr.car) }
  add_fn(:parse, 1)       { |args, env| s = first(args)
                                        make_ast(tokenize(s)) }
  add_fn(:env!, 0)        { |_, env| env }
  add_fn(:"global-env!", 0) { |_, _| LYRA_ENV.cdr }
  add_fn(:time!, 0)       { |_, _| Time.now.to_f }
  
  add_fn(:measure, 2)     { |args, env|
                            t = Time.now
                            first(args).times do |_|
                              second(args).call(nil, env)
                            end
                            Time.now - t }

  add_var(:stdin, $stdin)
  add_var(:stdout, $stdout)
  add_var(:stderr, $stderr)

  true
end

# nil is not a valid pair but will be used as a separator between local LYRA_ENV
# and global LYRA_ENV.
unless  Object.const_defined?(:LYRA_ENV)
  LYRA_ENV = Cons.new(nil,nil)
  $lyra_call_stack = nil # Also handled as a cons
  setup_core_functions()
end

def evalstr(s, env=LYRA_ENV)
  ast = make_ast(tokenize(s))
  eval_keep_last(ast, env)
end

# Turns 2 lists into a combined one.
# pairs(list(1,2,3), list(4,5,6)) => ((1 . 4) (2 . 5) (3 . 6))
def pairs(cons0, cons1)
  if cons0.nil? || cons1.nil?
    nil
  elsif cons0.cdr.nil? && !(cons1.cdr.nil?)
    Cons.new(Cons.new(first(cons0), cons1), nil)
  else
    Cons.new(Cons.new(first(cons0), first(cons1)), pairs(cons0.cdr, cons1.cdr))
  end
end

# Check atoms for equality

# Search environment for symbol
def associated(x, env)
  if env.nil?
    raise "Symbol not found: #{x}"
  elsif env.car.nil?
    # Divider between local and global environments
    associated(x, env.cdr)
  elsif env.car.car == x
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
    Cons.new(first(c0), append(c0.cdr, c1))
  end
end

# Takes a Cons (list of expressions), calls eval_ly on each element
# and return a new list
def eval_list(expr_list, env)
  if expr_list.nil?
    nil
  else
    Cons.new(eval_ly(first(expr_list), env), eval_list(rest(expr_list), env))
  end
end

# Similar to eval_list, but only returns the last evaluated value
def eval_keep_last(expr_list, env)
  if expr_list.nil?
    nil
  elsif rest(expr_list).nil?
    eval_ly(first(expr_list), env)
  else
    eval_ly(first(expr_list), env)
    eval_keep_last(rest(expr_list), env)
  end
end

# Defines a new function or variable and puts it into the global LYRA_ENV.
# If `ismacro` is true, the function will not evaluate its
# arguments right away.
def evdefine(expr, env, ismacro)
  name = nil
  res = nil
  if first(expr).is_a?(Cons)
    # Form is `(define (...) ...)` (Function definition)
    name = first(first(expr))
    args_expr = rest(first(expr))
    body = rest(expr)

    res = evlambda(args_expr, body, ismacro)

    res.name = name
  else
    # Form is `(define .. ...)` (Variable definition)
    name = first(expr)
    val = second(expr)
    res = eval_ly(val, env)
  end
  entry = Cons.new(name, res)
  LYRA_ENV.cdr = Cons.new(entry , LYRA_ENV.cdr) # Put new entry into global LYRA_ENV
  res
end

# args_expr has the format `(args...)`
# body_expr has the format `expr...`
def evlambda(args_expr, body_expr, ismacro = false)
  arg_arr = args_expr.to_a
  arg_count = arg_arr.size
  max_args = arg_count

  if arg_count >= 2
    varargs = arg_arr[-2] == :"&"
    if varargs
      last = arg_arr[-1]
      arg_arr = arg_arr[0 .. -3]
      arg_arr << last
      args_expr = list(*arg_arr)
      max_args = -1
      arg_count -= 1
    end
  end

  LyraFn.new("", ismacro, arg_count, max_args, args_expr) do |args, environment|
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
    case first(expr)
    when :if
      if eval_ly(second(expr), env)
        eval_ly(third(expr), env)
      else
        eval_ly(fourth(expr), env)
      end
    when :lambda
      args_expr = second(expr)
      body_expr = rest(rest(expr))
      evlambda(args_expr, body_expr)
    when :define
      evdefine(rest(expr), env, false)
    when :"let*"
      name = first(second(expr))
      val = eval_ly(second(second(expr)), env)
      env1 = Cons.new(Cons.new(name, val), env)
      eval_keep_last(rest(rest(expr)), env1)
    when :"let"
      bindings = second(expr)
      body = rest(rest(expr))
      env1 = env
      while bindings
        env1 = Cons.new(Cons.new(bindings.car.car, bindings.car.cdr.car), env1)
        bindings = bindings.cdr
      end
      eval_keep_last(rest(rest(expr)), env1)
    when :quote
      raise "Too many arguments for quote." unless rest(rest(expr)).nil?
      second(expr)
    when :"def-macro"
      evdefine(rest(expr), env, true)
    else
      # Find value of symbol in env and call it as a function
      func = eval_ly(first(expr), env)
      args = rest(expr)
      func = eval_ly(func, env) if func.is_a?(Cons)
      if func.ismacro
        #$lyra_call_stack = Cons.new(func, $lyra_call_stack)
        eval_ly(func.call(args, env), env)
      else
        if (first(expr) == :times)
          #puts (func == $lyra_call_stack.car) unless $lyra_call_stack.nil?
        end
        args = eval_list(args, env)
        if (!func.native?) && (!$lyra_call_stack.nil?) && (func == $lyra_call_stack.car)
          # Tail call
          raise TailCall.new(args)
        end
        #$lyra_call_stack = Cons.new(func, $lyra_call_stack)
        func.call(args, env)
      end
    end
  else
    expr # Atoms evaluate to themselves
  end
end

if ARGV.size > 0
  evalstr(IO.read(ARGV[0]))
end
