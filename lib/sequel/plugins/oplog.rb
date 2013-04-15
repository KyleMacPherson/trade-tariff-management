module Sequel
  module Plugins
    module Oplog
      def self.configure(model, options = {})
        primary_key = [:oid, options.fetch(:primary_key, model.primary_key)].flatten
        operation_klass = :"#{model}::Operation"

        # Define ModelClass::Operation
        # e.g. Measure::Operation for measure oplog table
        model.const_set(:Operation, Sequel::Model(:"#{model.table_name}_oplog"))
             .set_primary_key(primary_key)
        model.const_get(:Operation).unrestrict_primary_key

        # Associations
        model.one_to_one :source, key: :oid,
                                  primary_key: :oid,
                                  class_name: operation_klass
        model.one_to_many :operations, key: primary_key,
                                       foreign_key: primary_key,
                                       primary_key: primary_key,
                                       class_name: operation_klass

        # Delegations
        model.delegate :validator, :operation_klass, to: model
      end

      module InstanceMethods
        # Operation can be set to :update, :insert and :delete
        # But they get persistated as U, I and D.
        def operation=(op)
          self[:operation] = op.to_s.first.upcase
        end

        def operation
          case self[:operation]
          when 'C' then :create
          when 'U' then :update
          when 'D' then :destroy
          else
            :create
          end
        end

        def validate
          super

          validator.validate(self)
        end

        def validate!
          validator.validate(self)

          raise ValidationFailed.new(self) if self.errors.any?
        end

        def _insert_raw(ds)
          self.operation = :create

          operation_klass.insert(self.values.except(:oid))
        end

        def _destroy_delete
          self.operation = :destroy

          validator.validate(self)

          # Run destroy validations
          # In Sequel these are modeled using before_destroy hooks
          # which is not very pretty. It will raise an exception on #destroy
          if self.errors.none?
            operation_klass.insert(self.values.except(:oid))
          else
            raise ValidationFailed.new(self)
          end
        end

        def _update_columns(columns)
          self.operation = :update

          operation_klass.insert(self.values.except(:oid))
        end
      end

      # Enforce operation logging by undefining operations that do not use
      # model instances (as Insert/Update/Delete operations will not be
      # created)
      module ClassMethods
        # Hide oplog columns if asked
        def columns
          super - [:oid, :operation, :operation_date]
        end

        def insert(*args)
          raise NotImplementedError.new("You should be instantiating model and saving instances.")
        end

        def operation_klass
          @_operation_klass ||= "#{self}::Operation".constantize
        end

        def validator
          @_validator ||= begin
                            "#{self}Validator".constantize.new
                          rescue NameError
                            NullValidator
                          end
        end
      end

      module DatasetMethods
        def update(*attr)
          # noop
        end

        def insert
          raise NotImplementedError.new("You should be inserting model instances.")
        end

        def delete
          raise NotImplementedError.new("You should be *destroying* model instances.")
        end
      end
    end
  end
end
