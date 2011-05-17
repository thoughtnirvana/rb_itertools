rb_itertools
============


Introduction
------------

Inspired by Python's [itertools][iter]. Ruby already has a pretty strong `Enumerable` module which provides many useful iteration/enumeration stuff. But sometimes we would like things to be a bit lazy.

With introduction of `Fiber` in Ruby 1.9, generators are very easy to implement. `Fiber` was introduced in Ruby 1.9 and therefore, all code in this library is 1.9 specific.


Fibers and generators
---------------------

This library is just a port of few things I would want to use in my projects. The genreal idea is to use `Fiber` for lazy/infinite sequences and consume what you need. Not all problems can be modelled in this way - if you are going to realize the whole sequence, you are better off coding non-lazy sequences from the very beginning.


**Obligatory Fiber example**

*The Ruby Programming Language* book defines fibers as:

> Ruby 1.9 introduces a control structure known as a fiber and represented by an object of class Fiber. The name "fiber" has been used elsewhere for a kind of lightweight thread, but Ruby's fibers are better described as coroutines or, more accurately, semicoroutines. The most common use for coroutines is to implement generators: objects that can compute a partial result, yield the result back to the caller, and save the state of the computation so that the caller can resume that computation to obtain the next result.


The general use case for fibers is implementing generators for partial results, though you can use them for cooperative multitasking if you so wish.

So, without fibers, an infinite `fib_gen` looks like this:

    def fib_gen
      a, b = 0, 1
      while true
        yield a
        a, b = b, a + b
      end
    end

    fib_gen {|x| puts x; break if x > 100 }


With fibers, the same generator would be coded like this:

    def fib_gen
      Fiber.new {
        a, b = 0, 1
        while true
          Fiber.yield a
          a, b = b, a +b
        end
      }
    end

    f = fib_gen
    100.times { puts f.resume }

The not so obvious difference between the two is the generators implemented using fibers preserve state. If you call

    100.times { puts f.resume }

again, you will get the next 100 fibonacci numbers. With the regular iterators, you don't preserve state - the first example

    fib_gen {|x| puts x; break if x > 100 }

will give you the same numbers everytime you run them.


You should look up following resources if you are interested in learning more about generators and fibers.

[Dave Thomas - fibers part 1][dave1]

[Dave Thomas - fibers part 2][dave2]

[Python generators tricks][pythongen]


Examples
--------

This project is quite raw and basically done for my personal use. If you find it useful, would like to report issues, would like to fix issues - you are more than welcome to do so.

To use this library, you just need to make sure `itertools.rb` is in your path and then:

    require 'itertools'

`Fiber` has been monkey patched to include `Enumerable` and the fibers returned from these calls support all Enumberable methods.

     > f = 'ruby'.split("").icombination(3)
    => #<Fiber:0x00000001e400b0>

    > f.select {|x| x[0] == 'r' }
    => [["r", "u", "b"], ["r", "u", "y"], ["r", "b", "y"]]

The examples show `each` but the whole `Enumerable` methods are supported.

One thing to note here is fibers preserve state - that means you can run into `FiberError` if you try to access a fiber which has completed.

    > f = 'ruby'.split("").icombination(3)
    => #<Fiber:0x00000001ea1590>

    > f.select {|x| x[0] == 'r' }
    => [["r", "u", "b"], ["r", "u", "y"], ["r", "b", "y"]] 

    > f.select {|x| x[0] == 'r' }
    FiberError: dead fiber called
    ...


*  **chain**

    [1,2,3].chain([4,5], [6,7,8]).each {|x| print x, "\t" }
    1       2       3       4       5       6       7       8        => nil 


*  **from_iterable**

    [[1,2,3], [4,5]].from_iterable.each {|x| print x, "\t" }
    1       2       3       4       5        => nil 


*  **icombination**

The ruby library already provides a combination function for arrays.

    [1,2,3].combination(2) {|c| print c, "\t" }
    [1, 2]  [1, 3]  [2, 3]   => [1, 2, 3] 

icombination does the same thing - it just implements it as generator using fibers.

    [1,2,3].icombination(2).each {|c| print c, "\t" }
    [1, 2]  [1, 3]  [2, 3]   => nil


*  **icombination_r**

Combinations with repetitions.

    [1,2,3].icombination_r(2).each {|c| print c, "\t" }
    [1, 1]  [1, 2]  [1, 3]  [2, 2]  [2, 3]  [3, 3]   => nil 


*  **compress**

    [1,2,3,4].compress([1,0,1,0]).each {|c| print c, "\t" }
    1       3        => [1, 3] 


*  **ipermutation**

    [1,2,3,4].ipermutation(2).each {|c| print c, "\t" }
    [1, 2]  [1, 3]  [1, 4]  [4, 3]  [4, 2]  [4, 3]  [3, 2]  [3, 4]  [3, 2]  [4, 2]  [4, 2]  [4, 3]   => nil


*  repeat

    [1].repeat(3).each {|c| print c }
    [1][1][1] => nil 


*  **starmap**

    [[2,5], [3,2]].starmap{|x, y| x+y }.each {|c| print c, "\t" }
    7      5        => nil


*  **powerset** 

    [1,2,3].powerset {|p| p.each {|subset| print subset } }
    [][1][2][3][1, 2][1, 3][2, 3][1, 2, 3] => 0..3


    > [1,2,3,4].powerset(3) {|p| p.each {|subset| print subset } }
    [1, 2, 3][1, 2, 4][1, 3, 4][2, 3, 4][1, 2, 3, 4] => 3..4 



[iter]: http://docs.python.org/library/itertools.html
[dave1]: http://pragdave.blogs.pragprog.com/pragdave/2007/12/pipelines-using.html
[dave2]: http://pragdave.blogs.pragprog.com/pragdave/2008/01/pipelines-using.html
[pythongen]: http://www.dabeaz.com/generators/


