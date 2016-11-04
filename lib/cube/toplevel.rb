module Cube
  def self.mark_interface!(cls, iface)
    Cube[cls].as_interface(iface, runtime_checks: false)
    cl_iface = iface.impotent
    cls.include(cl_iface)
  end

  def self.[](mod)
    return mod if mod.is_a?(CubeMethods)
    unless mod.is_a?(Class)
      raise ArgumentError, "Only classes can be be converted to Cube classes"
    end
    Class.new(mod).extend(CubeMethods)
  end

  def self.with_super(mod)
    self[Class.new(mod)]
  end

  class << self
    alias_method :from, :[]
  end

  def self.interface(&block)
    mod = Module.new
    mod.extend(Cube::Interface)
    mod.instance_variable_set('@ids', {})
    mod.instance_eval(&block)
    mod
  end

  def self.trait(&blk)
    m = Module.new
    m.extend(Cube::Trait)
    m.module_exec(&blk) if block_given?
    m
  end

  def self.check_type_spec(t, v, &blk)
    if t.is_a?(Set)
      if v.is_a?(Set)
        if v != t
          raise Cube::Interface::TypeMismatchError, "#{t.to_a} is not eql to #{v.to_a}"
        end
        return true
      end
      unless t.any? { |tp| check_type(tp, v, &blk) rescue false }
        raise Cube::Interface::TypeMismatchError,
          "#{v.inspect} is not any of #{t.to_a}"
      end
      return
    end
    if t.is_a? Array
      raise Cube::Interface::TypeMismatchError,
        "#{v} is not an Array" unless v.is_a? Array
      check_type(t.first, v.first, &blk)
      check_type(t.first, v.last, &blk)
      return
    end
    raise Cube::Interface::TypeMismatchError, "#{v.inspect} is not type #{t}" unless blk.call(t, v) 
    true
  end

  if ENV['RUBY_CUBE_TYPECHECK'].to_i > 0
    def self.check_type(t, v)
      if t.is_a?(Set)
        unless t.any? { |tp| check_type(tp, v) rescue false }
          raise Cube::Interface::TypeMismatchError,
                "#{v.inspect} is not any of #{t.to_a}"
        end
        return
      end
      if t.is_a? Array
        raise Cube::Interface::TypeMismatchError,
              "#{v} is not an Array" unless v.is_a? Array
        check_type(t.first, v.first)
        check_type(t.first, v.last)
        return
      end
      raise Cube::Interface::TypeMismatchError, "#{v.inspect} is not type #{t}" unless v.is_a? t
      true
    end
  else
    def self.check_type(*_); end
  end

  module CubeMethods
    def as_interface(iface, runtime_checks: true)
      raise ArgumentError, "#{iface} is not a Cube::Interface" unless iface.is_a?(Cube::Interface)
      implements = lambda { |this|
        unless this.is_a? Class
          raise "Non-Class modules cannot implement interfaces"
        end
        this.instance_variable_set(:@__interface_runtime_check, true) if runtime_checks
        this.include(iface)
      }
      implements.call(clone)
    end


    def shell_implements(mod)
      instance_variable_set(:@__interface_runtime_check, false)
      instance_variable_set(:@__interface_arity_skip, true)
      include(mod)
    end
  end
end

