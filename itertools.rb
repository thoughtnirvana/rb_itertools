# Port of Python itertools.
# http://docs.python.org/library/itertools.html
# Sadly the way Ruby module systems work, it isn't possible
# to define a new module and include it in Enumerable.
# module Itertools
#   def iter
#     ...
#   end
#   ...
# end
#
# module Enumerable
#   include Enumerable
# end
#
# This won't work for the cases where Enumerable has already been
# included. So we have two choices:
# 1. Functional implementation where the functions take the `Enumerable`
# as an argument.
# 2. Augment Enumberable itself.
#
# Augmenting Enumberable leads to cleaner code for the user.
# Functional::
#   f = icombination [1,2,3,4], 3  
#   f.each {|c| process c }
#
#   # Or alternatively:
#   icombination([1,2,3,4], 3).each {|c| process c }
#
# Chained:
#   [1,2,3,4].icombination(3).each {|c| process c }
# It basically boils down to personal preference.
module Enumerable 
  # Converts a regular `iterable` to a fiber.
  # If the `iterable` is already a fiber, return it as is.
  def iter
    return self if self.is_a? Fiber
    Fiber.new {
      self.each {|el| Fiber.yield el }
      raise StopIteration
    }
  end

  #[1,2,3].chain([4,5]).each {|x| print x, "\t" }
  #1       2       3       4       5 => nil 
  def chain(*iterables)
    Fiber.new {
      iterables.unshift self
      iterables.each {|it| it.each {|el| Fiber.yield el } }
      raise StopIteration
    }
  end

  #[[1,2,3], [4,5]].from_iterable.each {|x| print x, "\t" }
  #1       2       3       4       5        => nil 
  def from_iterable
    Fiber.new {
      self.each {|it| it.each {|el| Fiber.yield el } }
      raise StopIteration
    }
  end

  # [1,2,3].icombination(2).each {|c| print c, "\t" }
  # [1, 2]  [1, 3]  [2, 3]   => nil
  def icombination(r)
    Fiber.new {
      n = self.size
      return if r > n
      range = (0..(r-1))
      indices = range.to_a
      Fiber.yield indices.collect {|idx| self[idx] }
      while true
        for i in range.reverse_each
          break if indices[i] != i + n - r
        end and raise StopIteration
        indices[i] += 1
        ((i+1)..(r-1)).each {|j| indices[j] = indices[j-1] + 1 }
        Fiber.yield indices.collect {|idx| self[idx] }
      end
    }
  end

  # [1,2,3].icombination_r(2).each {|c| print c, "\t" }
  # [1, 1]  [1, 2]  [1, 3]  [2, 2]  [2, 3]  [3, 3]   => nil 
  def icombination_r(r)
    Fiber.new {
      n = self.size
      return if r > n
      range = (0..(r-1))
      indices = [0] * r 
      Fiber.yield indices.collect {|idx| self[idx] }
      while true
        for i in range.reverse_each
          break if indices[i] != n - 1
        end and raise StopIteration
        indices[i..-1] = [indices[i] + 1] * (r - i)
        Fiber.yield indices.collect {|idx| self[idx] }
      end
    }
  end

  # > [1,2,3,4].compress([1,0,1,0]).each {|c| print c, "\t" }
  # 1       3        => [1, 3] 
  def compress(selectors)
    self.zip(selectors).collect {|d, s| d unless s.zero? }.compact
  end



  # [1,2,3,4].ipermutation(2).each {|c| print c, "\t" }
  # [1, 2]  [1, 3]  [1, 4]  [4, 3]  [4, 2]  [4, 3]  [3, 2]  [3, 4]  [3, 2]  [4, 2]  [4, 2]  [4, 3]   => nil
  def ipermutation(r=nil)
    Fiber.new {
      n = self.size
      r = n if r.nil?
      return if r > n
      indices = (0..(n-1)).to_a
      cycles = n.downto(n-r-1).to_a
      Fiber.yield indices[0..(r-1)].collect {|idx| self[idx] }
      while n
        for i in (0..(r-1)).reverse_each
          cycles[i] -= 1
          if cycles[i] == 0
            indices[0..(i-1)] = indices[i+1..-1] + indices[i..i]
            cycles[i] = n - 1
          else
            j = cycles[i]
            indices[i], indices[-j] = indices[-j], indices[i]
            Fiber.yield indices[0..(r-1)].collect {|idx| self[idx] }
            break
          end
        end and raise StopIteration
      end
    }
  end

  # [1].repeat(3).each {|c| print c }
  # [1][1][1] => nil 
  def repeat(times=nil)
    Fiber.new {
      if times.nil?
        while true
          Fiber.yield self 
        end
      else
        times.times { Fiber.yield self }
        raise StopIteration
      end
    }
  end

  # [[2,5], [3,2]].starmap{|x, y| x**y }.each {|c| print c, "\t" }
  # 32      9        => nil
  def starmap
    Fiber.new {
      for args in self 
        Fiber.yield yield *args
      end
      raise StopIteration
    }
  end

  # [1,2,3,4].powerset(3) {|p| p.each {|subset| print subset } }
  # [1, 2, 3][1, 2, 4][1, 3, 4][2, 3, 4][1, 2, 3, 4] => 3..4 
  def powerset(initial=0)
    (initial..size).each {|i| yield icombination(i) }
  end
end

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

  # Consume n items.
  def consume(n)
    n.times do
      if block_given?
        yield self.resume
      else
        self.resume
      end
    end
  end

  def nth(n)
    (n-1).times { self.resume }
    yield self.resume
  end
end
