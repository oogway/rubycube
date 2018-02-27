# run as `RUBY_CUBE_TYPECHECK= 1 ruby examples/demo.rb`
#require_relative '../lib/cube'
require 'cube'
require 'dry-types'

module Types
  include Dry::Types.module
end

Adder = Cube.interface {
  # sum is a method that takes an array of Types::Strict::Int and returns an Types::Strict::Int
  proto(:sum, [Types::Strict::Int]) { Types::Strict::Int }
}

Calculator = Cube.interface {
  # interfaces can be composed
  extends Adder
  # method fact takes an Types::Strict::Int and returns an Types::Strict::Int
  proto(:fact, Types::Strict::Int) { Types::Strict::Int }
  # method pos takes an array of Types::Strict::Ints, an Types::Strict::Int, and returns either Types::Strict::Int or nil
  proto(:pos, [Types::Strict::Array], Types::Strict::Int) { Types::Strict::Int|Types::Strict::Nil }
}

class SimpleCalcImpl
  def fact(n)
    (2..n).reduce(1) { |m, e| m * e }
  end

  def sum(a)
    a.reduce(0, &:+)
  end

  def pos(arr, i)
    arr.index(i)
  end
end

SimpleCalc = Cube[SimpleCalcImpl].as_interface(Calculator)
# OR
# SimpleCalc = Cube.from(SimpleCalcImpl).as_interface(Calculator)
c = SimpleCalc.new
p c.sum([1, 2])
p c.pos([1, 2, 3], 4)

AdvancedCalculator = Cube.interface {
  extend Calculator
  proto(:product, Types::Strict::Int, Types::Strict::Int) { Types::Strict::Int }
  proto(:avg, [Types::Strict::Int]) { Types::Strict::Float }
}

ProductCalcT = Cube.trait do
  def product(a, b)
    ret = 0
    a.times { ret = sum([ret, b]) }
    ret
  end
  # This specifies the interface that the including Class must satisfy in order for
  # this trait to work properly.
  # Eg, the product method above uses `sum`, which it expects to get from the including
  # class
  requires_interface Adder # Note that this will give an error if SimpleCalc#sum is removed
                           # even if this trait itself has a `sum` method
end

StatsCalcT = Cube.trait do
  def product; end

  def avg(arr)
    arr.reduce(0, &:+) / arr.size
  end
end
#
# This is how we compose behaviours
# AdvancedCalc is a class which mixes traits AdvancedCalcT and DummyCalcT
# into SimpleCalc and implements the interface AdvancedCalculator
# To avoid conflicts, alias methods in AdvancedCalcT (otherwise error will be raised)
# One can also suppress methods in DummyCalcT
AdvancedCalc = SimpleCalc.with_trait(ProductCalcT)
                         .with_trait(StatsCalcT, suppress: [:product])
                         .as_interface(AdvancedCalculator)
sc = AdvancedCalc.new
p sc.product(3, 2)

__END__

# Benchmarks. Run with RUBY_INTERFACE_TYPECHECK=0 and 1 to compare

t1 = Time.now
1_000_000.times do
  c.fact(50)
end
t2 = Time.now

p t2 - t1
