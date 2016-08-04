require 'securerandom'
require 'set'
# A module for implementing Java style interfaces in Ruby. For more information
# about Java interfaces, please see:
#
# http://java.sun.com/docs/books/tutorial/java/concepts/interface.html
#

# Top level module for RubyCube
module Cube
  module Interface

    def self.match_specs(i1specs, i2specs)
      i1specs.each do |meth, i1spec|
        i2spec = i2specs[meth]
        raise InterfaceMatchError, "Method `#{meth}` not found" unless i2spec
        i2_in = i2spec[:in]
        i1_in = i1spec[:in]
        if i1_in && (!i2_in || i1_in.size != i2_in.size)
          raise InterfaceMatchError, "Method `#{meth}` prototype does not match"
        end
        (i1_in || []).each_index do |i|
          Cube.check_type_spec(i1_in[i], i2_in[i]) { |t1, t2| t2 == t1 }
        end
        i1_out = i1spec[:out]
        if i1_out
          i2_out = i2spec[:out]
          raise InterfaceMatchError, "Method `#{meth}` prototype does not match" unless i2_out
          Cube.check_type_spec(i1_out, i2_out) { |t1, t2| t2 == t1 }
        end
      end
    end
    # The version of the interface library.
    Interface::VERSION = '0.2.0'

    # Exceptions thrown while checking interfaces
    class MethodMissing < RuntimeError; end
    class PrivateVisibleMethodMissing < MethodMissing; end
    class PublicVisibleMethodMissing < MethodMissing; end
    class MethodArityError < RuntimeError; end
    class TypeMismatchError < RuntimeError; end
    class InterfaceMatchError < RuntimeError; end

    alias :extends :extend

    private

    # convert a proc to lambda
    def convert_to_lambda &block
      obj = Object.new
      obj.define_singleton_method(:_, &block)
      return obj.method(:_).to_proc
    end

    def extend_object(obj)
      return append_features(obj) if Interface === obj
      append_features(class << obj; self end)
      included(obj)
    end

    # This is called before `included`
    def append_features(mod)
      return super if Interface === mod

      # Is this a sub-interface?
      # Get specs from super interfaces
      inherited = (self.ancestors-[self]).select{ |x| Interface === x }
      inherited_ids = inherited.map{ |x| x.instance_variable_get('@ids') }

      # Store required method ids
      inherited_specs = map_spec(inherited_ids.flatten)
      specs = to_spec
      ids = @ids.keys + map_spec(inherited_ids.flatten).keys
      @unreq ||= []

      # Iterate over the methods, minus the unrequired methods, and raise
      # an error if the method has not been defined.
      mod_public_instance_methods = mod.public_instance_methods(true)
      (ids - @unreq).uniq.each do |id|
        id = id.to_s if RUBY_VERSION.to_f < 1.9
        unless mod_public_instance_methods.include?(id)
          raise Interface::PublicVisibleMethodMissing, "#{mod}: #{self}##{id}"
        end
        spec = specs[id]
        if spec.is_a?(Hash) && spec.key?(:in) && spec[:in].is_a?(Array)
          # Check arity and replace method with type checking method
          replace_check_method(mod, id, spec[:in], spec[:out])
        end
      end

      super mod
    end

    # Stash a method in the module for future checks
    def stash_method(mod, id)
      unless mod.instance_variable_defined?('@__interface_stashed_methods')
        mod.instance_variable_set('@__interface_stashed_methods', {})
      end
      mod.instance_variable_get('@__interface_stashed_methods')[id] = mod.instance_method(id)
    end

    # Get a stashed method for the module
    def stashed_method(mod, id)
      return nil unless mod.instance_variable_defined?('@__interface_stashed_methods')
      mod.instance_variable_get('@__interface_stashed_methods')[id]
    end

    # Check arity
    # Replace with type_checking method if demanded
    def replace_check_method(mod, id, inchecks, outcheck)
      # Get the previously stashed method if it exists
      stashed_meth = stashed_method(mod, id)
      orig_method = stashed_meth || mod.instance_method(id)
      unless mod.instance_variable_defined?("@__interface_arity_skip") \
        && mod.instance_variable_get("@__interface_arity_skip")
        orig_arity = orig_method.parameters.size
        check_arity = inchecks.size
        if orig_arity != check_arity
          raise Interface::MethodArityError,
                "#{mod}: #{self}##{id} arity mismatch: #{orig_arity} instead of #{check_arity}"
        end
      end

      # return if we are not doing runtime checks for this class
      unless ENV['RUBY_CUBE_TYPECHECK'].to_i > 0 \
        && mod.instance_variable_defined?("@__interface_runtime_check") \
        && mod.instance_variable_get("@__interface_runtime_check")
        return
      end
      # if the stashed method exists, it already exists. return
      return if stashed_meth
      iface = self
      stash_method(mod, id)
      # replace method with a type checking wrapper
      mod.class_exec do
        # random alias name to avoid conflicts
        ns_meth_name = "#{id}_#{SecureRandom.hex(3)}".to_sym 
        alias_method ns_meth_name, id
        # The type checking wrapper
        define_method(id) do |*args|
          args.each_index do |i|
            # the value and expected type of the arg
            v, t = args[i], inchecks[i]
            begin
              Cube.check_type(t, v)
            rescue Interface::TypeMismatchError => e
              raise Interface::TypeMismatchError,
                    "#{mod}: #{iface}##{id} (arg: #{i}): #{e.message}"
            end
          end
          # types look good, call the original method
          ret = send(ns_meth_name, *args)
          # check return type if it exists
          begin
            Cube.check_type(outcheck, ret) if outcheck
          rescue Interface::TypeMismatchError => e
            raise Interface::TypeMismatchError,
              "#{mod}: #{iface}##{id} (return): #{e.message}"
          end
          # looks good, return
          ret
        end
      end
    end

    # massage array spec and hash spec into hash spec
    def map_spec(ids)
      ids.reduce({}) do |res, m|
        if m.is_a?(Hash)
          res.merge(m)
        elsif m.is_a?(Symbol) || m.is_a?(String)
          res.merge({ m.to_sym => nil })
        end
      end
    end

    # validate the interface spec is valid
    def validate_spec(spec)
      [*spec].each do |t|
        if t.is_a?(Array)
          unless t.first.is_a?(Module)
            raise ArgumentError, "#{t} does not contain a Module or Interface"
          end
        elsif !t.is_a?(Module)
          raise ArgumentError, "#{t} is not a Module or Interface"
        end
      end
    end

    public

    # Accepts an array of method names that define the interface.  When this
    # module is included/implemented, those method names must have already been
    # defined.
    #
    def required_public_methods
      @ids.keys
    end

    def to_spec
      inherited = (self.ancestors-[self]).select{ |x| Interface === x }
      inherited_ids = inherited.map{ |x| x.instance_variable_get('@ids') }

      # Store required method ids
      inherited_specs = map_spec(inherited_ids.flatten)
      @ids.merge(inherited_specs)
    end


    def assert_match(intf)
      raise ArgumentError, "#{intf} is not a Cube::Interface" unless intf.is_a?(Interface)
      intf_specs = intf.to_spec
      self_specs = to_spec
      Interface.match_specs(self_specs, intf_specs)
    end

        

    def proto(meth, *args)
      out_spec = yield if block_given?
      validate_spec(args)
      validate_spec(out_spec) if out_spec
      @ids.merge!({ meth.to_sym => { in: args, out: out_spec } })
    end

    def public_visible(*ids)
      unless ids.all? { |id| id.is_a?(Symbol) || id.is_a?(String) }
        raise ArgumentError, "Arguments should be strings or symbols"
      end
      spec = map_spec(ids)
      @ids.merge!(spec)
    end

    # creates a shell object for testing
    def shell
      ids = @ids
      unreq = @unreq
      cls = Class.new(Object) do
        (ids.keys - unreq).each do |m|
          define_method(m) { |*args| }
        end
      end
      Cube[cls].send(:shell_implements, self)
    end
  end
