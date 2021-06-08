# Lyra

Lyra is a lisp I make for fun and learning.

## Goals and priorities:

- The top goal is to finish something simple. The project will be slowly iterated upon.  
- Most functions will be implemented in Lyra itself if possible.  
- Simplicity > performance  
- Having fun

## Features:

- Different numeric types: Integer and Float  
- Macros  
- Tail recursion  
- Access to the environment for people who know what they are doing.  
- Basic implementation for maps.  
- Many TODOs :D

## Types:

- Basic numbers: Integer, Float  
- String  
- Cons (car, cdr)  
- Boolean (#t, #f)  
- Function  

## Basic commands:

`(define <symbol> <value>)` Assigns a value to a symbol.  
`(lambda (<args>) <body>)` A function.  
`(define (<name> <args>) <body>)` Short for `(define <name> (lambda (<args>) <body>))`.  
`(if <predicate> <then> <else>)` Common if. Executes the predicate. If it is true, evaluates `then`, if not, evaluates `else`.  

`(cond <clauses>)` Each clause has the form `(<predicate> <expr>)`.  
Example:
```(cond ((vector? e) (foo e)) 
((list? e) (bar e)) 
#t (baz e))```  

```
Notice! Any function marked with '!' should only be used if you know what
you are doing!

Natively implemented:
Function             | Arity | Description
---------------------+-------+------------------------------------------------------------
define               | any   | Adds a variable or function to the global (!) environment.
lambda               | any   | Creates a new anonymous function.
let*                 | >=1   | Adds a single variable to the local environment.
let                  | >=1   | Like let* but for multiple variables.
                     |       | 
=                    | 2     | Checks 2 values for equality.
<                    | 2     | Checks whether the first argument is less than the second.
>                    | 2     | Checks whether the second argument is less than the first.
                     |       | 
+                    | 2     | Addition. Adding to a string also works.
-                    | 2     | Subtraction
*                    | 2     | Multiplication
/                    | 2     | Division
%                    | 2     | Modulo
&                    | 2     | Bitwise and
^                    | 2     | Bitwise xor
                     |       | 
list                 | any   | Creates a list ending with nil.
car                  | 1     | Gets the car of a pair.
cdr                  | 1     | Gets the cons of a pair.
cons                 | 2     | Creates a new cons.
set-car!             | 2     | Sets the car of a cons. (Unsafe!)
set-cdr!             | 2     | Sets the cdr of a cons. (Unsafe!)
                     |       | 
null?                | 1     | Checks equality to nil.
cons?                | 1     | Checks whether the value is a cons.
int?                 | 1     | Checks whether the value is a int.
float?               | 1     | Checks whether the value is a float.
string?              | 1     | Checks whether the value is a string.
vector?              | 1     | Checks whether the value is a vector.
symbol?              | 1     | Checks whether the value is a symbol.
                     |       | 
int                  | 1     | Tries to convert a value to an int.
float                | 1     | Tries to convert a value to a float.
string               | 1     | Tries to convert a value to a string.
bool                 | 1     | Triess to convert a value to a bool.
                     |       | 
sprint!              | 2     | Prints a string (2nd argument) to a stream (1st argument).
sread!               | 1     | Reads a string from a stream.
slurp!               | 1     | Reads all contents of a file into a string.
spit!                | 2     | Writes a string (2nd argument) into a file (1st argument).
                     |       | 
eval!                | 1     | Evaluates an expression.
parse                | 1     | Parses a string into an expression.
                     |       | 
env!                 | 0     | Gets the current (local) environment. Highly unsafe.
global-env!          | 0     | Like env!, but ignores the local environment. Also unsafe.
                     |       | 
time!                | 0     | Get the current time in seconds as a floating point number.
measure              | 2     | Runs a function (2nd argument) n (1st argument) times.

Untested: sprint!, sread!, slurp!, spit!, env!

Core functions:
Function             | Arity | Description
---------------------+-------+------------------------------------------------------------
eq?                  | 2     | Alias for =
eql?                 | 2     | Alias for =
<=                   | 2     | Less than or equal to.
>=                   | 2     | Greater than or equal to.
load!                | 1     | Imports another source file by filename.
require!             | 1     | Alias for load!
import!              | 1     | Alias for load!
comment              | any   | A macro which ignores its body.
first                | 1     | First element of a collection.
second               | 1     | Second element of a collection.
third                | 1     | Third element of a collection.
rest                 | 1     | Rest element of a collection.
ffirst               | 1     | Alias for (first (first e))
sfirst               | 1     | Alias for (second (first e))
rfirst               | 1     | Alias for (rest (first e))
length               | 1     | Length of a collection. 0 for atomic types.
begin                | 2     | Takes two arguments and executes them both.
                     |       | 
deprioritise-helper! |       | Helper for deprioritise!. Do not use or override!
deprioritise!        | 1     | Moves a variable (if found) to the end of the global
                     |       | environment.
index-in-env-helper! |       | Helper for index-in-env!. Do not use or override!
index-in-env!        | 1     | Finds the index of a variable in the global environment.
                     |       | -1 if the symbol could not be found.
                     |       | 
empty?               | 1     | Same as null?
inc                  | 1     | Increment a number by 1
dec                  | 1     | Decrement a number by 1
nth                  | 2     | 
and                  | 2     | boolean and
or                   | 2     | boolean or
not                  | 1     | boolean not
foldl                | 3     |
foldr                | 3     |
print!               | 1     | Prints a string to stdout.
println!             | 1     | Prints a string to stdout followed by a newline.
read!                | 0     | Reads a string from stdin.
map                  | 2     | 
map!                 | 2     | Impure map. Modifies the each element. (!)
filter               | 2     | 
; TODO Update the list above.

associative.lyra functions:
Function             | Arity | Description
---------------------+-------+------------------------------------------------------------
make-map             | 0     | 
map-to-string        | 1     | (Needs a re-work)
add-entry            | 3     | Adds an entry to a map and returns a new map. If the key 
                     |       | already exists, it is replaced.
add-entry!           | 3     | Adds or replaces an entry. The map is mutated.
remove-from-map      | 2     | Removes an entry from a map and returns a new map.
remove-from-map!     | 2     | Removes an entry from a map. The map is mutated.
get-value            | 2     | Gets a value from the map.

Untested: filter, and, or, not, foldl, foldr, map!


Variable | Description
---------+--------------------------------------------------------------------------------
#t #f    | True and false
'()      | The empty list (Also called 'nil'). Serves as the terminator for normal lists.
stdin    | Standard input stream.
stdout   | Standard output stream.
stderr   | Standard error stream.
nil      | Alias for '().
```

## Missing features:

Quoted expressions: Currently, the `'` prefix only works on the empty list and symbols. Otherwise `(quote ...)` has to be used.  

"Curried" lambdas like the following: `(lambda (n) (lambda (m) (+ n m)))`  
This will fail because `n` won't be found when the inner lambda is called. The same happens with lambdas inside a `let*`.  

A module-system to prevent messing with core-function-names. (Can easily happen when using `define`)  

## Videos:

https://www.youtube.com/playlist?list=PLatjRac4Qo4BQ-ksFWeYUt8FL03MnJVPK


