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

## Videos:

https://www.youtube.com/playlist?list=PLatjRac4Qo4BQ-ksFWeYUt8FL03MnJVPK


