# Lyra

Lyra is a lisp I make for fun and learning.

## Goals and priorities:

- The top goal is to finish something simple. The project will be slowly iterated upon.  
- Most functions will be implemented in Lyra itself if possible.  
- Simplicity > performance  
- Having fun

## Types:

Basic numbers: Integer, Float  
String  
Cons (car, cdr)  
Boolean (#t, #f)  
Function  

## Basic commands:

`(define <symbol> <value>)` Assigns a value to a symbol.  
`(lambda (<args>) <body>)` A function.  
`(define (<name> <args>) <body>)` Short for `(define <name> (lambda (<args>) <body>))`.  
`(cons <e0> <e1>)` Creates a pair of elements.  
`(car <pair>)` Get the first element of a Cons.  
`(cdr <pair>)` Get the second element of a Cons / the rest of a list.  
`(list ...)` Creates a list (chained conses).  
`(if <predicate> <then> <else>)` Common if. Executes the predicate. If it is true, evaluates `then`, if not, evaluates `else`.

```
Notice! Any functionf marked with '!' should only be used if you know what
you are doing!

Natively implemented:
Function | Arity | Description
---------+-------+------------------------------------------------------------
define   | any   | Adds a variable or function to the global (!) environment.
lambda   | any   | Creates a new anonymous function.
let*     | any   | Adds a single variable to the local environment.
         |       |
=        | 2     | Checks 2 values for equality.
<        | 2     | Checks whether the first argument is less than the second.
>        | 2     | Checks whether the second argument is less than the first.
         |       | 
+        | 2     | Addition. Adding to a string also works.
-        | 2     | Subtraction
*        | 2     | Multiplication
/        | 2     | Division
%        | 2     | Modulo
&        | 2     | Bitwise and
|        | 2     | Bitwise or
^        | 2     | Bitwise xor
         |       | 
list     | any   | Creates a list ending with nil.
car      | 1     | Gets the car of a pair.
cdr      | 1     | Gets the cons of a pair.
cons     | 2     | Creates a new cons.
set-car! | 2     | Sets the car of a cons. (Unsafe!)
set-cdr! | 2     | Sets the cdr of a cons. (Unsafe!)
         |       | 
null?    | 1     | Checks equality to nil.
cons?    | 1     | Checks whether the value is a cons.
int?     | 1     | Checks whether the value is a int.
float?   | 1     | Checks whether the value is a float.
string?  | 1     | Checks whether the value is a string.
         |       | 
int      | 1     | Tries to convert a value to an int.
float    | 1     | Tries to convert a value to a float.
string   | 1     | Tries to convert a value to a string.
bool     | 1     | Triess to convert a value to a bool.
         |       | 
sprint!  | 2     | Prints a string (2nd argument) to a stream (1st argument).
sread!   | 1     | Reads a string from a stream.
slurp!   | 1     | Reads all contents of a file into a string.
spit!    | 2     | Writes a string (2nd argument) into a file (1st argument).
         |       | 
eval!    | 1     | Evaluates an expression.
parse    | 1     | Parses a string into an expression.
         |       | 
env!     | 0     | Gets the current (local) environment. Highly unsafe. 
         |       | Use at your own risk!
global-env!| 0   | Like env!, but ignores the local environment. Also unsafe.
time!    | 0     | Get the current time in seconds as a floating point number.

Untested: sprint!, sread!, slurp!, spit!, env!, set-car!, set-cdr!

Core functions:
Function | Arity | Description
---------+-------+------------------------------------------------------------
empty?   | 1     | Same as null?
inc      | 1     | Increment a number by 1
dec      | 1     | Decrement a number by 1
nth      | 2     | 
and      | any   | boolean and
or       | any   | boolean or
not      | 1     | boolean not
foldl    | 3     |
foldr    | 3     |
print!   | 1     | Prints a string to stdout.
println! | 1     | Prints a string to stdout followed by a newline.
read!    | 0     | Reads a string from stdin.
map      | 2     | 
map!     | 2     | Impure map. Modifies the each element. (!)
filter   | 2     | 

Untested: filter, and, or, not, foldl, foldr, map!


Variable | Description
---------+------------------------------
stdin    | Standard input stream.
stdout   | Standard output stream.
stderr   | Standard error stream.
NIL      | The empty list.
ENV      | Global environment.
```

## Missing features:

Quoted expressions: Currently, the `'` prefix only works on the empty list and symbols. Otherwise `(quote ...)` has to be used.

`import/require/load` command. This can probably be implemented as `(eval! (parse (slurp! file)))`, but I need to try.

"Curried" lambdas like the following: `(lambda (n) (lambda (m) (+ n m)))`  
This will fail because `n` won't be found when the inner lambda is called. The same happens with lambdas inside a `let*`.

## Videos:

https://www.youtube.com/playlist?list=PLatjRac4Qo4BQ-ksFWeYUt8FL03MnJVPK


