require_relative 'interfaces'
require 'delegate'

module Cube
  module Trait
    class MethodConflict < RuntimeError; end
    class IncludeError < RuntimeError; end

    def requires_interface(intf)
      unless intf.is_a? Cube::Interface
        raise ArgumentError, "#{intf} is not a Cube::Interface"
      end
      @__interface_trait_required_interface = intf
    end

    def append_features(mod)
      if mod.is_a?(Class) && !mod.is_a?(CubeMethods)
        raise IncludeError, "Traits can only be mixed into cube classes"
      end
      unless mod.instance_variable_defined?(:@__trait_allow_include) &&
        mod.instance_variable_get(:@__trait_allow_include)
        raise IncludeError, "Traits can only be mixed in using method `with_trait`"
      end
      conflicts = public_instance_methods & mod.public_instance_methods
      errors = conflicts.map { |c|
        meth = mod.instance_method(c)
        { meth: meth, owner: meth.owner } unless meth.owner.is_a?(Class)
      }.compact
      unless errors.empty?
        message = "\n" + errors.map { |e| e[:meth].to_s }.join("\n")
        raise MethodConflict, message
      end
      if @__interface_trait_required_interface && mod.is_a?(Class)
        intf = @__interface_trait_required_interface
        mod.include?(intf) || mod.as_interface(intf, runtime_checks: false)
      end
      super
    end

    def wrap(intf)
      assert_match(intf)
      cls = Class.new(SimpleDelegator) do
        define_method(:initialize) do |obj|
          $stderr.puts "Checking with #{intf}"
          Cube.check_type(intf, obj)
          super(obj)
        end
      end
      inc_trait = clone
      inc_trait.instance_variable_set(:@__interface_trait_required_interface, nil)
      inc_trait.instance_variable_set(:@__trait_cloned_from, self)
      Cube[cls].with_trait(inc_trait)
    end

    def assert_match(intf)
      self_methods = instance_methods
      inherited = self.ancestors.select{ |x| Trait === x }
      required_interface_spec = inherited.inject({}) { |acc, x|
        req = x.instance_variable_get('@__interface_trait_required_interface')
        if req
          acc.merge(req.to_spec)
        else
          acc
        end
      }
      self_methods.each do |sm|
        required_interface_spec.delete(sm)
      end
      Interface.match_specs(required_interface_spec, intf.to_spec)
    end
  end
end

class Module
  def with_trait(trait, rename: {}, suppress: [])
    unless trait.is_a? Cube::Trait
      raise ArgumentError, "#{trait} is not an Cube::Trait"
    end
    cls = clone
    cls.instance_variable_set(:@__trait_allow_include, true)
    cls.instance_variable_set(:@__trait_cloned_from, self)
    raise ArgumentError, "aliases must be a Hash" unless rename.is_a?(Hash)
    raise ArgumentError, "supresses must be a Array" unless suppress.is_a?(Array)

    al_trait = trait_with_resolutions(trait, rename, suppress)
    al_trait.instance_variable_set(:@__interface_runtime_check, false)
    cls.include(al_trait)
    cls
  end

  private

  def trait_with_resolutions(trait, aliases, suppress)
    cl = trait.clone
    cl.module_exec do
      suppress.each do |sup|
        remove_method(sup)
      end
      aliases.each do |before, after|
        begin
          alias_method(after, before)
        rescue => e
          $stderr.puts "with_trait(#{trait}): #{e.message}"
          raise ArgumentError, "with_trait(#{trait}): #{e.message}"
        end
        remove_method(before)
      end
    end
    cl
  end
end
