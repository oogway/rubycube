#####################################################
# test_interface.rb
#
# Test suite for the Interface module.
#####################################################
ENV['RUBY_CUBE_TYPECHECK'] = "1"
require 'test-unit'
require 'cube'


class TC_Interface < Test::Unit::TestCase
  def self.startup
    alpha_interface = Cube.interface{
      public_visible(:alpha, :beta)
      proto(:beta) { [Integer, NilClass].to_set }
      proto(:delta, Integer, String, Integer) { Integer }
    }

    gamma_interface = Cube.interface{
      extends alpha_interface
      public_visible :gamma
    }

    # Workaround for 1.9.x
    @@alpha_interface = alpha_interface
    @@gamma_interface = gamma_interface

    eval("class A; end")

    eval("
      class B
        def alpha; end
        def beta; end
        def delta(a, b, c=nil); 0; end
      end
    ")

    eval("
      class C
        def alpha; end
        def beta; end
        def gamma; end
        def delta(a); end
      end
    ")
  end


  def checker_method(arg)
    Cube.check_type(@@gamma_interface, arg)
  end

  def test_version
    assert_equal('0.2.0', Cube::Interface::VERSION)
  end

  def test_interface_requirements_not_met
    assert_raise(Cube::Interface::PublicVisibleMethodMissing){ A.extend(@@alpha_interface) }
    assert_raise(Cube::Interface::PublicVisibleMethodMissing){ A.new.extend(@@alpha_interface) }
  end

  def test_sub_interface_requirements_not_met
    assert_raise(Cube::Interface::PublicVisibleMethodMissing){ B.extend(@@gamma_interface) }
    assert_raise(Cube::Interface::PublicVisibleMethodMissing){ B.new.extend(@@gamma_interface) }
  end

  def test_alpha_interface_requirements_met
    assert_nothing_raised{ B.new.extend(@@alpha_interface) }
  end

  def test_gamma_interface_requirements_met
    assert_raise(Cube::Interface::MethodArityError) { C.new.extend(@@gamma_interface) }
    assert_raise(Cube::Interface::MethodArityError) { Cube[C].as_interface(@@gamma_interface) }
  end

  def test_method_check
    assert_raise(Cube::Interface::TypeMismatchError) { checker_method(Cube[B].as_interface(@@alpha_interface).new) }
  end

  def test_runtime_error_check
    assert_nothing_raised {
      Cube[Cube[B]]
    }
    assert(Cube[B].is_a?(Cube::CubeMethods))
    assert_raise(ArgumentError) {
      Cube[@@gamma_interface]
    }
    assert_nothing_raised {
      Cube[B].as_interface(@@alpha_interface).as_interface(@@alpha_interface)
    }
    assert_nothing_raised {
      Cube[B].as_interface(@@alpha_interface, runtime_checks: true).new.beta
    }
    assert_raise(ArgumentError) {
      Cube[B].as_interface(@@alpha_interface).new.delta
    }
    assert_raise(ArgumentError) {
      Cube[B].as_interface(@@alpha_interface).new.delta(1)
    }
    assert_raise(Cube::Interface::TypeMismatchError) {
      Cube[B].as_interface(@@alpha_interface).new.delta(1, 2)
    }
    assert_raise(Cube::Interface::TypeMismatchError) {
      Cube[B].as_interface(@@alpha_interface).new.delta(1, "2", "3")
    }
    assert_nothing_raised {
      Cube[B].as_interface(@@alpha_interface).new.delta(1, "2")
    }
    assert_nothing_raised {
      Cube[B].as_interface(@@alpha_interface).new.delta(1, "2", 3)
    }
  end

  def test_shell
    sh = @@alpha_interface.shell
    sho = sh.new
    [:alpha, :beta].each do |m|
      assert_equal(sho.send(m), nil)
    end
  end
end
