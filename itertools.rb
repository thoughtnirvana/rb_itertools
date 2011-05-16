#!/usr/bin/env ruby

# Monkey patching `Fiber`.
# Python's generators work in `for el in generator:` cases
# and the `itertools` library is built around that assumption
# If Ruby's generators don't work that way, it will limit the
# usefulness of library.
class Fiber
  include Enumerable 
  def each
    loop { yield self.resume }
  end
end

# Monkey patching String.
# We can't have two different code paths for strings and
# other iterables.
class String
  alias :each :each_char 
end

# Port of Python itertools.
# http://docs.python.org/library/itertools.html
module Itertools
  module_function

  # Converts a regular `iterable` to a fiber.
  # If the `iterable` is already a fiber, return it as is.
  def iter(iterable)
    return iterables if iterable.is_a? Fiber
    Fiber.new {
      iterable.each {|el| Fiber.yield el }
      raise StopIteration
    }
  end

  # chain [1, 2, 3], [4, 5] --> 1 2 3 4 5
  def chain(*iterables)
    Fiber.new {
      iterables.each {|it| it.each {|el| Fiber.yield el } }
      raise StopIteration
    }
  end

  # chain.from_iterable [[1, 2, 3], [4, 5]] --> 1 2 3 4 5
  def from_iterable(iterable)
    Fiber.new {
      iterable.each {|it| it.each {|el| Fiber.yield el } }
      raise StopIteration
    }
  end

  # icombination 'ABCD', 2 --> AB AC AD BC BD CD
  def icombination(iterable, r)
    Fiber.new {
      n = iterable.size
      return if r > n
      range = (0..(r-1))
      indices = range.to_a
      Fiber.yield indices.collect {|idx| iterable[idx] }
      while true
        for i in range.reverse_each
          break if indices[i] != i + n - r
        end and raise StopIteration
        indices[i] += 1
        ((i+1)..(r-1)).each {|j| indices[j] = indices[j-1] + 1 }
        Fiber.yield indices.collect {|idx| iterable[idx] }
      end
    }
  end

  # icombination_r 'ABC', 2 --> AA AB AC BB BC CC
  def icombination_r(iterable, r)
    Fiber.new {
      n = iterable.size
      return if r > n
      range = (0..(r-1))
      indices = [0] * r 
      Fiber.yield indices.collect {|idx| iterable[idx] }
      while true
        for i in range.reverse_each
          break if indices[i] != n - 1
        end and raise StopIteration
        indices[i..-1] = [indices[i] + 1] * (r - i)
        Fiber.yield indices.collect {|idx| iterable[idx] }
      end
    }
  end

  # compress 'ABCDEF', [1,0,1,0,1,1] --> A C E F
  def compress(data, selectors)
    data.zip(selectors).collect {|d, s| d unless s.zero? }.compact
  end

  # count 10 --> 10 11 12 13 14 ...
  # count 2.5, 0.5 -> 2.5 3.0 3.5 ...
  def count(start=0, step=1)
    Fiber.new {
      n = start
      while true
        Fiber.yield n
        n += step
      end
    } 
  end

  # cycle 'ABCD' --> A B C D A B C D A B C D ...
  def cycle(iterable) 
    Fiber.new {
      saved = []
      iterable.each {|el| Fiber.yield el; saved << el } 
      while saved
        saved.each {|el| Fiber.yield el }
      end
    }
  end

  # dropwhile [1,4,6,4,1] {|x| x < 5 } --> 6 4 1
  def dropwhile(iterable)
    Fiber.new {
      iterable = iter(iterable)
      iterable.each do |el|
        if not yield el
          Fiber.yield el
          break
        end
      end
      iterable.each {|el| Fiber.yield el }
      raise StopIteration
    }
  end

  # ifilter (1..10) {|x| x > 5 } --> 6 7 8 9 10 
  def ifilter(iterable)
    Fiber.new {
      iterable.each {|el| Fiber.yield el if yield el }
      raise StopIteration
    }
  end

  # ifilterfalse (1..10) {|x| x > 5 } --> 1 2 3 4 5 
  def ifilterfalse(iterable)
    Fiber.new {
      iterable.each {|el| Fiber.yield el unless yield el }
      raise StopIteration
    }
  end

  # imap [2,3,10], [5,2,3] {|x, y| x**y } --> 32 9 1000
  def imap(*iterables)
    Fiber.new {
      iterables = iterables.map {|it| iter(it) }
      while true
        args = iterables.map {|it| it.enum_for(:each).next }
        Fiber.yield yield *args
      end
    }
  end

  # izip 'ABCD', 'xy' --> Ax By
  def izip(*iterables)
    Fiber.new {
      iterables = iterables.map {|it| iter(it) }
      while iterables
        Fiber.yield iterables.map {|it| it.enum_for(:each).next }
      end
    }
  end

  # ipermutation 'ABCD', 2 --> AB AC AD BA BC BD CA CB CD DA DB DC
  def ipermutation(iterable, r=nil)
    Fiber.new {
      n = iterable.size
      r = n if r.nil?
      return if r > n
      indices = (0..(n-1)).to_a
      cycles = n.downto(n-r-1).to_a
      Fiber.yield indices[0..(r-1)].collect {|idx| iterable[idx] }
      while n
        for i in (0..(r-1)).reverse_each
          cycles[i] -= 1
          if cycles[i] == 0
            indices[0..(i-1)] = indices[i+1..-1] + indices[i..i]
            cycles[i] = n - 1
          else
            j = cycles[i]
            indices[i], indices[-j] = indices[-j], indices[i]
            Fiber.yield indices[0..(r-1)].collect {|idx| iterable[idx] }
            break
          end
        end and raise StopIteration
      end
    }
  end

  # repeat 10, 3 --> 10 10 10
  def repeat(object, times=nil)
    Fiber.new {
      if times.nil?
        while true
          Fiber.yield object
        end
      else
        times.times { Fiber.yield object }
        raise StopIteration
      end
    }
  end

  # starmap [[2, 5], [3, 2], [10, 3]] {|x, y| x**Y } --> 32 9 1000
  def starmap(iterable)
    Fiber.new {
      for args in iterable
        Fiber.yield yield *args
      end
      raise StopIteration
    }
  end

  # takewhile [1,4,6,4,1] {|x| x<5} --> 1 4
  def takewhile(iterable)
    Fiber.new {
      for el in iterable
        if yield el
          Fiber.yield el
        else
          break
        end
      end
      raise StopIteration
    }
  end
end