end

#class Object
#  def interface(&block)
#    mod = Module.new
#    mod.extend(Cube::Interface)
#    mod.instance_variable_set('@ids', {})
#    mod.instance_variable_set('@private_ids', {})
#    mod.instance_eval(&block)
#    mod
#  end
#
#  if ENV['RUBY_CUBE_TYPECHECK'].to_i > 0
#    def check_type(t, v)
#      if t.is_a?(Set)
#        unless t.any? { |tp| check_type(tp, v) rescue false }
#          raise Cube::Interface::TypeMismatchError,
#                "#{v.inspect} is not any of #{tp.to_a}" unless v.is_a?(tp)
#        end
#        return
#      end
#      if t.is_a? Array
#        raise Cube::Interface::TypeMismatchError,
#              "#{v} is not an Array" unless v.is_a? Array
#        check_type(t.first, v.first)
#        check_type(t.first, v.last)
#        return
#      end
#      raise Cube::Interface::TypeMismatchError, "#{v.inspect} is not type #{t}" unless v.is_a? t
#      true
#    end
#  else
#    def check_type(*_); end
#  end
#end
#
#class Module
#  def as_interface(iface, runtime_checks: true)
#    raise ArgumentError, "#{iface} is not a Cube::Interface" unless iface.is_a?(Cube::Interface)
#    implements = lambda { |this|
#      unless this.is_a? Class
#        raise "Non-Class modules should not implement interfaces"
#      end
#      this.instance_variable_set(:@__interface_runtime_check, true) if runtime_checks
#      this.include(iface)
#    }
#    implements.call(clone)
#  end
#
#  def shell_implements(mod)
#    instance_variable_set(:@__interface_runtime_check, false)
#    instance_variable_set(:@__interface_arity_skip, true)
#    include(mod)
#  end
#end
