# frozen_string_literal: true

module Arche
  module Mixins
    ##
    # Included on object, to make all objects respond to nan? and return false.
    # DataFrames may contian allot of NaNs that are treated differently, thus it
    # it is commont to ask for the object wheter or not it is nan. This is
    # intended to be the least intrusive patch
    module NaN
      def nan?
        false
      end
    end
  end
end
