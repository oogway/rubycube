ENV['RUBY_INTERFACE_TYPECHECK'] = "1"
require 'interface'

# Drivable specifies an interface
# The arity of the stop method should be 1
# That arity of the other methods will not be validated
Drivable = interface do
  public_visible(:turn_left, :turn_right, :start, { stop: 1 })
end

# Car is an implementation of Drivable
class Car
  def turn_left; :left; end
  def turn_right; :right; end
  def start; end
  def stop(urgency); end

  # This will check when the methods in this class
  # satisfy the interface Drivable
  # This check happens at class definition time
  implements Drivable
end

# BadCar does not implement Drivable
class BadCar
  def turn_left; :error; end

  # The following line will raise an error if uncommented
  # implements Drivable
end

# Turnable interface for things that can turn
Turnable = interface do
  public_visible :turn_left, :turn_right
end

# Driver interface for things that can be driven
# Interfaces are composable
Driver = interface do
  include Turnable
  public_visible :start, :stop
end

# RaceDriver implements Driver
# It can be used as a trait which is mixed into other modules
# It can also be instantiated into an engine or driver object
module RaceDriver
  def turn_left; car.turn_left end
  def turn_right; car.turn_right end
  def start; car.start end
  def stop; car.stop end
  implements Driver

  extend Interface::Trait
  # Requires that the including module satisfy the interface given below
  # Here, an anonymous interface is defined dynamically
  # `private_visible` does not mean that the method has to be private.
  # It means that it must be visible in private scope. Thus it can
  # be defined in private or public scope in the including class/module.
  requires_interface(interface { private_visible :car })

  # To create an engine object from this trait, define
  # an engine constructor using `initiator`.
  # This creates a constructor method called `create`
  # The create method accepts an object which must satisfy
  # the `Drivable` interface. This object is available as 'car'
  # in the trait object (which is what is used in the methods above)
  instantiator :create, :car, Drivable
end

# Person is a class which implements `interface { private_visible :car }`
# specified as a requirement of the RaceDriver trait.
class Person
  def initialize(age:, car:)
    # Check that `car` implements Drivable
    # This check happens for every method call and introduces some
    # overhead, although it is negligible.
    # The `check_interface` method does nothing if ENV['RUBY_INTERFACE_TYPECHECK']
    # is not defined or is "0". This can be used to turn off this check in
    # production if the overhead is not acceptable.
    check_interface { { Drivable => car } }
    @age = age
    @car = car
  end

  private

  attr_reader :car
end

# 'Mixin' the RaceDriver trait
# This will perform the `requires_interface` check
Racer = Person.include(RaceDriver)

# Instantiate a trait object which wraps the object that is passed
# The interface specified in the `instantiator` call is checked
# here. I.e., Car should implement Drivable
racer = RaceDriver.create(Car.new) # Instantiated trait object

# Both methods should print `:left`
puts Racer.new(age: 20, car: Car.new).turn_left
puts racer.turn_left

# The line below will raise an error since BadCar does not satisfy
# Drivable and ENV['RUBY_INTERFACE_TYPECHECK'] has been set to "1"
# above
racer1 = RaceDriver.create(BadCar.new)

# If ENV['RUBY_INTERFACE_TYPECHECK'] is set to "0" above, the following
# line will print `:error`
puts racer1.turn_left
