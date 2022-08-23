# frozen_string_literal: true

module Arche
  module Mixins
    ##
    # Extend this module to allow for before and/or after action block evaluation
    # for given methods.
    module ActionCallback
      ##
      # For a list of methods the &block will be called before wil be run.
      def before_action(*meths, &block)
        meths.each do |meth|
          define_method_with_callback(meth, :before, &block)
        end
      end

      ##
      # For a list of methods the &block will be called after method has run.
      # Uses define_method_with_callback to alias the methods, i.e. redefines
      # the method storing the old method names _method
      #
      #   before_action :lock_user do
      #     @user.revoke_jwt!
      #   end
      #
      #   after_action :lock_user do
      #     @user.notify_lock
      #   end
      #
      def after_action(*meths, &block)
        meths.each do |meth|
          define_method_with_callback(meth, :after, &block)
        end
      end

      private

      ##
      # Copies a method and defines a new with the smae name calling the old
      # method with a before and after blovk around the method. The alias strategy
      def define_method_with_callback(meth, type = :after, &super_block) # :doc:
        resolve_name = ->(name) { "_#{name}" }
        new_name = resolve_name.call(meth)
        new_name = resolve_name.call(new_name) while instance_methods.include?(new_name.to_sym)
        alias_method new_name, meth
        protected new_name

        define_method meth do |*args, **kwargs, &block|
          instance_eval(&super_block) if type == :before
          value = send(new_name, *args, **kwargs, &block)
          instance_eval(&super_block) if type == :after
          return value
        end
      end
    end
  end
end
