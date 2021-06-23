
# Definition of conses
Cons = Struct.new(:car, :cdr) do
  def lyra_type_id; @lyra_type_id
  end
  def lyra_type_id=(f)
    @lyra_type_id = f
  end
  
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
  
  # Not necessary, just for ease of use.
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

class Array
  def lyra_type_id
    @lyra_type_id
  end
  def lyra_type_id=(liti)
    @lyra_type_id = liti
  end
end

# Convenience functions.
def first(c); c.car; end
def second(c); c.cdr.car; end
def third(c); c.cdr.cdr.car; end
def fourth(c); c.cdr.cdr.cdr.car; end
def rest(c); c.cdr; end

# [\s,]* Whitespace
# '\(\) Matches the empty list '() (also called nil)
# [()] Matches (, )
# "(?:\\.|[^\\"])*"? Matches 0 or 1 string
# ;.* Matches comment and rest or line
# '?[^\s\[\]{}('"`,;)]* Everything else with an optional ' at the beginning.
RE = /[\s,]*('\(\)|[()]|"(?:\\.|[^\\"])*"?|;.*|'?[^\s\[\]{}('"`,;)]*)/

# Scan the text using RE, remove empty tokens and remove comments.
def tokenize(s)
  s.scan(RE).flatten.reject{|s| s.empty? || s.start_with?(";")}
end

# Creates a list of cons-cells from a Ruby-Array.
def list(*args)
  if args.empty?
    nil
  else
    Cons.new(args[0], list(*args[1..-1]))
  end
end

# Un-escapes a string and removed the '"' from beginning and end..
def parse_str(token)
  token.gsub(/\\./, {"\\\\" => "\\", "\\n" => "\n", "\\\"" => '"'})[1..-2]
end

# Builds the abstract syntax tree and converts all expressions into their
# types.
# For example, if a token is recognized as a bool, it is parsed into
# a bool, a string becomes a string, etc.
# If an `(` is found, a cons is opened. It is closed when a `)` is 
# encountered.
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
    when /^(0b[0-1]+|-?0x[0-9a-fA-F]+|-?[0-9]+)$/
      mult = 1
      if t[0] == "-"
        mult = -1
        t = t[1..-1]
      end
      
      case t[0..1]
      when "0x"
        t = t[2..-1]
        base = 16
      when "0b"
        t = t[2..-1]
        base = 2
      else
        base = 10
      end

      n = t.to_i(base) * mult
      root << n
    when /^-?[0-9]+\.[0-9]+$/
      root << t.to_f
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

# Get the length of a list. Might be removed in the future.
def list_len(cons, n=0)
  unless cons.is_a?(Cons)
    n
  else
    list_len(cons.cdr, n+1)
  end
end

# Thrown when a tail-call should be done.
class TailCall < StandardError
  attr_reader :args
  def initialize(args)
    @args = args
  end
end

# A Lyra-function. It knows its argument-count (minimum and maximum),
# body (the executable function), name and whether it is a macro or not.
class LyraFn < Proc
  attr_reader :arg_counts # Range of (minimum .. maximum)
  attr_reader :body # Executable
  attr_accessor :name # Symbol
  attr_reader :ismacro # Boolean
  
  def initialize(name, ismacro, min_args, max_args=min_args, &body)
    @arg_counts = (min_args .. max_args)
    @body = body
    @name = name
    @ismacro = ismacro
  end
  
  def call(args, env)
    # Check argument counts
    args_given = list_len(args)
    raise "#{@name}: Too few arguments. (Given #{args_given}, expected #{@arg_counts})" if args_given < arg_counts.first
    raise "#{@name}: Too many arguments. (Given #{args_given}, expected #{@arg_counts})" if arg_counts.last >= 0 && args_given > arg_counts.last
    
    begin
      # Execute the body.
      r = body.call(args, env)
    rescue TailCall => tailcall
      unless native?
        # Do a tail-call. (Thanks for providing `retry`, Ruby!)
        args = tailcall.args
        retry
      end
    rescue
      $stderr.puts "#{@name} failed with error: #{$!}"
      $stderr.puts "Arguments: #{args}"
      raise
    end
    
    # Return
    r
  end
  
  def to_s
    "<#{@ismacro ? "macro" : "function"} #{@name}>"
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

# Sets up the core functions and variables. The functions defined here are
# of the type NativeLyraFn instead of LyraFn. They can not make use of tail-
# recursion and are supposed to be very simple.
def setup_core_functions
  def add_fn(name, min_args, max_args=min_args, &body)
    entry = Cons.new(name, NativeLyraFn.new(name, false, min_args, max_args, &body))
    LYRA_ENV.cdr = Cons.new(entry, LYRA_ENV.cdr)
  end
  def add_var(name, value)
    LYRA_ENV.cdr = Cons.new(Cons.new(name, value), LYRA_ENV.cdr)
  end

  # "Primitive" operators. They are overridden in the core library of
  # Lyra as `=`, `<`, `>`, ... and can be extended there later on for
  # different types.
  add_fn(:"p=", 2)             { |args, _| first(args) == second(args) }
  add_fn(:"p<", 2)             { |args, _| first(args) < second(args) }
  add_fn(:"p>", 2)             { |args, _| first(args) > second(args) }
  add_fn(:"p+", 2)             { |args, _| first(args) + second(args) }
  add_fn(:"p-", 2)             { |args, _| first(args) - second(args) }
  add_fn(:"p*", 2)             { |args, _| first(args) * second(args) }
  add_fn(:"p/", 2)             { |args, _| first(args) / second(args) }
  add_fn(:"p%", 2)             { |args, _| first(args) % second(args) }
  add_fn(:"p&", 2)             { |args, _| first(args) & second(args) } # bit-and
  add_fn(:"p|", 2)             { |args, _| first(args) | second(args) } # bit-or
  add_fn(:"p^", 2)             { |args, _| first(args) ^ second(args) } # bit-xor
  add_fn(:"p<<", 2)            { |args, _| first(args) << second(args) } # bit-shift-left
  add_fn(:"p>>", 2)            { |args, _| first(args) >> second(args) } # bit-shift-right

  add_fn(:list, -1)            { |args, _| args }
  add_fn(:car, 1)              { |args, _| first(args).car }
  add_fn(:cdr, 1)              { |args, _| first(args).cdr }
  add_fn(:cons, 2)             { |args, _| Cons.new(first(args), second(args)) }
  add_fn(:pcons, 3)            { |args, _| c = Cons.new(first(args), second(args)); c.lyra_type_id = third(args); c }
  add_fn(:"set-car!", 2)       { |args, _| first(args).car = second(args) }
  add_fn(:"set-cdr!", 2)       { |args, _| first(args).cdr = second(args) }

  add_fn(:pvector, 1, -1)      { |args, _| r = args.cdr.to_a; r.lyra_type_id = args.car; r }
  add_fn(:vector, -1)          { |args, _| args.to_a }
  add_fn(:"vector-get", 2)     { |args, _| first(args)[second(args)] }
  add_fn(:"vector-set!", 3)    { |args, _| first(args)[second(args)] = third(args)
                                  first(args) }
  add_fn(:"vector-append!", 2) { |args, _| first(args) << second(args)
                                  first(args) }
  add_fn(:"vector-size", 1)    { |args, _| first(args).size }
  add_fn(:"vector-iterate", 3) { |args, env|
                               accumulator = second(args)
                               f = third(args)
                               first(args).each_with_index do |e,i|
                                 accumulator = f.call(list(accumulator, e,i), env)
                               end
                               accumulator }

  # Returns an integer representing an arbitrary id for the type of the
  # argument. It can be check using (bit-match ..).
  add_fn(:"lyra-type-id", 1) do |args, _|
    e = first(args)
    if e.respond_to?(:lyra_type_id) && (lti = first(args).lyra_type_id) != nil
      lti
    else
      case e
      when nil          then 0
      when Cons         then 1
      when Integer      then 2
      when Float        then 3
      when true, false  then 4
      when String       then 5
      when Array        then 6
      when Symbol       then 7
      else nil
      end
    end
  end

  add_fn(:"bit-match?", 2)     { |args, _| !(first(args).nil? || second(args).nil?) && (first(args) & second(args)) == first(args) }

  add_fn(:int, 1)              { |args, _| first(args).to_i }
  add_fn(:float, 1)            { |args, _| first(args).to_f }
  add_fn(:string, 1)           { |args, _| first(args).to_s }
  add_fn(:bool, 1)             { |args, _| !!first(args) }

  add_fn(:sprint!, 2, 3)       do |args, env|
    s = second(args)
    if list_len(args) == 3
      s = third(args).call(list(s), env)
    else
      s = s.to_s
    end
    first(args).print(s)
  end
  
  add_fn(:sread!, 1)           { |args, _| first(args).gets }
  add_fn(:slurp!, 1)           { |args, _| IO.read(first(args)) }
  add_fn(:spit!, 2)            { |args, _| IO.write(first(args), second(args)) }

  add_fn(:eval!, 1)            { |args, env| eval_keep_last(first(args), env) }
  add_fn(:"call-with-env!", 2) { |args, _| args.car.call(args.cdr.car) }
  add_fn(:parse, 1)            { |args, env| s = first(args)
                                  make_ast(tokenize(s)) }

  add_fn(:"global-env!", 0)    { |_, _| LYRA_ENV.cdr }
  add_fn(:time!, 0)            { |_, _| Time.now.to_f }
  add_fn(:"call-stack!", 0)    { |_, _| $lyra_call_stack }

  # Runs a function n times, saves the millisecond time for each run
  # and calculates the median time afterwards. The result is a floating point
  # number.
  add_fn(:measure, 2)          { |args, env|
                                median = lambda do |arr|
                                  arr.sort!
                                  len = arr.size
                                  (arr[(len-1)/2]+arr[len / 2]) / 2
                                end
                                
                                res = []
                                first(args).times do
                                  t0 = Time.now
                                  second(args).call(nil, env)
                                  t1 = Time.now
                                  res << (t1 - t0) * 1000.0
                                end
                                median.call(res) }

  add_fn(:"p-hash", 1)           { |args, _| first(args).hash }

  add_var(:stdin, $stdin)
  add_var(:stdout, $stdout)
  add_var(:stderr, $stderr)

  true
end

# nil is not a valid pair but will be used as a separator between
# local LYRA_ENV and global LYRA_ENV.
unless Object.const_defined?(:LYRA_ENV)
  LYRA_ENV = Cons.new(nil,nil)
  $lyra_call_stack = nil # Also handled as a cons
  setup_core_functions()
end

# Parses and evaluates a string as Lyra-source code.
def evalstr(s, env=LYRA_ENV)
  ast = make_ast(tokenize(s))
  eval_keep_last(ast, env)
end

# Turns 2 lists into a combined one.
#   `pairs(list(1,2,3), list(4,5,6)) => ((1 . 4) (2 . 5) (3 . 6))`
# If the first list is longer than the second, all remaining 
# elements from the second are added the value for the last element
# of the first list:
#   `pairs(list(1,2,3), list(4,5,6,7)) => ((1 . 4) (2 . 5) (3 6 7))`
# The intended use for this function is for adding function arguments
# to the environment. The latter case makes it easy to pass
# variadic arguments.
def pairs(cons0, cons1)
  if cons0.nil?
    nil
  elsif cons1.nil?
    # FIXME
    Cons.new(Cons.new(first(cons0), nil), pairs(cons0.cdr, nil))
  elsif cons0.cdr.nil? && !(cons1.cdr.nil?)
    Cons.new(Cons.new(first(cons0), cons1), nil)
  else
    Cons.new(Cons.new(first(cons0), first(cons1)), pairs(cons0.cdr, cons1.cdr))
  end
end

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

# Append two lists. Complexity depends on the first list.
# TODO Potential candidate for optimization?
def append(c0, c1)
  if c0.nil?
    c1
  else
    Cons.new(first(c0), append(c0.cdr, c1))
  end
end

# Takes a Cons (list of expressions), calls eval_ly on each element
# and return a new list.
# TODO Potential candidate for optimization?
def eval_list(expr_list, env)
  if expr_list.nil?
    nil
  else
    Cons.new(eval_ly(first(expr_list), env, true), eval_list(rest(expr_list), env))
  end
end

# Similar to eval_list, but only returns the last evaluated value.
# TODO Potential candidate for optimization?
def eval_keep_last(expr_list, env)
  if expr_list.nil?
    # No expressions in the list -> Just return nil
    nil
  elsif rest(expr_list).nil?
    # Only one expression left -> Execute it and return.
    eval_ly(first(expr_list), env)
  else
    # At least 2 expressions left -> Execute the first and recurse
    eval_ly(first(expr_list), env)
    eval_keep_last(rest(expr_list), env)
  end
end

# Defines a new function or variable and puts it into the global LYRA_ENV.
# If `ismacro` is true, the function will not evaluate its arguments right away.
def evdefine(expr, env, ismacro)
  name = nil
  res = nil
  if first(expr).is_a?(Cons)
    # Form is `(define (...) ...)` (Function definition)
    name = first(first(expr))
    args_expr = rest(first(expr))
    body = rest(expr)

    # Create the function
    res = evlambda(args_expr, body, ismacro)
    res.name = name
  else
    # Form is `(define .. ...)` (Variable definition)
    name = first(expr) # Get the name
    val = second(expr)
    res = eval_ly(val, env) # Get and evaluate the value.
  end
  # Create an entry with the name and value.
  entry = Cons.new(name, res)
  
  # Add the entry to the global environment.
  LYRA_ENV.cdr = Cons.new(entry , LYRA_ENV.cdr)
  
  name
end

# args_expr has the format `(args...)`
# body_expr has the format `expr...`
def evlambda(args_expr, body_expr, ismacro = false)
  arg_arr = args_expr.to_a
  arg_count = arg_arr.size
  max_args = arg_count

  # Check for variadic arguments.
  # The arguments of a function are variadic if the second to last
  # symbol in the argument list is `&`.
  if arg_count >= 2
    varargs = arg_arr[-2] == :"&"
    if varargs
      # Remove the `&` from the arguments.
      last = arg_arr[-1]
      arg_arr = arg_arr[0 .. -3]
      arg_arr << last
      args_expr = list(*arg_arr)
      
      # Set the new argument numbers for minimum
      # and maximum number of arguments.
      # -1 means infinite.
      max_args = -1
      arg_count -= 2
    end
  end
  
  LyraFn.new("", ismacro, arg_count, max_args) do |args, environment|
    # Makes pairs of the argument names and given arguments and
    # adds these pairs to the local environment.
    env1 = append(pairs(args_expr, args), environment)
    # Execute all commands in the body and return the last
    # value.
    eval_keep_last(body_expr, env1)
  end
end

# Evaluation function
def eval_ly(expr, env, is_in_call_params=false)
  if expr.nil?
    nil # nil evaluates to nil
  elsif expr.is_a?(Symbol)
    associated(expr, env) # Get associated value from env
  elsif expr.is_a?(Cons)
    # The expression is a cons and probably starts with a symbol.
    # The evaluate function will try to treat the symbol as a function
    # and execute it.
    # If the first expression in the cons is another cons, that one 
    # will be evaluated first and then run as a function too.
    #   Example: ((lambda (n) (+ n 1)) 15)
    # If the cons is empty or does not start with a symbol or another
    # cons, an error is thrown.
    
    # Try to match the symbol.
    case first(expr)
    when :if
      # Form is `(if predicate then-branch else-branch)`.
      # If the predicate holds true, the then-branch is executed.
      # Otherwise, the else-branch is executed.
      raise "if needs 3 arguments." if list_len(expr) < 4 # includes the 'if
      pres = eval_ly(second(expr), env)
      #uts "In if: " + pres.to_s
      if pres != false && pres != nil
        # The predicate was true
        eval_ly(third(expr), env)
      else
        # The predicate was not true
        eval_ly(fourth(expr), env)
      end
    when :cond
      clauses = rest(expr)
      result = nil
      until clauses.nil?
        predicate = eval_ly(first(first(clauses)), env)
        if predicate
          result = eval_ly(second(first(clauses)), env)
          break
        end
        clauses = rest(clauses)
      end
      result
    when :lambda
      raise "lambda must take at least 1 argument." if expr.cdr.nil?

      # Defines an anonymous function.
      # Form: `(lambda (arg0 arg1 ...) body...)`
      # If the body is empty, the lambda returns nil.
      args_expr = second(expr)
      body_expr = rest(rest(expr))
      evlambda(args_expr, body_expr)
    when :define
      # Creates a new function and adds it to the global environment.
      # Form: `(define name value)` (For variables)
      #    or `(define (name arg0 arg1 ...) body...)` (For functions)
      # If the body is empty, the function returns nil.
      evdefine(rest(expr), env, false)
    when :"let*"
      raise "let* needs at least 1 argument." if expr.cdr.nil?
      raise "let* bindings must be a list." unless second(expr).is_a?(Cons)

      # `expr` has the following form:
      # (let* (name value) body...)
      # The binding (name-value pair) is evaluated and added to the
      # environment. Then the body is executed and the result of the
      # last expression returned.
      # If the body is empty, returns nil.
      name = first(second(expr))
      val = eval_ly(second(second(expr)), env) # Evaluate the value.
      env1 = Cons.new(Cons.new(name, val), env) # Add the value to the environment.
      eval_keep_last(rest(rest(expr)), env1) # Evaluate the body.
    when :let
      raise "let needs at least 1 argument." if expr.cdr.nil?
      raise "let bindings must be a list." unless second(expr).is_a?(Cons)

      # 'expr' has the following form:
      # (let ((sym0 val0) (sym1 val1) ...) body...)
      # The bindings (sym-val pairs) are evaluated, added to the environment
      # and then the body is evaluated. The last returned value is returned.

      bindings = second(expr)
      body = rest(rest(expr))
      env1 = env

      # Evaluate and add the bindings in order (so they will end up in the
      # environment in reverse order since they are each appended to the
      # beginning).
      while bindings
        env1 = Cons.new(Cons.new(bindings.car.car, eval_ly(bindings.car.cdr.car, env1)), env1)
        bindings = bindings.cdr
      end
      
      # Execute the body.
      eval_keep_last(body, env1)
    when :quote
      # Quotes a single expression so that it is not evaluated when
      # passed.
      if rest(expr).nil? || !(rest(rest(expr)).nil?)
        raise "quote takes exactly 1 argument"
      end
      second(expr)
    when :requote
      # Quotes a single expression so that it is not evaluated when
      # passed.
      if rest(expr).nil? || !(rest(rest(expr)).nil?)
        raise "quote takes exactly 1 argument"
      end
      list(:quote, eval_ly(second(expr), env))
    when :"def-macro"
      # Same as define, but the 'ismacro' parameter is true.
      # Form: `(def-macro (name arg0 arg1 ...) body...)`
      evdefine(rest(expr), env, true)
    else
      # Here, the expression will have a form like the following:
      # (func arg0 arg1 ...)
      # The function corresponding to the symbol ('func in this example)
      # is fetched from the environment.
      # If the function is a macro, the arguments are not evaluated before
      # executing the macro. Otherwise, the arguments are evaluated and
      # the function is called.
      
      # Find value of symbol in env and call it as a function
      func = eval_ly(first(expr), env)
      
      # The arguments which will be passed to the function.
      args = rest(expr)
      
      # If `expr` had the form `((...) ...)`, then the result of the
      # inner cons must be executed too.
      func = eval_ly(func, env) if func.is_a?(Cons)
      
      if func.ismacro
        # The macro is first called and the resulting expression
        # is then executed.
        r1 = func.call(args, env)
        eval_ly(r1, env)
      else
        # Check whether a tailcall is possible
        # A tailcall is possible if the function is not natively implemented
        # and the same function is at the front of the call stack.
        # So `(define (crash n) (crash (inc n)))` will tail call,
        # but `(define (crash) (inc (crash)))` will not.
        # Notice that the special commands if, let* and let (and all macros
        # which boil down to them, like `begin`) do not go on the callstack.
        # So `(define (dotimes n f)
        #       (if (= 0 n) '() (begin (f) (dotimes (dec n) f))))`
        # will also tail call.
        if !is_in_call_params && !func.native? && (!$lyra_call_stack.nil?) && (func == $lyra_call_stack.car)
          # Evaluate arguments that will be passed to the call.
          args = eval_list(args, env)
          # Tail call
          raise TailCall.new(args)
        else
          $lyra_call_stack = Cons.new(func, $lyra_call_stack)          
          
          # Evaluate arguments that will be passed to the call.
          args = eval_list(args, env)
          
          #puts $lyra_call_stack
          
          # Call the function with the new arguments
          r = func.call(args, env)
    
          # Remove from the callstack.
          $lyra_call_stack = $lyra_call_stack.cdr
          
          r
        end
      end
    end
  else
    # The expr is not nil, not a cons and not a symbol.
    # Thus, it is an atom and evaluates to itself.
    expr
  end
end

# Treat the first console argument as a filename,
# read from the file and evaluate the result.
begin
  evalstr(IO.read("core.lyra"))
  ARGV.each do |f|
    evalstr(IO.read(f))
  end
rescue
  $stderr.puts "Internal callstack: " + $lyra_call_stack.to_s
  $stderr.puts "Error: " + $!.message
  #raise
end
